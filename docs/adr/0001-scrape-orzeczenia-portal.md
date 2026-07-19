# Verify Signatures by scraping orzeczenia.ms.gov.pl

The Portal Orzeczeń Sądów Powszechnych (orzeczenia.ms.gov.pl) is the authoritative
source for common-court rulings, but it exposes only a human-facing HTML search
form — no documented public API. For v1 we submit Signatures to that search
endpoint server-side with `Req` and parse the results HTML, treating a Signature
as existing only when a returned Ruling carries a matching Signature.

We accept the fragility (markup changes, rate limits, ToS) rather than block the
"one small tool" on obtaining official API access. To contain that risk, all
portal access lives behind a single swappable `RulingSource` adapter, so moving
to an official API or adding other courts later changes one module, not the app.
Results are cached to avoid hammering the portal on repeat lookups.

## Considered Options

- **Official API / data dump** — robust and legitimate, but slow to obtain and
  may never materialise. Rejected for v1; still the preferred long-term source.
- **Scraping behind an adapter** (chosen) — ships now, isolates the risk.
