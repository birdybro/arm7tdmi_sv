#!/usr/bin/env python3
import argparse
from pathlib import Path


def parse_int(text: str) -> int:
    return int(text, 0)


def parse_placeholder(spec: str):
    parts = spec.split(":")
    if len(parts) not in (2, 3):
        raise argparse.ArgumentTypeError(
            f"invalid placeholder spec '{spec}', expected name:size[:fill]"
        )
    name = parts[0]
    size = parse_int(parts[1])
    fill = parse_int(parts[2]) if len(parts) == 3 else 0
    return name, size, fill & 0xFF


def load_memh_bytes(path: Path) -> bytes:
    data = bytearray()
    for lineno, raw_line in enumerate(path.read_text().splitlines(), 1):
        line = raw_line.split("//", 1)[0].strip()
        if not line:
            continue
        token = line.lower().removeprefix("0x")
        if len(token) != 2:
            raise SystemExit(
                f"{path}:{lineno}: expected one byte per line in hex, got '{raw_line}'"
            )
        try:
            data.append(int(token, 16))
        except ValueError as exc:
            raise SystemExit(f"{path}:{lineno}: invalid hex byte '{raw_line}'") from exc
    return bytes(data)


def main():
    parser = argparse.ArgumentParser(
        description="Prepare a disposable MAME ROM set directory from a byte-oriented memh image"
    )
    parser.add_argument("--memh", required=True, type=Path, help="Input byte-per-line memh")
    parser.add_argument(
        "--set-name", required=True, help="MAME ROM set directory name, e.g. cm2005"
    )
    parser.add_argument(
        "--rom-name",
        required=True,
        help="ROM filename expected by the target MAME driver",
    )
    parser.add_argument(
        "--rom-size",
        required=True,
        type=parse_int,
        help="Final ROM size in bytes; image is padded with 0x00",
    )
    parser.add_argument(
        "--output-root",
        required=True,
        type=Path,
        help="Root rompath directory to populate",
    )
    parser.add_argument(
        "--fill-byte",
        type=parse_int,
        default=0,
        help="Padding byte value, default 0x00",
    )
    parser.add_argument(
        "--placeholder-rom",
        action="append",
        type=parse_placeholder,
        default=[],
        help="Additional placeholder ROM file as name:size[:fill], may be specified multiple times",
    )
    args = parser.parse_args()

    image = bytearray(load_memh_bytes(args.memh))
    if len(image) > args.rom_size:
        raise SystemExit(
            f"input image too large: {len(image)} bytes exceeds rom-size {args.rom_size}"
        )

    image.extend([args.fill_byte & 0xFF] * (args.rom_size - len(image)))

    set_dir = args.output_root / args.set_name
    set_dir.mkdir(parents=True, exist_ok=True)
    rom_path = set_dir / args.rom_name
    rom_path.write_bytes(image)

    for name, size, fill in args.placeholder_rom:
        (set_dir / name).write_bytes(bytes([fill]) * size)

    print(
        f"wrote {rom_path} ({len(image)} bytes) from {args.memh} for MAME set {args.set_name}"
    )
    for name, size, fill in args.placeholder_rom:
        print(
            f"wrote placeholder {(set_dir / name)} ({size} bytes, fill=0x{fill:02x})"
        )


if __name__ == "__main__":
    main()
