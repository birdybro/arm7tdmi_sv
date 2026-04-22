#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def run_checked(cmd):
    print("+", " ".join(str(part) for part in cmd))
    subprocess.run(cmd, check=True)


def main():
    parser = argparse.ArgumentParser(
        description="Generate a MAME debugger script, normalize a raw MAME trace, and compare it to an RTL trace"
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
        "--skip-normalize",
        action="store_true",
        help="Use an existing normalized MAME trace instead of regenerating it",
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
