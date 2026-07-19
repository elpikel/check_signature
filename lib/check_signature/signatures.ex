defmodule CheckSignature.Signatures do
  @moduledoc """
  Extraction: finding the Signatures (*sygnatury*) cited within a Document.

  A missed Signature is the worst outcome — it lets a potential hallucination go
  unchecked — so the pattern leans toward recall. Everything the pattern matches
  is a well-formed candidate; whether the referenced Ruling actually *exists* is
  decided later by `CheckSignature.Verification`, not here.
  """

  alias CheckSignature.Signatures.Signature

  # Polish court signatures share a shape:
  #
  #   <division: roman> <department: letters>[/<city>] <number>/<year>
  #
  # Examples this matches: "II CSK 234/19", "I Ns 123/2019", "III SA/Wa 1234/19",
  # "II FSK 1234/19", "I OSK 200/18", "II SAB/Wa 12/20".
  #
  #   - division:   roman numeral (I..XIII in practice)
  #   - department: a titlecased/upper code such as C, CSK, Ns, RC, SA, FSK, KZP
  #   - city:       administrative-court location code, e.g. /Wa, /Kr, /Gl, /Łd
  @pattern ~r/\b[IVX]{1,5}\s+[A-Z][A-Za-z]{0,4}(?:\s*\/\s*[A-ZŁ][a-ząćęłńóśźż]{1,3})?\s+\d{1,6}\/\d{2,4}\b/u

  @doc "The configured maximum number of Signatures processed per Document."
  @spec max_signatures() :: pos_integer()
  def max_signatures do
    :check_signature
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:max_signatures, 50)
  end

  @doc """
  Extracts the unique Signatures cited in `document`.

  Duplicates (by normalized form) collapse to one. The result is capped at
  `:max` (defaulting to the configured `max_signatures/0`); `truncated?` reports
  whether the cap dropped any, so the UI can warn the user.
  """
  @spec extract(String.t(), keyword()) :: %{
          signatures: [Signature.t()],
          truncated?: boolean(),
          unique_count: non_neg_integer()
        }
  def extract(document, opts \\ []) when is_binary(document) do
    max = Keyword.get(opts, :max, max_signatures())

    unique =
      @pattern
      |> Regex.scan(document)
      |> Enum.map(fn [match | _] -> Signature.new(match) end)
      |> Enum.uniq_by(& &1.normalized)

    %{
      signatures: Enum.take(unique, max),
      truncated?: length(unique) > max,
      unique_count: length(unique)
    }
  end

  @doc "The raw regex, exposed for testing and reuse."
  @spec pattern() :: Regex.t()
  def pattern, do: @pattern
end
