"""Record the character's Green Hill Acts on a secondary monitor, then assemble the MP4."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
STAGES = ("Plunger Lane", "Spin Alley", "Spring Meadow", "Dash Causeway", "Rail Terrace",
          "Loop Clearing", "Special Arena", "Trick Garden", "Animation Green")
CAPTURES = ROOT / "test-results" / "character-reels"
DELIVERY = ROOT / "test-results" / "Green Hill Character Reels"


def encode(actor, indexes):
    rows = [row for index in indexes for row in json.loads(index.read_text(encoding="utf-8"))]
    offset = 0
    blocks = [";FFMETADATA1"]
    for row in rows:
        end = offset + row["frames"]
        blocks.extend(["[CHAPTER]", "TIMEBASE=1/30", f"START={offset}", f"END={end}",
                       "title=" + row["stage"] + " / " + row["title"]])
        offset = end
    metadata = CAPTURES / actor / "chapters.ffmetadata"
    metadata.write_text("\n".join(blocks) + "\n", encoding="utf-8")
    DELIVERY.mkdir(parents=True, exist_ok=True)
    draft = CAPTURES / actor / (actor + ".mp4")
    with subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "image2pipe",
                           "-framerate", "30", "-c:v", "mjpeg", "-i", "-", "-i", str(metadata),
                           "-map", "0:v", "-map_chapters", "1", "-an", "-c:v", "libx264",
                           "-preset", "veryfast", "-crf", "16", "-pix_fmt", "yuv420p",
                           "-movflags", "+faststart", str(draft)], stdin=subprocess.PIPE) as encoder:
        for row in rows:
            folder = ROOT / row["folder"].removeprefix("res://")
            for i in range(row["frames"]):
                encoder.stdin.write((folder / f"{i:03}.jpg").read_bytes())
        encoder.stdin.close()
        if encoder.wait():
            raise RuntimeError("FFmpeg failed to encode the compilation")
    subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(draft), "-f", "null", "-"], check=True)
    info = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_chapters",
                                               "-show_streams", "-of", "json", str(draft)]))
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    if int(video["nb_frames"]) != offset or len(info["chapters"]) != len(rows):
        raise RuntimeError("Unexpected chapter or frame count")
    target = DELIVERY / draft.name
    os.replace(draft, target)
    print(f"{target} | {video['width']}x{video['height']} | {offset / 30:.2f}s | {len(rows)} chapters", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("actor", help="Playable character ID, for example sonic, tails or knuckles")
    parser.add_argument("--godot", default=shutil.which("godot") or "C:/Program Files/Godot/Godot.exe")
    parser.add_argument("--screen", type=int, required=True, help="Godot index of the non-primary display")
    parser.add_argument("--stage", choices=STAGES, action="append", help="Record only the listed Acts")
    parser.add_argument("--resume", action="store_true", help="Reuse previously completed chapter indexes")
    args = parser.parse_args()
    indexes = []
    failed = []
    for stage in args.stage or STAGES:
        directory = CAPTURES / args.actor / stage
        directory.mkdir(parents=True, exist_ok=True)
        index = directory / "index.json"
        indexes.append(index)
        if args.resume and index.exists():
            continue
        index.unlink(missing_ok=True)
        log = directory / "capture.log"
        print("Recording", args.actor, stage, flush=True)
        result = subprocess.run([args.godot, "--path", str(ROOT), "--screen", str(args.screen),
                                 "--fullscreen", "--rendering-method", "forward_plus", "--rendering-driver", "vulkan",
                                 "--audio-driver", "Dummy", "--fixed-fps", "30", "--script",
                                 "res://experiments/character_reels/capture.gd", "--log-file", str(log),
                                 "--", args.actor, stage], cwd=ROOT, stdout=subprocess.DEVNULL, timeout=360)
        if result.returncode or not index.exists():
            failed.append(stage)
            print(log.read_text(encoding="utf-8", errors="replace")[-1200:], flush=True)
    if failed:
        raise SystemExit("Incomplete Acts: " + ", ".join(failed))
    if not args.stage:
        encode(args.actor, indexes)


if __name__ == "__main__":
    main()
