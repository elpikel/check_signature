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

  @typedoc """
  An opaque, Source-defined position in the newest-first Ruling listing (e.g. a
  page number, a date, a court id). `nil` means "start from the newest".
  """
  @type cursor :: map() | nil

  @typedoc """
  One harvested Ruling: a raw `:signature` string, its `:url`, and optional
  `:court`, `:title`, `:decided_on`. `CheckSignature.Rulings.upsert_all/2`
  normalizes and stores these.
  """
  @type harvest_entry :: %{
          required(:signature) => String.t(),
          required(:url) => String.t(),
          optional(:court) => String.t() | nil,
          optional(:title) => String.t() | nil,
          optional(:decided_on) => Date.t() | nil
        }

  @doc """
  Fetches one page of this Source's Rulings, **newest-first**, starting at
  `cursor` (`nil` = newest). Returns the page's entries and the next cursor, or
  `:done` when the listing is exhausted. Implemented only by harvestable Sources.
  """
  @callback harvest_page(cursor()) :: {[harvest_entry()], cursor() | :done}

  @optional_callbacks harvest_page: 1
end
