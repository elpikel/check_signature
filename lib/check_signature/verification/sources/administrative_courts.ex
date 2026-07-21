defmodule CheckSignature.Verification.Sources.AdministrativeCourts do
  @moduledoc """
  Source: administrative courts (NSA/WSA) via CBOSA — the Centralna Baza Orzeczeń
  Sądów Administracyjnych at orzeczenia.nsa.gov.pl.

  Unlike the other two Sources, this adapter is wired against the *real* portal.
  CBOSA's search is a POST form (`/cbo/search`, field `sygnatura`) that renders
  each hit as `<a href="/doc/HASH">II FSK 1442/21 - Wyrok NSA z 2022-02-22</a>`.

  A CBOSA search also returns *related* rulings, so "got results" is not "found" —
  we only report `:matched` when a result link's own signature matches the queried
  one. `:confirmed_absent` is returned only when CBOSA clearly understood the query
  (its "no results" banner, or a results list without our signature); anything else
  degrades to `:errored` so we never manufacture a false absence.
  """

  @behaviour CheckSignature.Verification.Source

  require Logger

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{Ruling, Verdict}
  alias CheckSignature.Verification.Sources.Retry

  @base_url "https://orzeczenia.nsa.gov.pl"
  @search_url @base_url <> "/cbo/search"
  # Browse endpoint: all Rulings, newest-first, 10 per page, paged via `?p=N`.
  @find_url @base_url <> "/cbo/find"
  @miss_marker "Nie znaleziono orzeczeń"
  @found_marker "Znaleziono"
  @headers [
    {"user-agent", "CheckSignature/0.1 (+https://checksignature.pl; hallucination-checker)"},
    {"accept", "text/html"}
  ]
  # The harvest crawl uses a browser-like UA — CBOSA resets obvious bots.
  @harvest_headers [
    {"user-agent",
     "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"},
    {"accept", "text/html"}
  ]

  @impl true
  def name, do: "Sądy administracyjne"

  @impl true
  def lookup(%Signature{} = signature) do
    Retry.with_retry(fn -> do_lookup(signature) end)
  end

  defp do_lookup(%Signature{} = signature) do
    case request(signature.normalized) do
      {:ok, %{status: 200, body: body}} -> parse(body, signature)
      {:ok, %{status: status}} -> {:errored, {:http_status, status}}
      {:error, reason} -> {:errored, reason}
    end
  rescue
    e -> {:errored, {:exception, Exception.message(e)}}
  end

  @impl true
  @spec harvest_page(CheckSignature.Verification.Source.cursor()) ::
          {[CheckSignature.Verification.Source.harvest_entry()], map() | :done}
  def harvest_page(cursor) do
    page = page_number(cursor)

    opts =
      [
        params: [p: page],
        headers: @harvest_headers,
        receive_timeout: timeout(),
        retry: :transient,
        max_retries: 3,
        redirect: true
      ] ++ Application.get_env(:check_signature, :harvest_req_options, [])

    case Req.get(@find_url, opts) do
      {:ok, %{status: 200, body: body}} ->
        case parse_listing(body) do
          [] -> {[], :done}
          entries -> {entries, %{"p" => page + 1}}
        end

      other ->
        # Don't loop on a blocked/errored page: end this run and let the next
        # scheduled harvest resume from the top (incremental) or retry the sweep.
        Logger.warning(
          "AdministrativeCourts.harvest_page/1 stopping at p=#{page}: #{inspect(other)}"
        )

        {[], :done}
    end
  rescue
    e ->
      Logger.warning("AdministrativeCourts.harvest_page/1 raised: #{Exception.message(e)}")
      {[], :done}
  end

  defp page_number(nil), do: 1
  defp page_number(%{"p" => n}) when is_integer(n) and n > 0, do: n

  @doc """
  Parses a `/cbo/find` listing page into harvest entries. Public so it can be
  tested against a saved fixture without hitting the network. Each result is an
  `<a href="/doc/HASH">` whose text is "<SIGNATURE> - <title>"; we keep the
  signature (text before " - ") and the link.
  """
  @spec parse_listing(String.t()) :: [CheckSignature.Verification.Source.harvest_entry()]
  def parse_listing(body) do
    body
    |> Floki.parse_document!()
    |> Floki.find("a[href^='/doc/']")
    |> Enum.map(fn a ->
      href = a |> Floki.attribute("href") |> List.first()

      signature =
        a |> Floki.text() |> String.split(" - ", parts: 2) |> List.first() |> String.trim()

      %{signature: signature, url: @base_url <> href}
    end)
    |> Enum.reject(fn e -> e.signature == "" or is_nil(e.url) end)
  end

  defp request(sygnatura) do
    Req.post(@search_url,
      form: [sygnatura: sygnatura, odmiana: "on"],
      headers: @headers,
      receive_timeout: timeout(),
      retry: false,
      redirect: true
    )
  end

  @doc """
  Derives a Source outcome from a CBOSA results page body. Public so it can be
  tested against saved fixtures without hitting the network.
  """
  @spec parse(String.t(), Signature.t()) :: Verdict.source_outcome()
  def parse(body, %Signature{} = signature) do
    cond do
      String.contains?(body, @miss_marker) ->
        :confirmed_absent

      match = find_match(body, signature) ->
        {:matched, match}

      String.contains?(body, @found_marker) ->
        # CBOSA understood the query and listed rulings, but none is ours.
        :confirmed_absent

      true ->
        {:errored, :unrecognized_results}
    end
  end

  defp find_match(body, %Signature{} = signature) do
    body
    |> results()
    |> Enum.find_value(fn {sig, href} ->
      if Signature.same?(signature, sig) do
        %Ruling{signature: sig, url: @base_url <> href, court: "NSA/WSA"}
      end
    end)
  end

  # Each result is an <a href="/doc/HASH"> whose text is "<SIGNATURE> - <title>".
  defp results(body) do
    body
    |> Floki.parse_document!()
    |> Floki.find("a[href^='/doc/']")
    |> Enum.map(fn a ->
      href = a |> Floki.attribute("href") |> List.first()
      sig = a |> Floki.text() |> String.split(" - ", parts: 2) |> List.first() |> String.trim()
      {sig, href}
    end)
  end

  defp timeout do
    :check_signature
    |> Application.get_env(CheckSignature.Verification, [])
    |> Keyword.get(:source_timeout_ms, 8_000)
  end
end
