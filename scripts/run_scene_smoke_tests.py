#!/usr/bin/env python3
"""Run Godot headless scene-loading smoke tests.

The runner performs a headless editor import pass before loading scenes. Fresh
checkouts do not have .godot/global_script_class_cache.cfg or imported assets,
and Godot autoload parsing depends on that generated state.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


DEFAULT_REPO = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = "res://scripts/scene_smoke_scenes.json"
GODOT_BIN_NAMES = [
    "godot",
    "godot4",
    "Godot_v4.6.2-stable_win64_console.exe",
]


def find_godot_bin(explicit: str) -> str:
    candidates = [
        explicit,
        os.environ.get("GODOT_BIN", ""),
        *[shutil.which(name) or "" for name in GODOT_BIN_NAMES],
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate
    raise RuntimeError("Godot executable not found. Set GODOT_BIN or pass --godot-bin.")


def run_command(command: list[str], repo: Path, timeout_seconds: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
        timeout=timeout_seconds,
        check=False,
    )


def run_import_pass(godot_bin: str, repo: Path, timeout_seconds: int) -> int:
    command = [
        godot_bin,
        "--headless",
        "--editor",
        "--quit",
        "--path",
        str(repo),
    ]
    print("SCENE_SMOKE_IMPORT: " + " ".join(command))
    try:
        completed = run_command(command, repo, timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        output = _timeout_output(exc)
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        print(f"SCENE_SMOKE_RESULTS: FAIL (import timeout after {timeout_seconds}s)")
        return 124

    if completed.returncode != 0:
        if completed.stdout:
            print(completed.stdout, end="" if completed.stdout.endswith("\n") else "\n")
        print(f"SCENE_SMOKE_RESULTS: FAIL (import exit code {completed.returncode})")
        return completed.returncode
    return 0


def run_smoke(args: argparse.Namespace) -> int:
    repo = args.repo.resolve()
    godot_bin = find_godot_bin(args.godot_bin)

    if not args.skip_import:
        import_code = run_import_pass(godot_bin, repo, args.import_timeout_seconds)
        if import_code != 0:
            return import_code

    command = [
        godot_bin,
        "--headless",
        "--path",
        str(repo),
        "-s",
        "res://tools/scene_smoke_test.gd",
        "--",
        f"--scene-smoke-config={args.scene_list}",
    ]

    print("SCENE_SMOKE_RUNNER: " + " ".join(command))
    try:
        completed = run_command(command, repo, args.timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        output = _timeout_output(exc)
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        print(f"SCENE_SMOKE_RESULTS: FAIL (timeout after {args.timeout_seconds}s)")
        return 124

    output = completed.stdout or ""
    if output:
        print(output, end="" if output.endswith("\n") else "\n")

    if args.report_json:
        report = {
            "command": command,
            "exit_code": completed.returncode,
            "scene_list": args.scene_list,
        }
        Path(args.report_json).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    engine_errors = [
        line
        for line in output.splitlines()
        if line.startswith("SCRIPT ERROR:") or line.startswith("ERROR:")
    ]
    if args.fail_on_engine_error and engine_errors:
        print(f"SCENE_SMOKE_RESULTS: FAIL ({len(engine_errors)} engine errors detected)")
        return 1

    return completed.returncode


def _timeout_output(exc: subprocess.TimeoutExpired) -> str:
    output = exc.stdout or ""
    if isinstance(output, bytes):
        return output.decode("utf-8", errors="replace")
    return output


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load configured Godot scenes in headless mode.")
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO, help="Path to the Godot project.")
    parser.add_argument("--godot-bin", default="", help="Path to Godot console executable.")
    parser.add_argument("--scene-list", default=DEFAULT_CONFIG, help="res:// JSON config with a scenes array.")
    parser.add_argument("--timeout-seconds", type=int, default=120, help="Maximum smoke runtime before failing.")
    parser.add_argument("--import-timeout-seconds", type=int, default=180, help="Maximum import runtime before failing.")
    parser.add_argument("--skip-import", action="store_true", help="Skip the headless editor import pass.")
    parser.add_argument("--report-json", default="", help="Optional path for a JSON runner report.")
    parser.add_argument("--fail-on-engine-error", action="store_true", help="Fail when Godot prints ERROR or SCRIPT ERROR lines.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    try:
        return run_smoke(parse_args(argv))
    except RuntimeError as exc:
        print(f"SCENE_SMOKE_RESULTS: FAIL ({exc})", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
