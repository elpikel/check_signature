defmodule CheckSignature.Verification.Verdict do
  @moduledoc """
  The three-valued outcome of checking one Signature (see CONTEXT.md).

    * `:found`        — at least one Source matched; `matches` links the Rulings.
    * `:not_found`    — every Source responded and none held the Signature. The
                        strong "likely hallucinated" signal.
    * `:inconclusive` — no Source matched but at least one Source errored, so
                        absence can't be trusted. Never an accusation.

  A Verdict is *derived* from the set of per-Source outcomes; the derivation is
  the single place that rule lives, so the LiveView and the cache agree.
  """

  alias CheckSignature.Signatures.Signature
  alias CheckSignature.Verification.Ruling

  @enforce_keys [:signature, :status]
  defstruct [:signature, :status, matches: [], checked: [], errored: []]

  @type status :: :found | :not_found | :inconclusive

  @type source_outcome ::
          {:matched, Ruling.t()} | :confirmed_absent | {:errored, term()}

  @type t :: %__MODULE__{
          signature: Signature.t(),
          status: status(),
          # Rulings that matched, each tagged with the Source that found it.
          matches: [%{source: String.t(), ruling: Ruling.t()}],
          # Human names of every Source we queried.
          checked: [String.t()],
          # Human names of Sources that errored (subset of `checked`).
          errored: [String.t()]
        }

  @doc """
  Derives a Verdict for `signature` from `outcomes` — a list of
  `{source_name, outcome}` pairs, one per Source we fanned out to.
  """
  @spec derive(Signature.t(), [{String.t(), source_outcome()}]) :: t()
  def derive(%Signature{} = signature, outcomes) when is_list(outcomes) do
    checked = Enum.map(outcomes, fn {name, _} -> name end)

    matches =
      for {name, {:matched, %Ruling{} = ruling}} <- outcomes,
          do: %{source: name, ruling: ruling}

    errored = for {name, {:errored, _}} <- outcomes, do: name

    status =
      cond do
        matches != [] -> :found
        errored != [] -> :inconclusive
        true -> :not_found
      end

    %__MODULE__{
      signature: signature,
      status: status,
      matches: matches,
      checked: checked,
      errored: errored
    }
  end
end
