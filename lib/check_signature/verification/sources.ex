defmodule CheckSignature.Verification.Sources do
  @moduledoc """
  Registry mapping a short, stable Source *key* to its module.

  The key is what we persist in `rulings.source` and pass in Oban harvest job
  args (`%{"source" => "supreme_court"}`), so it must stay stable even if a
  module is renamed. This registry governs which Sources are harvestable in the
  background and maps a stored `rulings.source` back to a module for display.
  """

  alias CheckSignature.Verification.Sources.{
    AdministrativeCourts,
    CommonCourts,
    SupremeCourt
  }

  @by_key %{
    "common_courts" => CommonCourts,
    "supreme_court" => SupremeCourt,
    "administrative_courts" => AdministrativeCourts
  }

  @doc "Resolves a Source key to its module, or `:error`."
  @spec fetch(String.t()) :: {:ok, module()} | :error
  def fetch(key) when is_binary(key), do: Map.fetch(registry(), key)

  @doc "The Source key for a module (inverse of `fetch/1`)."
  @spec key(module()) :: String.t() | nil
  def key(module) do
    Enum.find_value(registry(), fn {k, mod} -> if mod == module, do: k end)
  end

  @doc "All registered `{key, module}` pairs."
  @spec all() :: [{String.t(), module()}]
  def all, do: Map.to_list(registry())

  # Tests can register extra harvestable Sources (e.g. a scripted fake) via
  # `:extra_harvest_sources` without touching the production registry.
  defp registry do
    Map.merge(@by_key, Application.get_env(:check_signature, :extra_harvest_sources, %{}))
  end
end
