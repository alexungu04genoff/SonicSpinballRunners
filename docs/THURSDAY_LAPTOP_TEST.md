# Thursday laptop test — 19 November 2026

Extract the complete ZIP to a writable folder. No editor, repository, rebake, Python, or installation is needed.

## Work laptop with shell scripts blocked

Use the separate **Thursday-No-Shell-2026-11-19.zip** release asset. Its root contains
**Run Work Laptop Matrix.exe** and **Visual Grounding Lab.exe**. Double-click
these directly, in that order, with no other Godot diagnostics running. The
original frozen Thursday ZIP remains unchanged.

The EXEs launch the original frozen engine directly, without CMD, PowerShell,
elevation, registry changes, installation, or security-policy changes. They use
the Windows .NET Framework 4.x runtime. Every retained payload file is verified
against a SHA-256 manifest derived from the original archive before launch.
The matrix keeps the same eight cases, renderer arguments, sample durations,
240/420-second case limits, and 20-minute overall budget. Failed cases remain
failed, with their partial results retained.

All generated files go into **Results** beside the two EXEs. The payload stays
immutable under **Frozen Payload**; the launcher prepares a verified working
copy under **Results/Runtime** and isolated diagnostic profiles under
**Results/diagnostic-user**. Return the **Work-Laptop-...** and **Visual-Lab-...**
result folders. Do not launch both EXEs simultaneously. On a multi-monitor
desktop, launcher and game windows start on the non-primary monitor.

Build-machine source lives in `tools/no_shell_grounding/Launcher.cs` and
`tools/package_grounding_no_shell.ps1`. That PowerShell script only assembles
the separate package on the development machine; it is not shipped or used at
runtime. The packager accepts only the qualified original archive hash
`84C18A4D1BC193374AD3084E2804457D1727228C3D6FB7721A39D9A8C22FE707`.

Allow 2 GB of free local space for extraction, the verified runtime copy and
results. Build-machine verification is reproducible with the standard-library
Python helper `tools/verify_grounding_no_shell.py --original <frozen.zip>
--package <no-shell.zip> --extracted <folder>`, after running the extracted
matrix EXE with `--verify-only`. Neither Python nor this helper is delivered
or required on the work laptop.

Development-machine verification passed all eight original matrix cases. The
direct Lab reaches interactive readiness and writes its report. Closing its
window exposed an existing frozen asynchronous-cleanup error; the wrapper
correctly retains that failed run. Escape is the Lab's existing own close
control. No frozen code or failure rule was changed to hide the window-close
error. Preserve partial/failed Lab results as well as matrix results.

## Original frozen package instructions

1. Plug the laptop into power.
2. Select Windows **Best performance** power mode.
3. Close other games, browsers with heavy tabs, and rendering jobs where possible.
4. Run **Run Work Laptop Matrix.cmd**. Let it finish; the maximum budget is 20 minutes. Failed renderer runs still save useful results.
5. Run **Visual Grounding Lab.cmd**.
6. Inspect these three comparisons: **Production vs Side-key** (F1); **Side-key vs Side-key + proxies** (F1, then F5 to reveal alignment); **Production quality vs Balanced** (F10). F7 switches identical camera positions, F8 cycles the seven themes, F4 toggles Retro, and F9 saves a screenshot with measurements. Proxy trials exist only for Rooftop, Sky, Ice and Chemical. F2 changes sun direction; F3 shows caster/receiver/world bounds. Mode 4 is an expensive diagnostic ceiling.
7. Return the entire **Results** folder. All screenshots, JSON/CSV measurements, GPU details and logs are gathered there. Keep partial/failed runs too.

Everything is process-local. Closing the lab restores normal launch behavior. Lava Reef is excluded from this investigation.
