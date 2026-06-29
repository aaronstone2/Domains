## Part XII — Limitations & Conclusion

A dissertation that has spent eleven parts insisting on the difference between what evidence supports and what an experiment could prove owes its readers one last act of discipline: it must turn that instrument on itself. This closing part audits the corpus against its own standard. It tallies where derived primary backing exists and, more tellingly, where it does not; it reads the full verdict distribution across all 406 claims without rounding dissent away; it names staleness and the retained-but-refuted claim as standing limitations rather than blemishes to be hidden; and it states, one final time and without drift, what the corpus has and has not established about MetroGraph. The conclusion that follows is deliberately modest in its object and ambitious only in its method.

### The primary-backing audit: where the floor is real

The single most important number in this part is a count of zeros. Of the nine domains in the corpus, only two carry any *derived* primary backing, and the derivation is the point: `is_primary_backed` is computed by the `evidence` layer from the `claim_evidence` junction against `primary_studies`, never authored by hand. A claim cannot declare itself primary-backed; the junction either resolves to a primary study or it does not.

| Domain | Claims | Primary-backed | Share |
| --- | ---: | ---: | ---: |
| hci | 49 | 46 | 94% |
| voc | 63 | 42 | 67% |
| market | 177 | 0 | 0% |
| governance | 33 | 0 | 0% |
| product | 27 | 0 | 0% |
| finance | 20 | 0 | 0% |
| compintel | 15 | 0 | 0% |
| ecosystem | 13 | 0 | 0% |
| strategy | 9 | 0 | 0% |

![Figure — Claims with derived primary backing (green) vs proxy/secondary support (grey), by domain. Only HCI (46/49) and VoC review-mining (42/63) carry primary backing; market/product/finance are secondary by construction.](figures/evidence_grade.png)

Seven of nine domains have zero primary backing, and this is by construction, not oversight. Market, product, finance, governance, ecosystem, compintel, and strategy reason over secondary signal — published comps, feature taxonomies, competitor changelogs, compliance frameworks, and the synthesis layer's own derivations — because no primary instrument was ever pointed at MetroGraph in those domains. The HCI floor of 46 of 49 is genuine peer-reviewed experimental literature, and it is what lets any wedge claim rise to *supported-by-proxy* at all. But even there the backing is borrowed: the experiments measured *other* interfaces and *other* graphs, and the literature is internally split — `hci_grounds_contradicts` records 82 grounding edges against 11 contradicting ones, including the finding that force-directed layouts win path-finding and subgraph tasks. The empirical floor is real, and it is also context-dependent.

The VoC figure demands its own caveat, because it is the one most easily misread upward. VoC's 42 primary-backed claims are *review-mining*: a real user said a real thing in a real review. That is primary evidence that a complaint exists — it is **not** evidence that MetroGraph measurably fixes the complaint. The honest reading of "67% primary-backed" in VoC is "two-thirds of these claims rest on something a user actually wrote," not "two-thirds are validated outcomes." The same caution holds at the evidence-link level: of 458 evidence attachments, 331 are secondary and only 127 primary. Secondary signal is the corpus's native medium, and the gold layer's job is to grade it honestly rather than launder it into proof.

### The verdict distribution: what retaining dissent buys

The corpus does not delete claims it disbelieves, and the full verdict distribution across all 406 claims is the visible proof of that policy.

| Verdict | Claims |
| --- | ---: |
| supported | 236 |
| speculative | 74 |
| refuted | 38 |
| disputed | 37 |
| TRUE (governance gates) | 9 |
| mixed | 5 |
| CONFIRMED | 4 |
| equivalent | 3 |
| **Total** | **406** |

![Figure — The gold layer is honest about dissent: 406 claims span supported through refuted. Refuted/disputed claims are retained and reframed as hypotheses, not deleted.](figures/verdict_distribution.png)

Seventy-five claims — 38 refuted and 37 disputed — are kept in the corpus with their negative verdicts intact, and retention rather than deletion buys three epistemic goods. First, it makes the corpus *falsifiable in place*: a refuted claim such as `market.claim.agent-orchestration-feature-gap-data-teams` (refuted because 36 products already cover orchestration) [C:market.claim.agent-orchestration-feature-gap-data-teams] records not just a "no" but the reason for it, so a future reader can re-litigate the evidence rather than rediscover the question. Second, it reframes a refuted claim as a *hypothesis pending a named experiment* rather than an embarrassment to be buried — `market.claim.40-percent-screens-3plus-panes-standard` is refuted as stated [C:market.claim.40-percent-screens-3plus-panes-standard], but the underlying split-attention question survives as something a usability study could answer. Third, it disciplines the supported column: a corpus that never says "no" cannot be trusted when it says "yes," and the visible 75 negatives are what give the 236 supported verdicts their credibility.

This is also where the two featured claims sit, instructively on opposite sides of the line. `market.claim.ai-ui-parity-exclusive-wedge` — that MetroGraph is the only graph-building tool offering full AI + UI parity, addressing the flight-to-chat failure mode — is **supported** [C:market.claim.ai-ui-parity-exclusive-wedge], yet "supported" here means the whitespace argument holds against the indexed competitive set, not that parity has been shown to change a single user's behavior. The finance comp band, by contrast, is **disputed**: comparable multiples span 6–27× ARR (Creatio 6×, Neo4j 11×, Airtable/Retool 23–27×), and a 15–22× assumption at scale is contestable on the spread alone [C:finance.claim.metrograph.revenue-multiple-band]. One claim survives its scrutiny and one does not, and the corpus shows both verdicts side by side rather than reporting only the flattering one.

### Staleness, freshness, and the regenerability mitigation

A strategy corpus decays. Competitor moves erode the whitespace a market claim depends on; comps re-rate; published HCI findings are superseded. The `verify` layer treats this explicitly, decaying confidence with freshness and flagging `stale` claims for re-grading. At the current snapshot the stale count is **0** — every claim has been touched within its freshness window — but that is a statement about *now*, not a property of the artifact. The `watch` layer exists precisely because the zero is perishable: it scans the temporal layer for competitor moves after a cutoff that erode a wedge feature or fire a red-team falsifier, and the erosion timeline shows the drumbeat on canvas and agent-node features is real and dated. Staleness is therefore a standing limitation, not a solved problem.

The mitigation is structural rather than rhetorical. The corpus is a *regenerable artifact*: `init-db` plus `restore --label <L>` reconstructs the entire database from committed parquet (round-trip verified at 298 tables / 15.6k rows), and SCD-2 `claim_history` plus `diff --since` make change between labels auditable rather than silent. The honest claim is not "the corpus never goes stale" — it will — but "when it does, re-running the pipeline against fresh signal recomputes every verdict deterministically, and the diff shows exactly what moved." Freshness is bounded by re-execution, not by trust.

### The core limitation: no MetroGraph behavioral data exists

Every limitation above is downstream of one fact. **No MetroGraph behavioral data exists.** MetroGraph is pre-revenue with no telemetry, and the corpus surfaces this not as a footnote but as a queryable, standing marker: the VoC intake tables — interviews, surveys, usability sessions, A/B experiments — are all empty, and `market.primary_studies` is empty. Those zeros are not missing work to be apologized for; they *are* the pending-experimental signal, and they are what cap the 13 wedge claims.

This is the honesty mechanism stated at its sharpest. The 13 wedge claims in `strategy.wedge_reeval` each carry a derived `cross_domain_ceiling` of supported-by-proxy, weak-proxy, or contested, and **all 13 carry `pending_experimental = TRUE`**. The ceiling is derived from the empty intake: with no behavioral data, no wedge claim *can* rise above proxy, because the only evidence that would raise it does not yet exist. So when the corpus says the metro-map layout reduces cognitive load, or that visible agent state calibrates trust, the strongest honest reading is "supported by analogous HCI experiments on other interfaces" — never "demonstrated on MetroGraph." The wedge is supported-by-proxy at best, and the empty tables are the proof, sitting in the schema as a permanent reminder that the experiment has not been run.

### What the corpus is not

It is worth being blunt about the negative space, because a sophisticated synthesis is easy to mistake for a verdict it never rendered.

- **It is not a validation of MetroGraph.** No claim in the corpus shows that MetroGraph works for any user; the supported verdicts are about market structure, literature, and shipped reality, not about MetroGraph's measured effect.
- **It is not a guarantee of returns.** Every financial figure is a comp- or assumption-driven *estimate* with p10/p50/p90 uncertainty — the SOM and LTV:CAC distributions bound an option value, not a mark, and the disputed multiple band [C:finance.claim.metrograph.revenue-multiple-band] is the case in point.
- **It is not a substitute for the named studies.** The four needed-but-missing MetroGraph experiments are roadmap items, emitted as `is_experiment` recommendations, never folded in as inputs. The corpus assumes that data may *never* arrive and refuses to borrow against it.

### The contribution, restated

If the object of the corpus is held this honestly modest, what is the contribution? It is the *method*, and the method generalizes beyond MetroGraph. The corpus is a regenerable, self-auditing strategy OS that mechanizes the proxy/experimental distinction, and it does so with machinery that is domain-agnostic by design: a uniform `claims` base layer with derived Wilson confidence intervals and freshness decay (`verify`/`calibrate`); a `claim_evidence` junction whose `is_primary_backed` flag is computed, so secondary evidence cannot masquerade as primary (`evidence`); a typed relationship graph of 2,095 edges across 21 types that the synthesis layer reads read-only, never mutating another domain's verdicts; an inference layer that derives speculative claims quarantined until verification promotes them (`reason`); reproducible Monte-Carlo models with fixed seeds (`model`/`sensitivity`); and a non-divergence projection (`render`) in which a shared metric renders byte-identically across investor deck, memo, and battlecard, each figure carrying a verdict glyph so a proxy-only wedge cannot read as measured. Any bold bet in any domain could be argued through the same engine, because nothing in it is specific to graph visualization — what is specific is only the data dropped into the auto-discovered domain folders.

### The honest closing verdict

MetroGraph's wedge is a **defensible-in-hypothesis bet with a clear, costed path to either validation or refutation.** The whitespace is real and the AI + UI parity argument survives scrutiny against the indexed market [C:market.claim.ai-ui-parity-exclusive-wedge]; the HCI literature supplies a genuine, if context-dependent, empirical floor; the shipped product is partway to the surface the thesis needs. And the ceiling holds: all 13 wedge claims carry `pending_experimental = TRUE`, with derived `cross_domain_ceiling` values of supported-by-proxy (6), weak-proxy (3), or contested (4) — none rises above proxy, and all are capped by intake tables that are still empty. The corpus has not proven the wedge works, and it does not claim to. What it has produced is honest decision-support — a defensible hypothesis, a named and costed roadmap of pre-registered studies, and a self-auditing record of exactly which verdict each claim has earned and exactly what would move it. The only path upward runs through those studies. Until they are run, supported-by-proxy is the verdict, and saying so plainly is the contribution. The appendices that follow document the engine and glossary; the argument itself closes here.
