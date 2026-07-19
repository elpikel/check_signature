defmodule CheckSignatureWeb.CheckController do
  @moduledoc """
  JSON API behind the landing page's checker.

  Contract (matches assets in page_html/landing.html):

      POST /api/check  { "document": string }
      → 200 { "verdicts": [
                { "signature": string,
                  "verdict": "found" | "not_found" | "inconclusive",
                  "sources": [ { "name": string,
                                 "outcome": "matched" | "confirmed_absent" | "errored",
                                 "url"?: string } ] } ] }

  Guardrails (document-size cap, per-IP rate limit) are enforced here; the
  per-Document signature cap lives in `CheckSignature.Signatures`.
  """

  use CheckSignatureWeb, :controller

  alias CheckSignature.Verification
  alias CheckSignature.Verification.Verdict

  def create(conn, %{"document" => document}) when is_binary(document) do
    cond do
      byte_size(document) > config(:max_document_bytes) ->
        conn |> put_status(:request_entity_too_large) |> json(%{error: "document_too_large"})

      rate_limited?(conn) ->
        conn |> put_status(:too_many_requests) |> json(%{error: "rate_limited"})

      true ->
        verdicts = document |> Verification.check_document() |> Enum.map(&serialize/1)
        json(conn, %{verdicts: verdicts})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "missing_document"})
  end

  # --- serialization ---------------------------------------------------------

  defp serialize(%Verdict{} = verdict) do
    %{
      signature: verdict.signature.raw,
      verdict: Atom.to_string(verdict.status),
      sources: sources(verdict)
    }
  end

  # Reconstruct the per-Source outcome list the JS renders: matched (with url),
  # errored, or confirmed_absent, for every Source that was queried.
  defp sources(%Verdict{checked: checked, matches: matches, errored: errored}) do
    matched_by_name = Map.new(matches, fn %{source: name, ruling: r} -> {name, r} end)
    errored_set = MapSet.new(errored)

    Enum.map(checked, fn name ->
      cond do
        Map.has_key?(matched_by_name, name) ->
          %{name: name, outcome: "matched", url: matched_by_name[name].url}

        MapSet.member?(errored_set, name) ->
          %{name: name, outcome: "errored"}

        true ->
          %{name: name, outcome: "confirmed_absent"}
      end
    end)
  end

  # --- guardrails ------------------------------------------------------------

  defp rate_limited?(conn) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case CheckSignature.RateLimiter.hit(
           {:check, ip},
           config(:rate_limit_max),
           config(:rate_limit_window_ms)
         ) do
      :ok -> false
      {:error, :rate_limited} -> true
    end
  end

  defp config(key) do
    :check_signature
    |> Application.get_env(__MODULE__, [])
    |> Keyword.fetch!(key)
  end
end
