defmodule CheckSignature.Verification.Sources.RetryTest do
  use ExUnit.Case, async: true

  alias CheckSignature.Verification.Sources.Retry

  defp counting(outcomes) do
    {:ok, agent} = Agent.start_link(fn -> {0, outcomes} end)

    fun = fn ->
      Agent.get_and_update(agent, fn {calls, [next | rest]} -> {next, {calls + 1, rest}} end)
    end

    calls = fn -> Agent.get(agent, fn {calls, _} -> calls end) end
    {fun, calls}
  end

  test "returns a final outcome without retrying" do
    {fun, calls} = counting([:confirmed_absent, {:errored, :should_not_reach}])
    assert :confirmed_absent = Retry.with_retry(fun, 1, 0)
    assert calls.() == 1
  end

  test "retries once on a transient error, then succeeds" do
    {fun, calls} = counting([{:errored, :blocked}, :confirmed_absent])
    assert :confirmed_absent = Retry.with_retry(fun, 1, 0)
    assert calls.() == 2
  end

  test "gives up and returns the error after exhausting retries" do
    {fun, calls} = counting([{:errored, :blocked}, {:errored, :still_blocked}])
    assert {:errored, :still_blocked} = Retry.with_retry(fun, 1, 0)
    assert calls.() == 2
  end
end
