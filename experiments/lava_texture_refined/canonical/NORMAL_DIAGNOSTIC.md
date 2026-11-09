# Floor-normal diagnostic — 2026-11-09

**Decision:** Alex subsequently selected the exaggerated version. Strength 6.0 is now the approved floor response, not merely a diagnostic. Production uses flat geometry; other material roles retain their previous strength. The observations below record the original diagnostic before that decision.

Alex found the recessed result too subtle and requested an exaggerated-normal diagnostic before considering further geometry. The real disk-loaded Prototype was captured with floor geometry disabled in both frames: `normal-only.png` uses normal strength 0.85 and `normal-extreme.png` uses 6.0 (approximately 7.06 times stronger). The diagnostic changes only the two floor material families. Approved albedo, surrounding materials, Default atmosphere, production Retro, camera and frozen gameplay state remain identical.

The exaggerated frame visibly changes the broad rock faces, including the upper-floor insets. This establishes that the structural normal field and its runtime bindings work and can make the facets readable at the gameplay camera. The 6.0 value produces harsh shading and is diagnostic, not a shipping recommendation. Since this diagnostic demonstrates readable facets, no additional geometric relief was introduced and no further normal increases were attempted. Parallax stays off. Existing canonical settings were restored after capture; this experiment does not alter the prior production materials or bakes.

`normal-diagnostic.json` records both settings and actual production authority. `normal-diagnostic-comparison.png` contains the untouched 1440x1000 frames side by side, with labels above. Reproduce graphically with `normal_diagnostic.gd -- --retro=production`. The script also has an unused `--geometry-study` branch for a restrained follow-up only if needed; that branch was not run during this diagnostic.

The current certificate-store startup error remains nonblocking. No full test suite, benchmark, commit or push was run. User judgment of the visual result remains the next decision.
