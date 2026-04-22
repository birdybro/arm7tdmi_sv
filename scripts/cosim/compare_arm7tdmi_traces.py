#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path


DEFAULT_FIELDS = [
    "pc",
    "cpsr",
    "r0",
    "r1",
    "r2",
    "r3",
    "r4",
    "r5",
    "r6",
    "r7",
    "r8",
    "r9",
    "r10",
    "r11",
    "r12",
    "r13",
    "r14",
]


def load_jsonl(path: Path):
    rows = []
    with path.open() as f:
      for lineno, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"{path}:{lineno}: invalid JSON: {exc}") from exc
        rows.append(normalize_row(row))
    return rows


def normalize_value(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return f"{value:08x}"
    if isinstance(value, str):
        text = value.strip().lower()
        if text.startswith("0x"):
            text = text[2:]
        return text
    return value


def normalize_row(row):
    return {key: normalize_value(value) for key, value in row.items()}


def main():
    parser = argparse.ArgumentParser(description="Compare ARM7TDMI retire traces")
    parser.add_argument("--rtl", required=True, type=Path, help="RTL JSONL trace")
    parser.add_argument("--ref", required=True, type=Path, help="Reference JSONL trace")
    parser.add_argument(
        "--fields",
        default=",".join(DEFAULT_FIELDS),
        help="Comma-separated fields to compare",
    )
    args = parser.parse_args()

    fields = [field for field in args.fields.split(",") if field]
    rtl_rows = load_jsonl(args.rtl)
    ref_rows = load_jsonl(args.ref)

    if len(rtl_rows) != len(ref_rows):
        raise SystemExit(
            f"trace length mismatch: rtl={len(rtl_rows)} ref={len(ref_rows)}"
        )

    for index, (rtl_row, ref_row) in enumerate(zip(rtl_rows, ref_rows), 1):
        for field in fields:
            rtl_value = rtl_row.get(field)
            ref_value = ref_row.get(field)
            if rtl_value != ref_value:
                raise SystemExit(
                    f"trace mismatch at retire {index} field '{field}': "
                    f"rtl={rtl_value} ref={ref_value}"
                )

    print(
        f"trace compare passed for {len(rtl_rows)} retired instructions "
        f"across fields: {', '.join(fields)}"
    )


if __name__ == "__main__":
    main()
