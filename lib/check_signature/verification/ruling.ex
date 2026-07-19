defmodule CheckSignature.Verification.Ruling do
  @moduledoc """
  A court judgment or decision returned by a Source, identified by its Signature.

  We keep just enough to let the user verify the match themselves: the Source's
  own rendering of the Signature, a link to the Ruling on the portal, and (when
  available) the court and date.
  """

  @enforce_keys [:signature, :url]
  defstruct [:signature, :url, :court, :date, :title]

  @type t :: %__MODULE__{
          signature: String.t(),
          url: String.t(),
          court: String.t() | nil,
          date: String.t() | nil,
          title: String.t() | nil
        }
end
