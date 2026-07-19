ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CheckSignature.Repo, :manual)

# Mock Source used across tests so we never scrape the real portals.
Mox.defmock(CheckSignature.Verification.MockSource, for: CheckSignature.Verification.Source)
