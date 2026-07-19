defmodule CheckSignature.Signatures.Signature do
  @moduledoc """
  A court-ruling reference number (Polish: *sygnatura akt*), e.g. "II CSK 234/19".

  `raw` is exactly what we pulled out of the Document (used for display);
  `normalized` is the canonical form used for matching and as a cache key, so
  that "III SA/Wa 1234/19" and "III  SA / Wa  1234/19" collapse to one Signature.
  """

  @enforce_keys [:raw, :normalized]
  defstruct [:raw, :normalized]

  @type t :: %__MODULE__{raw: String.t(), normalized: String.t()}

  @doc "Builds a Signature from a raw matched string, computing its normalized form."
  @spec new(String.t()) :: t()
  def new(raw) when is_binary(raw) do
    %__MODULE__{raw: String.trim(raw), normalized: normalize(raw)}
  end

  @doc """
  Canonicalises a Signature string: collapse whitespace, tighten the spacing
  around the court/city slash, and upcase. Normalisation must be applied
  identically to both a queried Signature and any Signature returned by a Source
  before they are compared.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(raw) when is_binary(raw) do
    raw
    |> String.trim()
    |> String.replace(~r/\s*\/\s*/, "/")
    |> String.replace(~r/\s+/, " ")
    |> String.upcase()
  end

  @doc "Whether two Signatures refer to the same ruling reference, ignoring formatting."
  @spec same?(t() | String.t(), t() | String.t()) :: boolean()
  def same?(%__MODULE__{normalized: a}, %__MODULE__{normalized: b}), do: a == b

  def same?(a, b) when is_binary(a) or is_binary(b),
    do: normalize(to_string_sig(a)) == normalize(to_string_sig(b))

  defp to_string_sig(%__MODULE__{raw: raw}), do: raw
  defp to_string_sig(raw) when is_binary(raw), do: raw
end
