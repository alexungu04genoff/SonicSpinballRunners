# Repository working agreements

- Build with Godot 4 and GDScript. Target Windows first; Android is a possible later platform.
- Read `docs/GAME_DESIGN.md` before major gameplay features or architectural changes. Keep it current with agreed decisions, and distinguish confirmed direction from tentative mechanics and tuning values.
- The supported gameplay modes are standalone authored Act play and seamless Endless streaming of authored Acts. Work autonomously within the agreed scope; discuss substantial changes to the gameplay vision first.
- The procedural alpha generator, generated Free Play, Score Attack and old score-gated Green Hill progression were retired at the user's request. Do not reintroduce them. Endless uses three shuffled authored Acts per themed Zone, no score gates and unlimited checkpoint retries. Preserve the Act editor, shared physics, character/session tuning and ArtBro's presentation work.
- Treat traversable corners, ledges, and tight connections as possible intentional challenges. Keep difficulty estimates separate from collision validity; do not automatically smooth every connection or relax safety checks for harder preferences.
- Keep gameplay physics independent of presentation. An invisible 2D ball owns collisions; collisionless 3D models, scenery, and animations must not control them.
- Resolve physics through shared profiles and centralized modifiers, not scattered character-specific checks. Start with Balanced and Floaty test profiles.
- Prefer clear, maintainable code and existing conventions. Add extensibility only for concrete needs; avoid premature abstractions and unrelated refactors.
- Prioritize fun, playable results. Make sensible implementation decisions, experiment, and include small improvements that support the agreed gameplay vision without overcomplicating the project.
- Use Godot MCP when appropriate to inspect scenes, interact with the editor, run the game, and read output, alongside normal local tools.
- Keep automated testing lightweight: a handful of deterministic regression checks for profile resolution, modifier stacking/reset, scoring, authored loading, and streaming as those systems exist. Use available Godot headless checks for scripts, startup, and scenes. Do not introduce substantial test dependencies or a custom framework for the sandbox.
- Run the game when possible. Report checks actually executed, failures, and what still needs manual playtesting. The user judges feel, flipper timing, camera readability, and polish; maintain only a short useful checklist.
- Commit and push completed, meaningful, verified work to GitHub autonomously, including directly to `main`; no repeated permission is needed. Run relevant checks before pushing and use focused, descriptive commits.
- Preserve existing work. Discuss force-pushes, rewriting shared history, or deleting significant existing work before acting. Do not perform public deployments or releases, or download external assets, without the user's approval.
- Check for concurrent changes before editing and again before committing. Stage only your own changes; preserve another conversation's uncommitted work.
- At handoff, give a friendly, concise summary of what was built, useful discoveries, checks actually run, remaining issues, and the commit hash and push status.
