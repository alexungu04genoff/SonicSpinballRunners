# Repository working agreements

- Build with Godot 4 and GDScript. Target Windows first; Android is a possible later platform.
- Read `docs/GAME_DESIGN.md` before major gameplay features or architectural changes. Keep it current with agreed decisions, and distinguish confirmed direction from tentative mechanics and tuning values.
- Current scope is Phase 1: Physics Playground. Prioritize a playable table and physics feel; do not expand into full characters, specials, Chao drafting, procedural generation, or elaborate art without agreement.
- Keep gameplay physics independent of presentation. An invisible 2D ball owns collisions; collisionless 3D models, scenery, and animations must not control them.
- Resolve physics through shared profiles and centralized modifiers, not scattered character-specific checks. Start with Balanced and Floaty test profiles.
- Prefer clear, maintainable code and existing conventions. Add extensibility only for concrete needs; avoid premature abstractions and unrelated refactors.
- Use Godot MCP when appropriate to inspect scenes, interact with the editor, run the game, and read output, alongside normal local tools.
- Keep automated testing lightweight: a handful of deterministic regression checks for profile resolution, modifier stacking/reset, and scoring as those systems exist. Use available Godot headless checks for scripts, startup, and scenes. Do not introduce substantial test dependencies or a custom framework for Phase 1.
- Run the game when possible. Report checks actually executed, failures, and what still needs manual playtesting. The user judges feel, flipper timing, camera readability, and polish; maintain only a short useful checklist.
- Preserve existing work. Do not commit, push, deploy, or download external assets without the user's approval. Report implementation/design differences before proposing broader changes.
