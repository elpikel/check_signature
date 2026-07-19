# Two of three Sources scrape directly; common courts needs a browser

> **Status:** the "needs a browser" conclusion for common courts is superseded by
> [ADR 0006](0006-saos-for-common-courts.md) — that Source is now served by the
> SAOS API instead. The scraping findings below (NSA POST, SN GET, common-courts
> F5/TSPD wall) still stand.

We wired each Source against its live portal. Result after probing all three:

- **NSA/WSA (CBOSA, orzeczenia.nsa.gov.pl)** — clean POST form, plain-HTML
  results. Implemented and live-verified.
- **Supreme Court (sn.pl)** — the ASP.NET *postback* is blocked by Incapsula (401
  without a JS challenge), but the search webpart also honours a plain
  `?Sygnatura=<sig>` **GET**, and GETs are not WAF-blocked. We query by GET and
  parse the HTML. Implemented and live-verified.
- **Common courts (orzeczenia.ms.gov.pl)** — behind an F5/TSPD JavaScript bot
  challenge that guards *every* request (GET and POST alike, all paths). No
  friendly-parameter bypass exists; a real browser must execute the challenge JS
  before any content is served.

## Decision

Ship NSA/WSA and SN as live Sources. The common-courts adapter short-circuits to
`{:errored, :requires_browser}` — it makes no doomed request (which would only
hammer the portal with unsolvable challenges) and yields an honest *inconclusive*
Verdict rather than a false "not found".

## Consequence

Because one Source is permanently unreachable, and an errored Source makes a
Verdict *inconclusive* (ADR 0004 / the never-falsely-accuse contract), a Signature
that no live Source matches is reported **inconclusive**, not **not_found** — we
can't rule out that it is a real *common-court* ruling we cannot currently check.
So the tool reliably *confirms* existence (found via SN or NSA/WSA) but rarely
fires the strong "likely hallucinated" verdict until common courts is covered.

Closing that gap needs either a headless-browser Source for orzeczenia.ms.gov.pl,
or an aggregating API covering common courts. That is a deliberate follow-up
decision, deferred until chosen.
