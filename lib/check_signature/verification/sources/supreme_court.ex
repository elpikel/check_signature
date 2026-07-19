defmodule CheckSignature.Verification.Sources.SupremeCourt do
  @moduledoc """
  Source: Supreme Court of Poland (Sąd Najwyższy) ruling database on sn.pl.

  The search UI at `/wyszukiwanie/SitePages/orzeczenia.aspx` is ASP.NET WebForms,
  and its *postback* is blocked by Incapsula (401 without a JS challenge). But the
  webpart also honours a plain `?Sygnatura=<sig>` **GET** query and renders results
  server-side — and GETs are not WAF-blocked. So we query by GET and parse the HTML.

  Each hit is `<a href="…?ItemSID=…&Sygnatura=…">II CSK 234/19</a>` (link text is
  the signature); a miss shows "Nie znaleziono orzeczeń…". As with CBOSA, the
  search can surface related rulings, so we only report `:matched` when a result
  link's own signature matches the queried one; `:confirmed_absent` only when the
  page was clearly understood; otherwise `:errored`, never a false absence.
  """

  @behaviour CheckSignature.Verification.Source

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{Ruling, Verdict}
  alias CheckSignature.Verification.Sources.Retry

  @search_url "https://www.sn.pl/wyszukiwanie/SitePages/orzeczenia.aspx"
  @miss_marker "Nie znaleziono orzeczeń"
  @headers [
    {"user-agent", "CheckSignature/0.1 (+https://checksignature.pl; hallucination-checker)"},
    {"accept", "text/html"}
  ]

  @impl true
  def name, do: "Sąd Najwyższy"

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

  defp request(sygnatura) do
    Req.get(@search_url,
      params: [{"Sygnatura", sygnatura}],
      headers: @headers,
      receive_timeout: timeout(),
      retry: false,
      redirect: true
    )
  end

  @doc """
  Derives a Source outcome from an SN results page body. Public so it can be
  tested against saved fixtures without hitting the network.
  """
  @spec parse(String.t(), Signature.t()) :: Verdict.source_outcome()
  def parse(body, %Signature{} = signature) do
    results = results(body)

    cond do
      match = find_match(results, signature) -> {:matched, match}
      String.contains?(body, @miss_marker) -> :confirmed_absent
      results != [] -> :confirmed_absent
      true -> {:errored, :unrecognized_results}
    end
  end

  defp find_match(results, %Signature{} = signature) do
    Enum.find_value(results, fn {sig, href} ->
      if Signature.same?(signature, sig) do
        %Ruling{signature: sig, url: href, court: "SN"}
      end
    end)
  end

  # Each result's signature is the text of its detail link (href carries ItemSID).
  defp results(body) do
    body
    |> Floki.parse_document!()
    |> Floki.find("a[href*='ItemSID=']")
    |> Enum.map(fn a ->
      href = a |> Floki.attribute("href") |> List.first()
      {a |> Floki.text() |> String.trim(), href}
    end)
    |> Enum.reject(fn {sig, href} -> sig == "" or is_nil(href) end)
  end

  defp timeout do
    :check_signature
    |> Application.get_env(CheckSignature.Verification, [])
    |> Keyword.get(:source_timeout_ms, 8_000)
  end
end
