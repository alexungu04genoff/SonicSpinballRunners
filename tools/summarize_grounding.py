"""Build review sheets and compact tables from real grounding-lab captures.

Build-machine utility only; Thursday's portable launchers need no Python.
Requires Pillow and NumPy. Source captures remain unchanged.
"""
import argparse
import csv
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

THEMES = ["green_hill", "chemical_plant", "rooftop_run", "casino_night",
          "sky_sanctuary", "ice_cap", "aquarium_park"]
PROXY_THEMES = ["rooftop_run", "sky_sanctuary", "ice_cap", "chemical_plant"]
DIRECTIONS = ["Production", "Camera-left", "Camera-right", "Rays up-table",
              "Rays down-table", "High key 70 deg", "Low key 20 deg"]
MODES = ["0 Production", "1 Side-key", "2 Current + proxies", "3 Side-key + proxies",
         "4 All-near ceiling", "5 Shadows off"]
FONT = Path("C:/Windows/Fonts/arial.ttf")


def font(size):
    return ImageFont.truetype(str(FONT), size)


def title(theme):
    return theme.replace("_", " ").title()


def sheet(path, heading, cells, columns=3, width=480, subtitle="", crop=None):
    height = 333 if crop is None else 300
    rows = (len(cells) + columns - 1) // columns
    canvas = Image.new("RGB", (columns * width, 110 + rows * (height + 42)), "#141a23")
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 16), heading, font=font(28), fill="white")
    draw.text((20, 57), subtitle, font=font(17), fill="#b8c7db")
    for i, (label, source) in enumerate(cells):
        x, y = (i % columns) * width, 110 + (i // columns) * (height + 42)
        draw.text((x + 10, y + 6), label, font=font(18), fill="white")
        if source is not None and source.exists():
            picture = Image.open(source).convert("RGB")
            if crop is not None:
                picture = picture.crop(crop)
            picture.thumbnail((width - 8, height), Image.Resampling.LANCZOS)
            canvas.paste(picture, (x + (width - picture.width) // 2, y + 36))
    canvas.save(path)


def differences(first, second):
    a = np.asarray(Image.open(first).convert("RGB"), dtype=np.int16)
    b = np.asarray(Image.open(second).convert("RGB"), dtype=np.int16)
    delta = np.abs(a - b)
    changed = np.any(delta > 0, axis=2)
    ys, xs = np.where(changed)
    return {"changed_pixels": int(changed.sum()), "fraction": float(changed.mean()),
            "mean_channel_delta": float(delta.mean()), "maximum_channel_delta": int(delta.max()),
            "bounds": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else None}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--preferred", default="", help="theme:index,theme:index; defaults to camera-right")
    parser.add_argument("--matrix", type=Path, help="Use only this completed matrix for published timing tables")
    parser.add_argument("--review-directory", type=Path, help="Write compact JPEG review sheets and measurements for repository documentation")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    preferred = {theme: 2 for theme in THEMES}
    preferred.update({key: int(value) for key, value in (part.split(":") for part in args.preferred.split(",") if part)})
    summary = {"preferred": preferred, "visual": {}, "runs": {}}
    overview = []
    for theme in THEMES:
        folder = args.results / ("visual-" + theme)
        if not (folder / "report.json").exists():
            continue
        report = json.loads((folder / "report.json").read_text(encoding="utf-8-sig"))
        cells = []
        for retro in ["production", "off"]:
            for index, name in enumerate(DIRECTIONS):
                cells.append((f"{name} / Retro {retro}", folder / f"sweep_{retro}_{index}.png"))
            cells.append(("Only direction changes; ambient retained", None))
        sheet(args.output / f"{theme}-sun-sweep.png", title(theme) + " | directional sweep", cells, 4,
              subtitle="Same canonical Act, frozen camera/state and quality. No albedo, normal, roughness or ambient edits.")
        overview.extend([(title(theme) + " / Production", folder / "sweep_production_0.png"),
                         (title(theme) + " / " + ("Keep production" if preferred[theme] == 0 else DIRECTIONS[preferred[theme]]), folder / f"sweep_production_{preferred[theme]}.png")])
        checks = {}
        for retro in ["production", "off"]:
            checks["restore_" + retro] = differences(folder / f"sweep_{retro}_0.png", folder / f"restored_{retro}.png")
        if theme in PROXY_THEMES:
            direction_folder = args.results / ("proxy-directions-" + theme)
            checks["proxy_direction_pairs"] = {
                str(i): differences(direction_folder / f"proxy_direction_{i}_0.png", direction_folder / f"proxy_direction_{i}_1.png")
                for i in range(7) if (direction_folder / f"proxy_direction_{i}_1.png").exists()}
            mode_cells = [(f"{name} / Retro {retro}", folder / f"grounding_{retro}_source_{index}.png")
                          for retro in ["production", "off"] for index, name in enumerate(MODES)]
            sheet(args.output / f"{theme}-six-modes.png", title(theme) + " | six diagnostic modes", mode_cells,
                  subtitle="Identical edge camera. Source silhouettes. Mode 4 is a non-shipping cost ceiling.")
            proxy_cells = [(f"{method} / {MODES[mode]} / {retro}", folder / f"grounding_{retro}_{method}_{mode}.png")
                           for retro in ["production", "off"] for mode in [2, 3] for method in ["source", "hull"]]
            sheet(args.output / f"{theme}-source-vs-hull.png", title(theme) + " | silhouette vs coarse hull", proxy_cells, 4,
                  subtitle="World transforms copied exactly; no scenery repositioned. Receipts include every selected component.")
            crop_regions = {"Edge contact": (550, 320, 910, 680), "Wall and floor": (400, 530, 760, 890),
                            "Floor normals": (70, 200, 430, 560), "Ball and hardware": (160, 400, 520, 760)}
            for name, box in crop_regions.items():
                sheet(args.output / f"{theme}-crop-{name.lower().replace(' ', '-')}.png", title(theme) + " | " + name,
                      [(MODES[i], folder / f"grounding_off_source_{i}.png") for i in range(6)], 3, width=400,
                      subtitle="Retro OFF. Identical fixed crop across all six modes; location is recorded in evidence-summary.json.", crop=box)
            checks["crop_regions"] = crop_regions
            for retro in ["production", "off"]:
                for pair in [(0, 2), (1, 3), (0, 4), (0, 5)]:
                    checks[f"{retro}_mode{pair[0]}_vs_{pair[1]}"] = differences(folder / f"grounding_{retro}_source_{pair[0]}.png", folder / f"grounding_{retro}_source_{pair[1]}.png")
                checks[f"{retro}_source_vs_hull_side_key"] = differences(folder / f"grounding_{retro}_source_3.png", folder / f"grounding_{retro}_hull_3.png")
        summary["visual"][theme] = {"integrity": report.get("integrity_checks"), "failures": report["failures"], "differences": checks,
                                     "captures": report["captures"], "counter_summary": report["sampled_counter_summary"]}
    sheet(args.output / "seven-theme-comparison.png", "Seven themes | production and diagnostic direction", overview, 2, 640,
          subtitle="Direction-only candidates. No production recommendation is implied by a darker image; proxies remain off.")
    sheet(args.output / "proxy-alignment.png", "Coarse hull alignment | magenta reveal",
          [(title(theme), args.results / ("visual-" + theme) / "alignment_off.png") for theme in PROXY_THEMES], 2, 640,
          subtitle="Foreground hulls use exact source transforms. Visible scenery stays in its own backdrop world.")
    sheet(args.output / "shadow-ownership.png", "Shadow ownership | live instance bounds",
          [(f"{title(theme)} / {kind}", args.results / ("visual-" + theme) / f"ownership_{kind}.png")
           for theme in ["rooftop_run", "sky_sanctuary"] for kind in ["casters", "shadowless"]], 2, 640,
          subtitle="Green: authored Decor. Cyan: other foreground. Gold: backdrop. Flags show eligibility; BG lights are shadowless.")
    if args.matrix:
        prototype = args.matrix / "01-prototype-production"
        endless = args.matrix / "02-endless-production"
        a = json.loads((prototype / "report.json").read_text(encoding="utf-8-sig"))
        e = json.loads((endless / "report.json").read_text(encoding="utf-8-sig"))
        states = [capture["state"] for report in [a, e] for capture in report["captures"]
                  if capture["label"].startswith("architecture_")]
        summary["matrix_matching"] = {"initial_states_equal": a["initial_state"] == e["initial_state"],
                                      "all_architecture_capture_states_equal": all(state == states[0] for state in states),
                                      "normal_runtime_huds_and_presentation_helpers_retained": True}
        architecture = [("A / normal Prototype", prototype / "architecture_A_0.png")]
        architecture.extend((f"{case} / Endless", endless / f"architecture_{case}_{index}.png")
                            for index, case in enumerate(["B", "C", "D", "E", "C"]))
        sheet(args.output / "architecture-opening.png", "Matched opening | Prototype and Endless", architecture,
              subtitle="Same Act, camera/projection, resolution, quality, atmosphere and frozen gameplay. Normal route HUDs retained.")
        sheet(args.output / "architecture-overlap.png", "Zone overlap | backdrop and residency controls",
              [(f"{case} / frozen camera during overlap", endless / f"overlap_architecture_{case}.png") for case in ["C", "D", "E", "B"]], 2, 640,
              subtitle="C normal / D no next backdrop / E no backdrops / B active Act and current backdrop only.")
        quality_cells = [(folder.name[3:], folder / "stationary_baseline.png") for folder in sorted(args.matrix.iterdir()) if folder.is_dir()]
        sheet(args.output / "quality-renderers.png", "Desktop quality and renderer controls", quality_cells, 4,
              subtitle="Rooftop, identical camera. Diagnostics only; measured frame cost does not establish UHD 620 performance.")
        sheet(args.output / "retro-passes.png", "Retro | native preset appearance",
              [(label, endless / f"retro_native_preset_{index}.png") for index, label in [(0,"OFF"),(1,"Pixel / Dither"),(2,"N64-ish"),(3,"CRT"),(4,"VHS"),(-1,"Production combined")]],
              subtitle="Native presets change internal resolution. Separate matched-pixel measurements isolate composition cost.")
    timing_rows = []
    inventory_rows = []
    reports = list(args.matrix.rglob("report.json")) if args.matrix else list(args.results.rglob("report.json"))
    if args.matrix:
        reports.extend(args.results.glob("visual-*/report.json"))
        reports.extend(args.results.glob("proxy-directions-*/report.json"))
        reports.extend(args.results.glob("lifecycle-final/report.json"))
    for report_path in reports:
        if "diagnostic-user" in report_path.parts:
            continue
        report = json.loads(report_path.read_text(encoding="utf-8-sig"))
        name = str(report_path.parent.relative_to(args.results))
        summary["runs"][name] = {key: report.get(key) for key in ["metadata", "startup_ms", "native_camera_far", "initial_state", "initial_settings",
                                                               "timing_by_phase_and_work", "sampled_counter_summary", "cpu_stage_totals", "cpu_stage_maxima",
                                                               "fallback_builds", "failures", "restoration_checks", "integrity_checks", "lifecycle_checks"]}
        for phase, values in report.get("timing_by_phase_and_work", {}).items():
            timing_rows.append({"run": name, "phase": phase, **values})
        inventory_path = report_path.parent / "inventory.json"
        if inventory_path.exists():
            inventory = json.loads(inventory_path.read_text(encoding="utf-8-sig"))
            counts = {}
            for row in inventory["meshes"]:
                key = (row["world"], row["category"], row["cast_shadow"])
                count = counts.setdefault(key, {"meshes": 0, "instances": 0, "surfaces": 0, "triangles": 0, "transparent_meshes": 0})
                for field, addition in [("meshes", 1), ("instances", row["instances"]), ("surfaces", row["surfaces"]), ("triangles", row["triangles"]),
                                        ("transparent_meshes", int(any(mat["transparent"] for mat in row["materials"])) )]:
                    count[field] += addition
            for (world, category, casts), values in counts.items():
                inventory_rows.append({"run": name, "world": world, "category": category, "cast_flag": casts, **values})
    for filename, rows in [("timings.csv", timing_rows), ("ownership.csv", inventory_rows)]:
        if rows:
            fields = list(dict.fromkeys(key for row in rows for key in row))
            with (args.output / filename).open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(stream, fieldnames=fields)
                writer.writeheader()
                writer.writerows(rows)
    (args.output / "evidence-summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    if args.review_directory:
        args.review_directory.mkdir(parents=True, exist_ok=True)
        for source in args.output.glob("*.png"):
            Image.open(source).convert("RGB").save(args.review_directory / (source.stem + ".jpg"), quality=90, subsampling=0, optimize=True)
        compact = {**summary, "visual": {theme: {key: value for key, value in row.items() if key not in ["captures", "counter_summary"]} for theme, row in summary["visual"].items()}}
        (args.review_directory / "measurements.json").write_text(json.dumps(compact, indent=2), encoding="utf-8")
        for name in ["timings.csv", "ownership.csv"]:
            (args.review_directory / name).write_bytes((args.output / name).read_bytes())
    print(f"Grounding evidence: {args.output}; {len(summary['visual'])} themes, {len(summary['runs'])} runs")


if __name__ == "__main__":
    main()
