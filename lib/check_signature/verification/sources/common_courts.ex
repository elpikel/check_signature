defmodule CheckSignature.Verification.Sources.CommonCourts do
  @moduledoc """
  Source: common courts (sądy powszechne — district, regional, appellate).

  The official portal (orzeczenia.ms.gov.pl) is behind an F5/TSPD JavaScript bot
  challenge that blocks every non-browser request (ADR 0005/0006), so we do not
  scrape it. Instead this Source is **harvested** from the SAOS API
  (saos.org.pl, ePaństwo Foundation), scoped to `courtType=COMMON`, into the local
  `rulings` index — SAOS mirrors the official common-courts data and exposes a
  paginated JSON search, no browser needed.

  SAOS is used for *background harvesting only*, never on the live request path:
  it's a third-party aggregator that can lag or briefly go down, which is
  tolerable for an async, retryable, idempotent harvest but was the source of
  per-request *inconclusive* verdicts before. Common-court checks are therefore
  answered from the index alone.
  """

  @behaviour CheckSignature.Verification.Source

  require Logger

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Verdict

  @api_url "https://www.saos.org.pl/api/search/judgments"
  @web_url "https://www.saos.org.pl/judgments/"
  @court "Sąd powszechny"
  # SAOS accepts pageSize up to 100; larger pages ⇒ fewer requests to backfill.
  @page_size 100
  @harvest_headers [
    {"user-agent", "CheckSignature/0.1 (+https://checksignature.pl; hallucination-checker)"},
    {"accept", "application/json"}
  ]

  @impl true
  def name, do: "Sądy powszechne"

  @doc "Never called on the request path — common courts are answered from the index."
  @impl true
  @spec lookup(Signature.t()) :: Verdict.source_outcome()
  def lookup(%Signature{}), do: {:errored, :harvest_only}

  @impl true
  @spec harvest_page(CheckSignature.Verification.Source.cursor()) ::
          {[CheckSignature.Verification.Source.harvest_entry()], map() | :done}
  def harvest_page(cursor) do
    page = page_number(cursor)

    case Req.get(@api_url,
           params: [
             courtType: "COMMON",
             pageSize: @page_size,
             pageNumber: page,
             sortingField: "JUDGMENT_DATE",
             sortingDirection: "DESC"
           ],
           headers: @harvest_headers,
           receive_timeout: timeout(),
           retry: false,
           redirect: true
         ) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case parse_dump(body) do
          [] -> {[], :done}
          entries -> {entries, %{"page" => page + 1}}
        end

      other ->
        Logger.warning("CommonCourts.harvest_page/1 stopping at page=#{page}: #{inspect(other)}")
        {[], :done}
    end
  rescue
    e ->
      Logger.warning("CommonCourts.harvest_page/1 raised: #{Exception.message(e)}")
      {[], :done}
  end

  # SAOS paging is 0-based.
  defp page_number(nil), do: 0
  defp page_number(%{"page" => n}) when is_integer(n) and n >= 0, do: n

  @doc """
  Parses a SAOS judgments search response into harvest entries — one per case
  number on each judgment. Public so it can be tested against a saved fixture.
  """
  @spec parse_dump(map()) :: [CheckSignature.Verification.Source.harvest_entry()]
  def parse_dump(body) when is_map(body) do
    body
    |> Map.get("items", [])
    |> Enum.flat_map(&item_entries/1)
  end

  defp item_entries(item) do
    url = @web_url <> to_string(Map.get(item, "id"))
    decided_on = parse_date(Map.get(item, "judgmentDate"))

    item
    |> Map.get("courtCases", [])
    |> Enum.map(&Map.get(&1, "caseNumber"))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn case_number ->
      %{signature: case_number, url: url, court: @court, decided_on: decided_on}
    end)
  end

  defp parse_date(nil), do: nil

  defp parse_date(iso) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp timeout do
    :check_signature
    |> Application.get_env(CheckSignature.Verification, [])
    |> Keyword.get(:source_timeout_ms, 8_000)
  end
end
