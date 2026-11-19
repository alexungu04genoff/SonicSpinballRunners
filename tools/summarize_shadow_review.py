"""Read one Shadow Review.cmd Results folder. Write CSV to standard output."""
import argparse
import csv
import json
import sys
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}


def case_row(folder, runtime, profile, cache_pass, exit_status):
    report = read(folder / "report.json") or read(folder / "startup-failed.json")
    teardown = read(folder / "teardown.json")
    problems = list(report.get("failures", []))
    if exit_status != "0" or not report or not teardown:
        problems.append(f"incomplete or failed process (exit {exit_status})")
    if teardown.get("remaining_project_owners") or teardown.get("orphan_nodes"):
        problems.append("see teardown.json")
    if report.get("fallback_builds") or report.get("user_settings_written"):
        problems.append("fallback build or device settings write")
    settings = report.get("settings", {})
    view = next((v for v in settings.get("viewports", []) if v["role"] == "foreground"), {})
    times = report.get("timing_by_phase_and_work", {})
    stationary = times.get("first_stationary_settled/settled", {})
    moving = times.get("tour_100px_s/settled" if runtime == "endless" else "prototype_camera_sweep/settled", {})
    preparation = report.get("zone_preparation", {})
    transition = times.get("zone_transition/zone_overlap", {})
    if runtime == "endless" and not (preparation.get("backdrop_and_entry_ready") and transition and times.get("post_transition_settled/settled")):
        problems.append("next Zone preparation or crossing incomplete")
    if not stationary or not moving:
        problems.append("missing stationary or moving-camera samples")
    return {
        "runtime": runtime, "profile": profile, "cache": cache_pass,
        "outcome": " | ".join(problems) if problems else "pass",
        "device": report.get("metadata", {}).get("device"),
        "atlas_px_submitted": settings.get("shadow_atlas_applied"), "cascades": settings.get("cascade_count"),
        "filter_submitted": settings.get("filter_quality_submitted"), "fxaa": settings.get("fxaa"),
        "msaa": view.get("msaa_samples"), "native_scale": view.get("scale"), "retro": settings.get("retro_name"),
        "startup_ms": report.get("startup_ms"),
        "startup_shader_phase_max_frame_ms": times.get("startup/shader_material_warmup", {}).get("max_ms"),
        "stationary_median_ms": stationary.get("median_ms"), "stationary_p95_ms": stationary.get("p95_ms"),
        "moving_median_ms": moving.get("median_ms"), "moving_p95_ms": moving.get("p95_ms"),
        "tour_400_median_ms": times.get("tour_400px_s/settled", {}).get("median_ms"),
        "next_zone_ready_ms": preparation.get("after_startup_ms"),
        "transition_overlap_p95_ms": transition.get("p95_ms"),
        "boundary_wait_frames": sum(v["count"] for k, v in times.items() if k.endswith("/boundary_wait")),
        "fallback_builds": report.get("fallback_builds"), "orphan_nodes": teardown.get("orphan_nodes"),
        "remaining_project_owners": teardown.get("remaining_project_owners"),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path)
    root = parser.parse_args().results
    statuses = {}
    status_file = root / "status.txt"
    if status_file.exists():
        for line in status_file.read_text().splitlines():
            runtime, profile, cache_pass, status = line.split()
            statuses[runtime, profile, cache_pass] = status.removeprefix("exit=")
    rows = []
    for runtime in ("prototype", "endless"):
        profiles = ["production", "quality", "performance"]
        if runtime == "endless":
            profiles.extend(["neither", "ultra-only", "both"])
        for profile in profiles:
            for cache_pass in ("first", "repeat"):
                key = runtime, profile, cache_pass
                rows.append(case_row(root / "-".join(key), *key, statuses.get(key, "unknown")))
    writer = csv.DictWriter(sys.stdout, rows[0].keys(), lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return int(any(row["outcome"] != "pass" for row in rows))


if __name__ == "__main__":
    sys.exit(main())
