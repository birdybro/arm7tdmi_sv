#!/usr/bin/env python3
import argparse
from pathlib import Path


def quote_mame_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    parser = argparse.ArgumentParser(
        description="Render a concrete MAME debugger script for ARM7TDMI co-sim"
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=Path(__file__).with_name("mame_debug_trace_template.cmd"),
        help="Debugger script template",
    )
    parser.add_argument("--cpu", required=True, help="MAME CPU tag or index")
    parser.add_argument(
        "--trace-output", required=True, type=Path, help="Raw MAME trace output path"
    )
    parser.add_argument(
        "--stop",
        required=True,
        help="MAME debugger stop expression or address for the 'g' command",
    )
    parser.add_argument(
        "--output", required=True, type=Path, help="Rendered debugger script path"
    )
    args = parser.parse_args()

    template = args.template.read_text()
    rendered = (
        template.replace("@@CPU@@", args.cpu)
        .replace("@@TRACE@@", quote_mame_string(str(args.trace_output)))
        .replace("@@STOP@@", args.stop)
    )

    args.output.write_text(rendered)
    print(f"rendered {args.output} from {args.template}")


if __name__ == "__main__":
    main()
