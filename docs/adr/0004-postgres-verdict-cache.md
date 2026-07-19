# Cache Signature -> Verdict lookups in Postgres

We keep the scaffold's Ecto/Postgres, but its only job in v1 is a durable cache
of Signature -> Verdict lookups: one table keyed by normalised Signature, holding
the resolved Verdict plus a timestamp for TTL expiry. On a check we read the
cache first and only fan out to the Sources on a miss or stale entry.

We chose a persistent store over an in-memory cache (ETS/Cachex) so the cache
survives deploys and restarts — otherwise every deploy would re-scrape the
portals from cold — and is shared across instances if we ever run more than one.
The cost is keeping a database dependency for a "small tool"; we accept it because
it is already scaffolded and the persistence genuinely helps here.

This does not weaken ADR 0003. The cache stores only public court references
(a Signature and whether a Ruling exists), never user-submitted Document text.
Errored and Inconclusive outcomes are not cached as absence — only *matched* and
*confirmed-absent* results are durable, so a transient portal outage never gets
frozen into a false "not found".
