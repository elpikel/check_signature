# Sample document — mixed real & hallucinated signatures

A paste-ready Polish legal excerpt for manually exercising the checker. It cites
signatures across all three court families, mixing rulings that exist in the
registries we query with clearly fabricated ones.

## Document (paste this into the form)

```
W ocenie Sądu roszczenie powoda znajduje oparcie w ugruntowanej linii
orzeczniczej. Jak wskazał Sąd Najwyższy w postanowieniu I KZP 5/20, a także
w wyroku II CSK 234/19 i uchwale III CZP 91/23, odpowiedzialność ta ma charakter
obiektywny.

Na gruncie spraw administracyjnych analogicznie wypowiedział się Naczelny Sąd
Administracyjny w wyroku II FSK 1442/21 oraz Wojewódzki Sąd Administracyjny
w Warszawie w sprawie II SA/Wa 123/20. W orzecznictwie sądów powszechnych por.
wyrok Sądu Apelacyjnego z dnia 8 lipca 2020 r., I ACa 1042/20.

Odmienny pogląd, powołany przez stronę przeciwną, opiera się na rzekomym wyroku
Sądu Najwyższego II CSK 9999/47 oraz na uchwale VII CZP 512/99, a nadto na
orzeczeniu NSA IX FSK 8888/23 i nieistniejącym postanowieniu V KK 4021/88.
```

## Expected verdicts

Verified live against the registries (SN via sn.pl, NSA/WSA via CBOSA, common
courts via SAOS). "Znaleziona" = found; "Nie znaleziono" = not in any registry we
check (possible hallucination — see the coverage caveats in the ADRs).

| Signature       | Court family        | Verdict         | Note                                            |
| --------------- | ------------------- | --------------- | ----------------------------------------------- |
| `I KZP 5/20`    | Supreme Court       | ✅ Znaleziona   | real — matched in SN                            |
| `II FSK 1442/21`| NSA                 | ✅ Znaleziona   | real — matched in CBOSA                         |
| `II SA/Wa 123/20`| WSA                | ✅ Znaleziona   | real — matched in CBOSA                         |
| `II CSK 234/19` | Supreme Court       | Nie znaleziono  | not in SN's online base (may exist offline)     |
| `III CZP 91/23` | Supreme Court       | Nie znaleziono  | not in SN's online base                         |
| `I ACa 1042/20` | common (appellate)  | Nie znaleziono  | not in SAOS's common-court set                  |
| `II CSK 9999/47`| Supreme Court       | Nie znaleziono  | **fabricated**                                  |
| `VII CZP 512/99`| Supreme Court       | Nie znaleziono  | **fabricated**                                  |
| `IX FSK 8888/23`| NSA                 | Nie znaleziono  | **fabricated**                                  |
| `V KK 4021/88`  | Supreme Court       | Nie znaleziono  | **fabricated**                                  |

Caveat: a "Nie znaleziono" means *not present in the registries we query*, not a
proof of fabrication — SN's online base and SAOS are both incomplete. That is why
the UI says *możliwa halucynacja* (possible), not certain. A "Znaleziona" is
authoritative.
