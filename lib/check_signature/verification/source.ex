defmodule CheckSignature.Verification.Source do
  @moduledoc """
  Behaviour for a Source: an authoritative registry of Rulings we query to
  confirm a Signature exists. Each Source (common courts, Supreme Court,
  administrative courts) is one implementation, scraped behind this behaviour so
  that swapping to an official API — or adding a court — changes one module.

  `lookup/1` MUST distinguish *confirmed absence* from *error*. Returning
  `:confirmed_absent` asserts "this portal responded and does not contain the
  Signature" and can brand a citation a hallucination — so return it only when
  the response was genuinely understood. When in any doubt (non-200, unexpected
  markup, timeout), return `{:errored, reason}`; an errored outcome is treated as
  *unknown*, never as absent.
  """

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Verdict

  @doc "A short human-readable name, e.g. \"Supreme Court (SN)\"."
  @callback name() :: String.t()

  @doc "Looks up a single Signature in this Source."
  @callback lookup(Signature.t()) :: Verdict.source_outcome()
end
