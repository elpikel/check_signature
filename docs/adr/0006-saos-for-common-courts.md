# Serve the common-courts Source from SAOS (scoped to common courts)

The official common-courts portal (orzeczenia.ms.gov.pl) is unreachable without a
browser: F5/TSPD bot protection sits at the edge of the whole domain and returns a
JavaScript challenge to every non-browser request. We verified this against four
different endpoint types — the HTML advanced-search pages, the `ncourt-api`
JSON API (GET and POST), and the Wicket `:autocomplete` endpoint — all return the
same `bobcmn`/TSPD challenge. The protection is host-wide, not per-page, so there
is no endpoint to slip through.

## Decision

Back the common-courts Source with the SAOS API (`saos.org.pl`,
`/api/search/judgments?caseNumber=<sig>&courtType=COMMON`), not a headless browser.
SAOS offers an exact `caseNumber` search; we still confirm the returned Ruling's
case number matches the queried Signature before reporting `:matched`. The scope is
deliberately `courtType=COMMON` only — the Supreme Court and administrative courts
stay on their own official portals (sn.pl, orzeczenia.nsa.gov.pl); SAOS fills just
the one gap we cannot scrape.

## Consequences

- All three Sources are now reachable, so the strong **not_found** ("likely
  hallucinated") Verdict fires again — there is no longer a permanently-errored
  Source dragging every miss to *inconclusive*.
- SAOS is a third-party aggregator (ePaństwo Foundation), not a `.gov.pl` origin.
  It harvests from the official sources but can lag on very recent rulings, so
  "found via SAOS" is solid while "not found via SAOS" is marginally weaker than
  the official portal would be. Acceptable, and swappable: if a headless-browser
  Source for orzeczenia.ms.gov.pl is ever added, it replaces this adapter behind
  the same `Source` behaviour.
