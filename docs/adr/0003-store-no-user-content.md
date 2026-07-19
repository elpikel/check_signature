# Persist no user-submitted content

Users paste confidential legal text (draft contracts, litigation material) into
the tool. We deliberately store none of it. A submitted Document lives in memory
only for the duration of the check and is then discarded; we keep no document
text, no per-user history, and no record of what was checked.

This is a privacy-and-liability stance, not an oversight: it lets the landing
page truthfully promise "we don't keep your documents" — a real selling point for
a legal tool — and removes any obligation around retention, breach exposure, or a
privacy policy covering stored legal text.

The trade-off is no history feature and no content analytics in v1. Caching
(see caching decision) is permitted only for non-sensitive Signature -> Verdict
lookups, since a Signature is a public court reference, not user content.

Note: the Phoenix scaffold ships with Ecto/Postgres configured. That does not
imply we persist user data — revisit this ADR before adding any table that would.
