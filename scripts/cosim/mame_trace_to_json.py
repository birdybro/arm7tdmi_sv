#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


PAIR_RE = re.compile(r"([a-zA-Z0-9_]+)=([0-9a-fA-Fx]+)")


def parse_line(line: str):
    if "COSIM" not in line:
        return None
    fields = {key.lower(): value.lower().removeprefix("0x") for key, value in PAIR_RE.findall(line)}
    if "pc" not in fields or "cpsr" not in fields:
        return None
    return fields


def main():
    parser = argparse.ArgumentParser(description="Normalize MAME ARM7 trace lines to JSONL")
    parser.add_argument("--input", required=True, type=Path, help="Raw MAME debugger trace")
    parser.add_argument("--output", required=True, type=Path, help="Normalized JSONL output")
    args = parser.parse_args()

    seq = 0
    with args.input.open() as src, args.output.open("w") as dst:
        for line in src:
            parsed = parse_line(line)
            if parsed is None:
                continue
            parsed["seq"] = seq
            dst.write(json.dumps(parsed) + "\n")
            seq += 1

    print(f"normalized {seq} trace lines from {args.input} to {args.output}")


if __name__ == "__main__":
    main()
