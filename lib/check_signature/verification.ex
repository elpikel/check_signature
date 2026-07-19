defmodule CheckSignature.Verification do
  @moduledoc """
  Verifying whether a Signature refers to a Ruling that actually exists.

  The rule (ADR 0002): every check fans out to *all* configured Sources
  concurrently — no routing by court, because a misrouted Signature would find
  nothing and be falsely branded a hallucination. A settled result is cached
  (ADR 0004) so repeat lookups never re-scrape.

  This module verifies one Signature. Checking a whole Document — extraction,
  bounded concurrency across signatures, streaming — is the LiveView's job.
  """

  alias CheckSignature.Signatures
  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.{Cache, Verdict}

  # Cap how many Signatures we verify concurrently. Because each Signature hits
  # each Source exactly once, this also bounds concurrent requests *per portal* —
  # keeping us gentle on bot-protected hosts (sn.pl behind Incapsula) that block
  # bursts. Kept low deliberately; transient blocks are additionally retried by
  # each Source adapter.
  @max_concurrency 3

  @doc """
  Checks every Signature cited in a Document and returns one Verdict per unique
  Signature, in document order. Extraction (and its per-Document cap) is applied
  first; the checks then run with bounded concurrency.
  """
  @spec check_document(String.t()) :: [Verdict.t()]
  def check_document(document) when is_binary(document) do
    %{signatures: signatures} = Signatures.extract(document)

    signatures
    |> Task.async_stream(&check/1,
      max_concurrency: @max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, verdict} -> verdict end)
  end

  @doc "The configured Sources we fan out to."
  @spec sources() :: [module()]
  def sources do
    :check_signature
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:sources, [])
  end

  @doc """
  Returns the Verdict for a Signature: cache first, otherwise fan out to all
  Sources, derive the Verdict, and cache it if settled.
  """
  @spec check(Signature.t()) :: Verdict.t()
  def check(%Signature{} = signature) do
    case Cache.fetch(signature) do
      {:ok, verdict} -> verdict
      :miss -> signature |> resolve() |> Cache.put()
    end
  end

  defp resolve(%Signature{} = signature) do
    signature
    |> fan_out()
    |> then(&Verdict.derive(signature, &1))
  end

  defp fan_out(%Signature{} = signature) do
    srcs = sources()

    srcs
    |> Task.async_stream(
      fn source -> {source.name(), safe_lookup(source, signature)} end,
      timeout: timeout_ms() + 2_000,
      on_timeout: :kill_task,
      ordered: true
    )
    |> Enum.zip(srcs)
    |> Enum.map(fn
      {{:ok, named_outcome}, _source} -> named_outcome
      {{:exit, _reason}, source} -> {source.name(), {:errored, :timeout}}
    end)
  end

  defp safe_lookup(source, signature) do
    source.lookup(signature)
  rescue
    e -> {:errored, {:exception, Exception.message(e)}}
  catch
    kind, reason -> {:errored, {kind, reason}}
  end

  defp timeout_ms do
    :check_signature
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:source_timeout_ms, 8_000)
  end
end
