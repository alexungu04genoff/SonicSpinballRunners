"""Build compact AO review media and tables from a completed native evidence run."""

import argparse
import csv
import json
from pathlib import Path

import numpy as np
from PIL import Image

from summarize_retro_shadow_lab import frame, label, movie, plate


CANDIDATES = [("off", "A   Off"), ("native", "B   Native subtle"), ("coarse", "C   Coarse SSAO"),
              ("clean4", "D   Clean 4"), ("ordered4", "E   Ordered 4"), ("authored", "F   Authored faces")]


def changes(a, b):
    delta = np.asarray(b, dtype=np.int16) - np.asarray(a, dtype=np.int16)
    return {"mean_abs_rgb": round(float(np.mean(np.abs(delta))), 4),
            "changed_3_of_255_pct": round(float(np.mean(np.abs(delta).max(axis=2) >= 3) * 100), 3),
            "max_rgb_delta": int(np.abs(delta).max())}


def summarize(source, output, first_use=()):
    report = json.loads((source / "report.json").read_text(encoding="utf-8"))
    if not report["complete"] or not any(r.get("runtime") == "Endless" for r in report["rows"]):
        raise ValueError("A completed full evidence run is required.")
    output.mkdir(parents=True, exist_ok=True)
    for scene, title in [("stairs", "Stairs and shelf"), ("tube", "Rooftop Run · Launch Tube")]:
        cells = [(caption, frame(source / f"{scene}-{mode}.png")) for mode, caption in CANDIDATES]
        plate(output, scene + ".jpg", title + "   /   native shadows   /   full Retro", cells, 3, (448, 315))
    # Inspect tiny tonal changes with untouched source pixels and lossless compression.
    detail_modes = [("off","Off"),("native","Native subtle"),("clean8","Clean 8"),
                    ("clean4","Clean 4"),("ordered4","Ordered 4"),("authored","Authored faces")]
    detail_sheet = Image.new("RGB", (960, 518), "#171924")
    label(detail_sheet, (10,5), "Riser junction   /   original pixels   /   full Retro", 20)
    for i, (mode, title) in enumerate(detail_modes):
        x, y = 320 * (i % 3), 38 + 240 * (i // 3)
        label(detail_sheet, (x+7,y), title, 17)
        detail_sheet.paste(frame(source / f"stairs-{mode}.png").crop((500,176,820,388)), (x,y+28))
    detail_sheet.save(output / "contact-detail.png")
    pairs = [("continuous", "Continuous contact"), ("clean8", "Clean 8"), ("clean4", "Clean 4"),
             ("clean3", "Clean 3"), ("clean2", "Clean 2"), ("ordered4", "Ordered 4")]
    plate(output, "bands.jpg", "One contact field   /   fixed pose   /   full Retro",
          [(name, frame(source / f"stairs-{key}.png").crop((165, 170, 1055, 720))) for key, name in pairs],
          3, (445, 275))
    plate(output, "ordered.jpg", "Ordered contact   /   world anchoring   /   full Retro",
          [(f"{n}×{n} · {cell} mm · width {width}",
            frame(source / f"ordered-{n}-{cell:03d}.png").crop((165, 170, 1055, 720)))
           for n, cell, width in [(2,25,0.35),(2,75,0.55),(4,45,0.55),(4,100,0.80)]], 2, (445,275))
    themes = [r["fixture"] for r in report["rows"] if r.get("mode") == "off" and
              r.get("fixture") not in (None, "stairs")]
    for i, group in enumerate([themes[:4], themes[4:]]):
        cells = []
        for theme in group:
            for key, name in [("off", "Off"), ("native", "Native"), ("clean4", "Clean 4"), ("authored", "Authored")]:
                cells.append((theme.replace("_", " ").title() + " · " + name, frame(source / f"{theme}-{key}.png")))
        plate(output, f"themes-{i+1}.jpg", "Held Prototype pose   /   Profile B   /   full Retro",
              cells, 4, (320, 225))
    cells = []
    for scene in ("stairs", "tube"):
        for shadow, ao, name in [(0, 0, "Native · AO off"), (0, 8, "Native · authored AO"),
                                 (5, 8, "Clean 8 · authored AO"), (2, 8, "Clean 4 · authored AO")]:
            cells.append((name, frame(source / f"pair-{scene}-{shadow}-{ao}.png")))
    plate(output, "shadow-pairs.jpg", "Native, Clean 8 and Clean 4 shadows   /   full Retro", cells, 4, (340, 239))
    cells = [(f"{scale}% · {mode}", frame(source / f"scale-{scale}-{mode}.png").crop((165, 170, 1055, 720)))
             for scale in (85, 100) for mode in ("native", "coarse", "clean4")]
    plate(output, "scale.jpg", "Native 3D scale   /   Profile B shadow settings   /   full Retro", cells, 3, (390, 241))
    plate(output, "fixtures.jpg", "Rooftop Run   /   moving gameplay fixtures   /   full Retro",
          [(caption, frame(source / (key + ".png"))) for key, caption in [
              ("act-1-moving","RampMania · flipper held"), ("act-2-moving","Side to Side · bumper in motion"),
              ("score-chute","Score chute"), ("act-3-moving","Launch Tube release")]], 2, (450, 316))

    def motion(scene, tick, variants):
        rows = (len(variants) + 2) // 3
        sheet = Image.new("RGB", (1080, 38 + rows * 282), "#171924")
        label(sheet, (9, 4), ("Stair study · moving block" if scene == "stairs" else "Rooftop Run · pan and zoom")
              + "   /   full Retro", 20)
        for i, (index, title) in enumerate(variants):
            x, y = (i % 3) * 360, 38 + (i // 3) * 282
            label(sheet, (x + 6, y + 2), title, 16)
            img = frame(source / f"motion-{scene}-{index}-{tick:02d}.png")
            sheet.paste(img.resize((360, 252), Image.Resampling.LANCZOS), (x, y + 28))
        return sheet

    sweep = list(range(24)) + list(range(22, 0, -1))
    for filename, entries in [("motion.mp4", [(0,"Off"),(1,"Native"),(2,"Coarse"),(4,"Clean 4"),(8,"Ordered 4 · world"),(5,"Authored")]),
                              ("anchors.mp4", [(6,"Ordered · screen"),(7,"Ordered · object"),(8,"Ordered · world")])]:
        movie(output, filename, (motion(scene, tick, entries) for scene in ("stairs","rooftop_run")
                                 for tick in sweep), 15)

    detail = []
    with (output / "rtx4060.csv").open("w", newline="", encoding="utf-8") as file:
        w = csv.writer(file)
        w.writerow(["fixture","mode","open_ms","activation_ms","warm24_median_ms","warm24_max_ms",
                    "median_ms","p95_ms","pan_median_ms","pan_p95_ms","visible_draws","visible_primitives",
                    "shadow_draws","resource_count","video_bytes","receivers","private_materials","programs","new_pipelines",
                    "visible_objects","shadow_objects","shadow_primitives"])
        for r in report["rows"]:
            if "fixture" not in r:
                detail.append(r)
                continue
            inv, pan = r["inventory"], r.get("pan", {})
            w.writerow([r["fixture"],r["mode"],r["startup_ms"],r["activation_ms"],r["warm24"]["median_ms"],
                        r["warm24"]["max_ms"],r["frame"]["median_ms"],r["frame"]["p95_ms"],pan.get("median_ms"),
                        pan.get("p95_ms"),r["visible"]["draws"],r["visible"]["primitives"],r["shadow"]["draws"],
                        r["resources"],r["video_bytes"],inv["receivers"],inv["materials"],inv["programs"],
                        int(sum(r["pipelines_after"].values()) - sum(r["pipelines_before"].values())),
                        r["visible"]["objects"],r["shadow"]["objects"],r["shadow"]["primitives"]])
    pair_labels = ["Native", "Native", "Clean 8", "Clean 4"]
    pair_order = {}
    for case in detail:
        if case.get("runtime") == "Shadow pair":
            scene = case["fixture_name"]
            index = pair_order.get(scene, 0)
            case.setdefault("shadow_mode", pair_labels[index])
            pair_order[scene] = index + 1
        if case.get("runtime") == "Direct light":
            theme, mode = case["fixture_name"], case["mode"]
            case.update(changes(frame(source / f"{theme}-direct-off.png"), frame(source / f"{theme}-direct-{mode}.png")))
    for folder in first_use:
        first = json.loads((folder / "report.json").read_text(encoding="utf-8"))
        if (not first["complete"] or first["metadata"]["device"] != report["metadata"]["device"]
                or [r.get("phase") for r in first["rows"]] != ["first", "repeat"]
                or any(r.get("runtime") != "Isolated first use" for r in first["rows"])):
            raise ValueError(f"Invalid first-use run in {folder}")
        detail.extend(first["rows"])
    summary = {"renderer": {k: report["metadata"][k] for k in ("engine","renderer","driver","device","api")},
               "checks": len(report["checks"]), "orphans": report["orphan_nodes"], "studies": detail,
               "differences": {s: {key: changes(frame(source / f"{s}-off.png"), frame(source / f"{s}-{key}.png"))
                                     for key in ("native","coarse","continuous","clean8","clean4","clean3","clean2","ordered4","authored")
                                     if (source / f"{s}-{key}.png").exists()} for s in ["stairs","tube"] + themes}}
    (output / "measurements.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--first-use", nargs="*", type=Path, default=[])
    args = parser.parse_args()
    summarize(args.capture, args.output, args.first_use)
