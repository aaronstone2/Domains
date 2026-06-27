# Generated routines — index (who's whose)

Each routine = `<lifter>-<gym>.md`, generated from the corpus against that lifter's profile
(`../lifters/<lifter>.json`), **only that lifter's own active constraints** (scoped by id prefix
`exercise.constraint.<lifter>.*`), and that gym's typed equipment (`../gyms/<gym>.json`).
Every doc's H1 + legend block names the lifter and gym, so a printed page is self-identifying.

| File | Lifter | Gym | Split | Governing constraint(s) | Source brief |
|---|---|---|---|---|---|
| `mark-290-revolution.md` | Mark | 290 Revolution Dr (Somerville) | 6-day PPL×2 (rest Thu) | left pinky (grip-gate), wrist tendonitis, shoulder, TMJ, lower-back support | `../brief/` |
| `aaron-290-revolution.md` | Aaron Stone | 290 Revolution Dr (Somerville) | 4-day Upper/Lower | bilateral shoulder instability — limited external-rotation ROM (upper volume therapeutic) | `../brief/aaron-290-revolution/` |
| `aaron-planet-fitness.md` | Aaron Stone | Planet Fitness | 4-day Upper/Lower | bilateral shoulder instability — limited external-rotation ROM (upper volume therapeutic) | `../brief/aaron-planet-fitness/` |

**Aaron has two routines** because he trains at two gyms — the exercise selection differs
because the equipment differs. Both have an Olympic barbell + rack + Smith + dumbbells, so the
heavy free-weight anchors (squat, RDL, hip thrust, presses) carry across. What differs: **Planet
Fitness adds** leg-press, pec-deck, machine lateral-raise, hip-adduction and dedicated calf
machines (high-SFR accessory volume 290 lacks); **290 adds** the Cybex FTS Glide cable with
wrist cuffs (its grip-bypass / functional-trainer work) and caps dumbbells at 75 lb (PF ~80).
Same body, same constraint, same 4-day split and per-muscle volume — only the menu changes.

## Regenerating the printable PDFs

```
uv run --with markdown python ../render.py                       # render every *.md here -> .html + .pdf
uv run --with markdown python ../render.py aaron-planet-fitness  # or just one (name without .md)
```

`render.py` skips this `README.md` and renders each routine doc into a matching `.html` + `.pdf`
beside it (Chrome/Edge headless). Re-run after editing any routine.
