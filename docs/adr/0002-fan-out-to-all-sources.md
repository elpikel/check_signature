# Fan out every Signature check to all Sources concurrently

A Signature's format encodes which court it belongs to, so in principle we could
classify it and query only the matching Source. We deliberately don't. Instead,
every check fans out to all three Sources concurrently (`Task.async_stream`) and
a Signature exists if any Source returns a matching Ruling.

Classification is a correctness liability: a misclassified Signature would be
sent to the wrong Source, find nothing, and be falsely branded a hallucination —
the precise failure this tool exists to prevent. Fan-out costs ~3x the requests,
but the Sources are cheap to hit in parallel and results are cached, so the cost
is negligible while the correctness win is large.

Routing-by-classification remains available later as a pure optimisation if
request volume ever justifies it; it is not needed for v1.
