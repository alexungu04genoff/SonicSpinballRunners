# Authored Act difficulty and review

Difficulty is authored metadata. Review facts are automatic. The design checklist is human judgment. Telemetry provides later evidence. The tool measures facts; the human judges design; playtesting can later test that judgment.

## Editor workflow

Open **Act Geometry Editor → right sidebar → Act Review**, beside Properties. The tab uses the existing sidebar width and has its own scroll. Foundation and hints start expanded; shot scale and the six checklist sections can be expanded individually.

Choose a difficulty and optionally write a Design Thesis of up to 240 characters. Both support ordinary Save/Load and Undo/Redo. The thesis states what the Act is trying to be; it is never required to save.

| Rating | Authored meaning |
| --- | --- |
| 1 · Relaxed | Very forgiving: broad useful shots, strong recovery, low drain pressure. |
| 2 · Easy | Some danger exists, but mistakes commonly return to useful play. |
| 3 · Standard | Normal SSR expectation: meaningful misses/drain risk and deliberate shots, while broadly approachable. |
| 4 · Hard | Precision and routing matter substantially. Bad shots regularly threaten the Ball; important routes require more control. |
| 5 · Expert | Intentionally demanding. Mastery of the table, Ball control and character mechanics is expected. |

Difficulty never changes score targets, Balls, Wide Spring charges, enemies, rewards, Goals, physics or mechanic strength. No classifier assigns or rewrites it. Future run-generation use is a possibility, not implemented behavior.

## Automatic facts and design language

**Baseline vocabulary:** Rings, Buzz Bombers, flippers, Slingshots, Springs and round/triangle bumpers. These do not contribute to featured-family focus.

**Featured families:** Drop Targets, Switch, One-Way Gate, Diverter, Elevated Rail, Dash Panel and Spinner. Existing Lane Barriers and Magnetic Fields also appear as separate featured families when used. Switch Targets, Wall Switches and Switch Banks count together as one Switch family. Repeated instances never increase a family's count.

Foundation counts all authored left/right flippers; the format has no main/secondary role, so the UI explicitly says “all.” Ring counts use the same pattern and elevated-rail sampling functions as runtime, including ellipses, racks and enabled rail rings. These are authored pickup counts, not estimates of how many Rings a player will collect. Goal reports an explicit position or its existing Spawn/table-center fallback; Spawn reports whether it was authored. Hiding editor layers does not change counts.

Five conservative checks can suggest review: absent Buzz Bombers, absent Rings, absent Slingshots anywhere in the Act, more than three featured families, or a Goal diameter below two base Ball diameters. These thresholds are prompts, not rules or quality scores. The panel does not infer a lower-table region or claim that a vertical route lacks support.

Shot scale shows Goal diameter, Gate span and Drop Target center-to-center spacing in pixels and base Ball diameters. Multiple Gate/Bank instances use min–max ranges. Base Ball diameter comes from shared Act proportions (`0.28 × cell_size`); character/session modifiers may differ. A Gate's authored span is not a measured free opening. None of these facts assigns precision difficulty.

## Human checklist and boundaries

Identity, Routes, Objects, Featured mechanics, Goal and Feel contain Alex's review prompts. Checkboxes are session-only UI state. Document edits, Undo/Redo, New and successful Load clear them; selection, scrolling, Save and layer visibility changes retain them. They do not affect fingerprints, validation, baking, play, telemetry or dirty state.

Review hints and unchecked prompts never gate Save, Bake or Play. Existing structural validation and the existing save-before-bake/play workflow still apply. Metadata validation only checks the field types/ranges; it does not judge the selected rating or require a thesis.

Static evidence cannot establish safe/fun routes, purposeful bumpers, fair enemies, comfortable Goal access, good tempo, a distinctive silhouette or the correct difficulty. Those remain human judgments informed by actual play.

## Persistence, bake receipts and telemetry

Act format **18** adds `authored_difficulty` (integer 1–5, default 3) and `design_thesis` (optional string, maximum 240 characters). Supported older Acts migrate in memory to Standard with an empty thesis. Loading never rewrites their files; explicit Save writes the current format. Existing goal/ring migrations are preserved. Production and experimental Acts are not manually re-rated by this task.

Both fields participate in the existing full-document fingerprint and copy/undo path. Consequently, this format change and later metadata edits invalidate old bake receipts under the normal convention. Use **Bake Prototype** or **Bake Endless** before their normal baked runs. Editor **Play Act** continues to build its selected Act in memory. There is no new metadata-only bake cache or bypass.

Prototype telemetry format **3** adds `authored_difficulty`, `authored_difficulty_label` and `act_fingerprint` to completed and partial Act telemetry rows. Existing source/title, theme, character/type/action, run configuration, scores, lost Balls and timing evidence remain available. Values come from the resident Act document used by that run, so later file edits cannot relabel old evidence. Both clipboard export and automatic local archives use this schema. Old archives are neither rewritten nor assumed to have a rating; absent metadata stays unknown in legacy callers.

The source plus fingerprint permits future comparisons of the same Act revision and authored rating against drains, target time, Goal delay and score/sec. No aggregation/dashboard is implemented in V1. A later system may recommend reviewing an Easy Act after punishing playtests; it must never alter authored difficulty automatically.

## Focused verification

`tests/act_review_regression.gd` checks persistence, legacy migration without rewriting sources, fingerprints/bake receipts, baseline/family counts, runtime-equivalent Ring counts, live editor additions/removals, Undo/Redo and session-only checklist isolation. The Prototype Act playtest regression checks partial/completed telemetry through real run hooks and JSON export. Existing geometry, editor and telemetry checks cover the surrounding paths. Human review still owns actual shot comfort, readability and feel.

Verified on Godot 4.7.2: 37 review checks with rendered Forward+/Vulkan panel inspection; 12 Prototype Act playtest checks including nondefault difficulty in the automatic archive; existing geometry (3,461 plus 6 fresh-process reload checks), editor (92), telemetry (14), enemy streaming (31) and archive (33) regressions passed. Streaming/archive initially needed their missing or stale bakes prepared. Test fixtures and all five production Acts baked successfully in Green Hill and Chemical Plant without rewriting authored resources; other theme/Endless bakes still require the normal rebuild after this format change. A rendered Prototype run also passed.
