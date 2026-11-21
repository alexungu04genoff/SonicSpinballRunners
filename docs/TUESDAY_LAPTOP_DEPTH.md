# Tuesday UHD 620 depth test · November 24, 2026

1. Extract the complete Tuesday depth ZIP to a writable local folder. Allow 2 GB free. Plug in the laptop, use its usual high-performance power mode and close other rendering jobs.
2. Double-click **Run Tuesday Depth Matrix.exe**. Keep **Frozen Payload** beside it. The launcher verifies the payload, starts four fresh Forward+/Vulkan processes directly and writes under **Results**. No shell or Godot install is required. Allow up to 20 minutes.
3. Return the dated **Results/Work-Laptop-…** folder, including any failed cases. The launcher retains console and error logs, machine/driver information, process exits and a matrix status file. The shared runtime copy can stay on the laptop.

| Case | Native 3D scale | Cast shadow | Native SSAO quality |
| --- | ---: | --- | --- |
| smooth85 | 85% | Smooth | Medium |
| four85 | 85% | Four tones | Medium |
| four85-low-contact | 85% | Four tones | Low |
| four75 | 75% | Four tones | Medium |

All four use the existing 2048 atlas, one cascade, authored faces, 2× MSAA, FXAA and full Retro at 480 world lines. The low-contact case retains native SSAO gain, radius, half-size buffers and blur settings. Only the engine sampling tier changes. Profiles apply within each process.

The course uses the production Endless scheduler, the authored **First Try Smooth Decor** opening in Green Hill and a Chemical Plant destination. Seed 18, the same normal launch and 480 physics ticks exercise moving gameplay. The camera tour advances at 100 px/s. After locating the last Act, the probe places the tour just before the boundary and measures the real distance-driven crossfade. It records relocation separately. Window size starts at 1280 × 900 and fits the available screen. Keep display and power settings constant throughout.

Each case saves **stationary.png** and **destination.png** outside its timing phases. Each **report.json** contains frame-interval median, P95, maximum and threshold counts by phase and streaming workload, sampled render counters, actual view scale, native contacts and active cast receivers. The report includes next-Zone readiness, overlap frames, fallback builds and pipeline counter changes with their coincident frame intervals. Startup measures game creation to first playable Act. Process elapsed time includes engine launch and shutdown. Diagnostic profiles are fresh for each case. Driver and OS caches may warm across cases. A coincident compilation counter identifies a frame to investigate and cannot assign the whole stall to a shader.

Open **frame-intervals.tsv** for one row per successful case and phase, including frame count, median, P95 and maximum interval. Compare **smooth85 / four85** for cast cost, **four85 / four75** for scale and **four85 / four85-low-contact** for AO quality. Compare the same phases and workloads, especially moving play and overlap. A failed launch, missing overlap, fallback build, or wrong adapter makes that result unsuitable for a UHD 620 pacing decision. Preserve it for diagnosis. If a first-use spike dominates, rerun the same matrix after the first pass and label the two dated folders in order.

The laptop atlas/cascade reduction already applies in every case. Prefer the lower world scale next, then the lower contact tier. Review four-tone removal only if the hardware timings and playing-distance appearance warrant it. Production device defaults remain a separate decision.

## Build machine

Use an imported checkout with fresh Green Hill and Chemical Plant Endless bakes and the authored opening Act baked for both themes. Run `python tools/package_laptop_depth.py <new-output.zip>`. The package uses the established Windows .NET launcher, bundled Godot license notices and a per-file SHA-256 manifest. The frozen Thursday package remains independently reproducible.

## Desktop qualification

The extracted November 24 ZIP verified 3,583 payload files and ran all four cases on the RTX 4060. Each loaded six disk Acts and both backdrops with zero fallback builds. The identical launch displaced the Ball by 354.59 px in every case. All four recorded the crossfade, stationary and destination screenshots, and frame intervals for all seven phases. The four processes took about 50 seconds each on this desktop. [Qualification receipt and ZIP SHA-256](laptop-depth/desktop-qualification.json) · [Desktop frame intervals](laptop-depth/desktop-frame-intervals.tsv)

No script or renderer errors occurred in the delivered run. Godot emitted its existing ObjectDB warning on process exit. A separate verbose reproduction showed two plain zero-reference RefCounted objects, consistent with the documented threaded-loader issue. The launcher retains the original logs. The UHD 620 pacing and visual decision still needs Tuesday's run. [Engine lifecycle investigation](LIFECYCLE_AUDIT.md)
