# CheckSignature

A tool that verifies whether court-ruling references found in legal documents
actually exist, so that hallucinated citations produced by LLMs can be caught.

## Language

**Signature**:
The reference number that uniquely identifies a court ruling (Polish: *sygnatura
akt*), e.g. "II CSK 234/19". Despite the name, this has nothing to do with
cryptographic or handwritten signatures.
_Avoid_: cryptographic signature, e-signature, citation

**Ruling**:
A court judgment or decision, identified by its Signature.
_Avoid_: case, verdict, judgment (use only when the distinction matters)

**Document**:
The text a user submits to be checked — typically a legal document produced by
an LLM. We scan a Document to extract the Signatures it cites; each is then
verified. The Document itself is never stored beyond the check.

**Extraction**:
Locating the Signatures cited within a Document. A missed Signature is the worst
outcome — it means a potential hallucination goes unchecked.

**Source**:
An authoritative registry of Rulings that we query to confirm existence. v1 has
three, each behind its own adapter implementing a shared behaviour: the Supreme
Court (SN) and administrative courts (NSA/WSA) are scraped from their official
portals; common courts are queried via the SAOS API, because the official portal
is bot-gated (see the ADRs).

**Verdict**:
The per-Signature outcome of a check, one of three states:
- *Found* — at least one Source matched; names the Source(s) and links the Ruling.
- *Not found* — every Source responded and none held the Signature; the strong
  "likely hallucinated" signal.
- *Inconclusive* — no Source matched but at least one Source errored (timeout,
  block, changed markup), so absence can't be trusted. Never an accusation.
A check of a Document produces a list of Verdicts, one per extracted Signature.

**Source outcome**:
The result of querying a single Source: *matched*, *confirmed-absent* (responded,
no such Signature), or *errored* (no usable answer). Verdicts are derived from
the set of Source outcomes — an *errored* outcome is unknown, not absent.

**Exists**:
A Signature *exists* when *any* Source returns at least one Ruling whose own
Signature matches the one we queried. Getting *some* results back is not enough —
a result must actually carry the queried Signature. A Signature that no Source
can match is a hallucination.
