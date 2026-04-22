#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def run_checked(cmd):
    print("+", " ".join(str(part) for part in cmd))
    subprocess.run(cmd, check=True)


def has_nonempty_file(path: Path) -> bool:
    return path.is_file() and path.stat().st_size > 0


def parse_env_assignment(text: str):
    key, sep, value = text.partition("=")
    if not sep or not key:
        raise argparse.ArgumentTypeError(
            f"invalid environment assignment '{text}', expected NAME=value"
        )
    return key, value


def main():
    parser = argparse.ArgumentParser(
        description="Generate a MAME debugger script, optionally launch MAME, normalize a raw MAME trace, and compare it to an RTL trace"
    )
    parser.add_argument(
        "--machine",
        help="MAME machine name to launch; if omitted, MAME execution is skipped",
    )
    parser.add_argument("--cpu", required=True, help="MAME CPU tag or index")
    parser.add_argument(
        "--stop",
        required=True,
        help="MAME debugger stop expression or address for the generated script",
    )
    parser.add_argument(
        "--rtl-trace", required=True, type=Path, help="RTL JSONL retire trace"
    )
    parser.add_argument(
        "--raw-trace", required=True, type=Path, help="Raw MAME debugger trace path"
    )
    parser.add_argument(
        "--norm-trace", required=True, type=Path, help="Normalized MAME JSONL trace path"
    )
    parser.add_argument(
        "--debug-script",
        required=True,
        type=Path,
        help="Rendered MAME debugger script path",
    )
    parser.add_argument(
        "--fields",
        default="pc,cpsr,r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14",
        help="Comma-separated fields to compare",
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=SCRIPT_DIR / "mame_debug_trace_template.cmd",
        help="Debugger script template",
    )
    parser.add_argument(
        "--skip-render",
        action="store_true",
        help="Use an existing debugger script instead of regenerating it",
    )
    parser.add_argument(
        "--skip-mame",
        action="store_true",
        help="Skip launching MAME and use an existing raw trace file",
    )
    parser.add_argument(
        "--skip-normalize",
        action="store_true",
        help="Use an existing normalized MAME trace instead of regenerating it",
    )
    parser.add_argument(
        "--mame-bin",
        default="mame",
        help="MAME executable to launch when --machine is provided",
    )
    parser.add_argument(
        "--mame-arg",
        action="append",
        default=[],
        help="Extra argument to pass through to MAME; may be specified multiple times",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the MAME command but do not execute it",
    )
    parser.add_argument(
        "--allow-mame-failure-if-trace",
        action="store_true",
        help="Continue if MAME exits nonzero but still produced a fresh non-empty raw trace",
    )
    parser.add_argument(
        "--mame-env",
        action="append",
        type=parse_env_assignment,
        default=[],
        help="Environment assignment for MAME launch as NAME=value; may be specified multiple times",
    )
    args = parser.parse_args()

    if not args.skip_render:
        run_checked(
            [
                sys.executable,
                str(SCRIPT_DIR / "render_mame_debug_script.py"),
                "--template",
                str(args.template),
                "--cpu",
                args.cpu,
                "--trace-output",
                str(args.raw_trace),
                "--stop",
                args.stop,
                "--output",
                str(args.debug_script),
            ]
        )

    if args.machine and not args.skip_mame:
        prior_stat = args.raw_trace.stat() if args.raw_trace.exists() else None
        if args.raw_trace.exists():
            args.raw_trace.unlink()

        mame_cmd = [
            args.mame_bin,
            args.machine,
            "-debug",
            "-debugscript",
            str(args.debug_script),
            *args.mame_arg,
        ]
        if args.dry_run:
            print("+", " ".join(str(part) for part in mame_cmd))
        else:
            print("+", " ".join(str(part) for part in mame_cmd))
            env = os.environ.copy()
            for key, value in args.mame_env:
                env[key] = value
            result = subprocess.run(mame_cmd, check=False, env=env)
            if result.returncode != 0:
                fresh_trace = has_nonempty_file(args.raw_trace)
                if prior_stat and fresh_trace:
                    stat = args.raw_trace.stat()
                    fresh_trace = (
                        stat.st_mtime_ns != prior_stat.st_mtime_ns
                        or stat.st_size != prior_stat.st_size
                    )
                if args.allow_mame_failure_if_trace and fresh_trace:
                    print(
                        f"warning: MAME exited with code {result.returncode}, "
                        f"but continuing because {args.raw_trace} was freshly generated"
                    )
                else:
                    raise SystemExit(f"MAME failed with exit code {result.returncode}")

    if not args.skip_normalize:
        run_checked(
            [
                sys.executable,
                str(SCRIPT_DIR / "mame_trace_to_json.py"),
                "--input",
                str(args.raw_trace),
                "--output",
                str(args.norm_trace),
            ]
        )

    run_checked(
        [
            sys.executable,
            str(SCRIPT_DIR / "compare_arm7tdmi_traces.py"),
            "--rtl",
            str(args.rtl_trace),
            "--ref",
            str(args.norm_trace),
            "--fields",
            args.fields,
        ]
    )


if __name__ == "__main__":
    main()
