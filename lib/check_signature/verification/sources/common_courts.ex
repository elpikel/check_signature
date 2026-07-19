defmodule CheckSignature.Verification.Sources.CommonCourts do
  @moduledoc """
  Source: common courts (sądy powszechne — district, regional, appellate).

  The official portal (orzeczenia.ms.gov.pl) is behind an F5/TSPD JavaScript bot
  challenge that blocks every non-browser request (ADR 0005/0006), so this Source
  is served by the SAOS API (saos.org.pl) instead — scoped to `courtType=COMMON`
  so it only fills the common-courts gap; the Supreme Court and administrative
  courts stay on their own official portals.

  SAOS exposes an exact `caseNumber` search. As always we still confirm the
  returned Ruling's own case number matches the queried Signature before reporting
  `:matched`. An empty result is `:confirmed_absent` (SAOS responded and holds no
  such common-court Ruling); a non-JSON/!200 response is `:errored`.
  """

  @behaviour CheckSignature.Verification.Source

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{Ruling, Verdict}
  alias CheckSignature.Verification.Sources.Retry

  @api_url "https://www.saos.org.pl/api/search/judgments"
  @web_url "https://www.saos.org.pl/judgments/"
  @headers [
    {"user-agent", "CheckSignature/0.1 (+https://checksignature.pl; hallucination-checker)"},
    {"accept", "application/json"}
  ]

  @impl true
  def name, do: "Sądy powszechne"

  @impl true
  def lookup(%Signature{} = signature) do
    Retry.with_retry(fn -> do_lookup(signature) end)
  end

  defp do_lookup(%Signature{} = signature) do
    case request(signature.normalized) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> parse(body, signature)
      {:ok, %{status: status}} -> {:errored, {:http_status, status}}
      {:error, reason} -> {:errored, reason}
    end
  rescue
    e -> {:errored, {:exception, Exception.message(e)}}
  end

  defp request(case_number) do
    Req.get(@api_url,
      params: [caseNumber: case_number, courtType: "COMMON", pageSize: 50],
      headers: @headers,
      receive_timeout: timeout(),
      retry: false,
      redirect: true
    )
  end

  @doc """
  Derives a Source outcome from a decoded SAOS search response. Public so it can
  be tested against saved fixtures without hitting the network.
  """
  @spec parse(map(), Signature.t()) :: Verdict.source_outcome()
  def parse(body, %Signature{} = signature) when is_map(body) do
    items = Map.get(body, "items")
    match = is_list(items) && Enum.find_value(items, &match_item(&1, signature))

    cond do
      match -> {:matched, match}
      is_list(items) -> :confirmed_absent
      true -> {:errored, :unrecognized_response}
    end
  end

  defp match_item(item, %Signature{} = signature) do
    numbers =
      item
      |> Map.get("courtCases", [])
      |> Enum.map(&Map.get(&1, "caseNumber"))
      |> Enum.reject(&is_nil/1)

    if number = Enum.find(numbers, &Signature.same?(signature, &1)) do
      %Ruling{
        signature: number,
        url: @web_url <> to_string(Map.get(item, "id")),
        court: "Sąd powszechny"
      }
    end
  end

  defp timeout do
    :check_signature
    |> Application.get_env(CheckSignature.Verification, [])
    |> Keyword.get(:source_timeout_ms, 8_000)
  end
end
