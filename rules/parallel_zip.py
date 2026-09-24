#!/usr/bin/env python3
# Copyright 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Parallel zip archive builder driving 7-Zip and streaming zip from a rules_pkg manifest."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import zipfile

DEFAULT_EPOCH = 315532800  # 1980-01-01 00:00:00 UTC (ZIP MS-DOS minimum epoch)


def _create_argument_parser():
    parser = argparse.ArgumentParser(
        description="Create a zip archive using 7-Zip or direct zip streaming",
        fromfile_prefix_chars="@",
    )
    parser.add_argument("--sevenzip", required=True, help="Path to 7za executable")
    parser.add_argument("-o", "--output", required=True, help="Output zip file path")
    parser.add_argument(
        "-d",
        "--directory",
        default="/",
        help="Prefix to prepend to all paths inside the zip",
    )
    parser.add_argument(
        "-t",
        "--timestamp",
        type=int,
        default=DEFAULT_EPOCH,
        help="Unix timestamp to set on files in the archive (default: 315532800 / 1980-01-01)",
    )
    parser.add_argument(
        "--stamp_from",
        default="",
        help="File to find BUILD_TIMESTAMP in",
    )
    parser.add_argument(
        "-m",
        "--mode",
        default="0555",
        help="Default file mode (e.g. 0555 or 0755)",
    )
    parser.add_argument(
        "-c",
        "--compression_type",
        default="deflated",
        choices=["deflated", "stored", "lzma", "bzip2"],
        help="Compression type: deflated, stored, lzma, bzip2",
    )
    parser.add_argument(
        "-l",
        "--compression_level",
        type=int,
        default=6,
        help="Compression level (0-9)",
    )
    parser.add_argument(
        "--manifest",
        required=True,
        help="Manifest JSON file containing contents to package",
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="Optional files in {src}={dst} or {src} format",
    )
    return parser


def _combine_paths(left: str, right: str) -> str:
    combined = left.rstrip("/") + "/" + right.lstrip("/")
    return combined.lstrip("/")


def _get_timestamp(args) -> int:
    ts = max(DEFAULT_EPOCH, args.timestamp)
    if args.stamp_from:
        stamp_path = Path(args.stamp_from)
        if stamp_path.exists():
            try:
                for line in stamp_path.read_text(encoding="utf-8").splitlines():
                    parts = line.strip().split()
                    if len(parts) > 1 and parts[0] == "BUILD_TIMESTAMP":
                        ts = max(DEFAULT_EPOCH, int(parts[1]))
                        break
            except Exception:
                pass
    return ts


def _get_compression_args(compression_type: str, level: int) -> list[str]:
    ctype = compression_type.lower()
    if ctype == "stored" or level == 0:
        return ["-mx=0"]
    elif ctype == "deflated":
        return ["-mm=Deflate", f"-mx={level}"]
    elif ctype == "bzip2":
        return ["-mm=BZip2", f"-mx={level}"]
    elif ctype == "lzma":
        return ["-mm=LZMA", f"-mx={level}"]
    else:
        raise ValueError(f"Unsupported compression type: {compression_type}")


def _setup_environment() -> None:
    """Configures global process environment for deterministic zip packaging."""
    os.environ["TZ"] = "UTC"
    if hasattr(time, "tzset"):
        time.tzset()


def _load_manifest_entries(
    manifest_path: Path, cli_files: list[str] | None
) -> list[dict]:
    """Loads manifest entries from JSON and appends any extra CLI file mappings."""
    if not manifest_path.exists():
        sys.stderr.write(f"Manifest file not found: {manifest_path}\n")
        sys.exit(1)

    entries: list[dict] = json.loads(manifest_path.read_text(encoding="utf-8"))
    if cli_files:
        for f in cli_files:
            if "=" in f:
                src, dst = f.split("=", 1)
            else:
                src = dst = f
            entries.append({"type": "file", "src": src, "dest": dst})
    return entries


def _create_empty_zip(output_path: Path) -> None:
    """Creates a standard 22-byte empty ZIP archive directly."""
    if output_path.exists():
        output_path.unlink()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_path, "w") as _:
        pass


def _build_dest_map(
    entries: list[dict],
    dir_prefix: str,
    default_mode: int,
) -> dict[str, dict]:
    """Flattens and validates manifest entries into a normalized destination map with parent directories."""
    dest_map: dict[str, dict] = {}

    for entry in entries:
        etype = entry.get("type", "file")
        raw_dest = entry.get("dest", "").replace("\\", "/").strip("/")
        if not raw_dest:
            continue

        dest_rel = _combine_paths(dir_prefix, raw_dest)
        mode_str = entry.get("mode")
        mode = int(mode_str, 8) if mode_str else default_mode

        if etype == "tree":
            src_str = entry.get("src")
            if not src_str:
                raise ValueError(f"Missing 'src' for tree entry: {dest_rel}")
            src_dir = Path(src_str)
            if not src_dir.exists():
                raise FileNotFoundError(f"Manifest source tree not found: {src_dir}")
            dest_map[dest_rel.rstrip("/") + "/"] = {
                "type": "dir",
                "mode": 0o755,
            }
            for root, dirs, files in os.walk(src_dir, followlinks=True):
                rel_root = Path(root).relative_to(src_dir)
                for d in dirs:
                    d_dest = _combine_paths(dest_rel, str(rel_root / d).replace("\\", "/")) + "/"
                    dest_map[d_dest] = {
                        "type": "dir",
                        "mode": 0o755,
                    }
                for f in files:
                    fp = Path(root) / f
                    f_dest = _combine_paths(dest_rel, str(rel_root / f).replace("\\", "/"))
                    file_mode = (
                        int(mode_str, 8)
                        if mode_str
                        else (0o755 if os.access(fp, os.X_OK) else default_mode)
                    )
                    dest_map[f_dest] = {
                        "type": "file",
                        "src": str(fp),
                        "mode": file_mode,
                    }
        elif etype == "dir":
            dest_map[dest_rel.rstrip("/") + "/"] = {
                "type": "dir",
                "mode": mode if mode_str else 0o755,
            }
        elif etype in ("symlink", "link"):
            src_str = entry.get("src")
            if not src_str:
                raise ValueError(f"Missing 'src' (link target) for symlink: {dest_rel}")
            dest_map[dest_rel.rstrip("/")] = {
                "type": "symlink",
                "src": src_str.replace("\\", "/"),
                "mode": mode,
            }
        elif etype in ("empty_file", "empty-file"):
            dest_map[dest_rel.rstrip("/")] = {
                "type": "empty_file",
                "mode": mode,
            }
        elif etype == "file":
            src_str = entry.get("src")
            if not src_str:
                raise ValueError(f"Missing 'src' for file entry: {dest_rel}")
            src_path = Path(src_str)
            if not src_path.exists() and not src_path.is_symlink():
                raise FileNotFoundError(f"Manifest source file not found: {src_path}")
            dest_map[dest_rel.rstrip("/")] = {
                "type": "file",
                "src": src_str,
                "mode": mode,
            }
        else:
            raise ValueError(f"Unknown manifest entry type: {etype}")

    if not dest_map:
        return {}

    # Synthesize intermediate parent directory entries for all items
    for dest in list(dest_map.keys()):
        parts = dest.strip("/").split("/")
        for i in range(1, len(parts)):
            parent = "/".join(parts[:i]) + "/"
            if parent not in dest_map:
                dest_map[parent] = {"type": "dir", "mode": 0o755}

    return dest_map


def create_zip_stored(
    output_path: Path,
    entries: list[dict],
    dir_prefix: str,
    default_mode: int,
    timestamp: int,
) -> None:
    """Creates a ZIP archive using direct in-memory streaming with zero filesystem staging.

    Used for compression_level = 0 (stored mode). Bypasses all intermediate file copies,
    normalizes POSIX permissions and forward slashes, handles symlinks in-memory,
    and ensures bit-for-bit determinism across Linux, macOS, and Windows.
    """
    if output_path.exists():
        output_path.unlink()

    dest_map = _build_dest_map(entries, dir_prefix, default_mode)
    if not dest_map:
        _create_empty_zip(output_path)
        return

    ts = max(DEFAULT_EPOCH, timestamp)
    gm = time.gmtime(ts)
    dt = (max(1980, gm.tm_year), gm.tm_mon, gm.tm_mday, gm.tm_hour, gm.tm_min, gm.tm_sec)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_STORED) as zf:
        for dest in sorted(dest_map.keys()):
            item = dest_map[dest]
            itype = item["type"]
            mode = item["mode"]

            if itype == "dir":
                clean_dest = dest.rstrip("/") + "/"
                zinfo = zipfile.ZipInfo(filename=clean_dest, date_time=dt)
                zinfo.create_system = 3  # UNIX
                zinfo.external_attr = (0o040000 | mode) << 16
                zf.writestr(zinfo, b"")

            elif itype == "symlink":
                target = item["src"]
                clean_dest = dest.rstrip("/")
                zinfo = zipfile.ZipInfo(filename=clean_dest, date_time=dt)
                zinfo.create_system = 3  # UNIX
                zinfo.external_attr = (0o120000 | mode) << 16
                zf.writestr(zinfo, target)

            elif itype == "empty_file":
                clean_dest = dest.rstrip("/")
                zinfo = zipfile.ZipInfo(filename=clean_dest, date_time=dt)
                zinfo.create_system = 3  # UNIX
                zinfo.external_attr = (0o100000 | mode) << 16
                zf.writestr(zinfo, b"")

            elif itype == "file":
                src = Path(item["src"])
                clean_dest = dest.rstrip("/")
                zinfo = zipfile.ZipInfo(filename=clean_dest, date_time=dt)
                zinfo.create_system = 3  # UNIX
                zinfo.external_attr = (0o100000 | mode) << 16

                with open(src, "rb") as fsrc:
                    with zf.open(zinfo, "w") as fdst:
                        shutil.copyfileobj(fsrc, fdst, length=1024 * 1024)


def create_zip_deflated(
    sevenzip_bin: Path,
    output_path: Path,
    entries: list[dict],
    dir_prefix: str,
    default_mode: int,
    timestamp: int,
    compression_args: list[str],
) -> None:
    """Creates a ZIP archive using 7-Zip zero-staging path mapping.

    Used for compression_level > 0 (deflated mode). Emits a deterministic
    mode-annotated listfile consumed directly by 7za with parallel compression.
    """
    if output_path.exists():
        output_path.unlink()

    dest_map = _build_dest_map(entries, dir_prefix, default_mode)
    if not dest_map:
        _create_empty_zip(output_path)
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    listfile_path = output_path.parent / (output_path.name + ".list")

    lines = [f"#time:{max(DEFAULT_EPOCH, timestamp)}"]
    for dest in sorted(dest_map.keys()):
        item = dest_map[dest]
        itype = item["type"]
        mode = item["mode"]
        mode_str = f"{mode:04o}"

        if itype == "dir":
            clean_dest = dest.rstrip("/") + "/"
            lines.append(f"{mode_str}:{clean_dest}")
        elif itype == "symlink":
            clean_dest = dest.rstrip("/")
            target = item["src"]
            lines.append(f"{mode_str}:{clean_dest}->{target}")
        elif itype == "empty_file":
            clean_dest = dest.rstrip("/")
            lines.append(f"{mode_str}:{clean_dest}=")
        elif itype == "file":
            clean_dest = dest.rstrip("/")
            src = item["src"]
            lines.append(f"{mode_str}:{clean_dest}={src}")
        else:
            raise ValueError(f"Unknown manifest entry type: {itype}")

    cmd = (
        [
            str(sevenzip_bin),
            "a",
            "-tzip",
        ]
        + compression_args
        + [
            "-mmt=on",
            "-bd",
            "-bso0",
            "-bsp0",
            "-snl",
            "-r-",
            "-mtc=off",
            "-scsUTF-8",
            "-mcu=on",
            "-y",
            str(output_path),
            f"@{listfile_path}",
        ]
    )

    env = dict(os.environ)
    env["TZ"] = "UTC"
    env["LANG"] = "en_US.UTF-8"
    env["LC_CTYPE"] = "UTF-8"

    try:
        listfile_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env=env,
        )
        if proc.returncode != 0:
            sys.stderr.write(
                f"7za failed with exit code {proc.returncode}:\n"
                f"{proc.stderr}\n{proc.stdout}\n"
            )
            sys.exit(proc.returncode)
    finally:
        if listfile_path.exists():
            try:
                listfile_path.unlink()
            except OSError:
                pass


def main() -> None:
    _setup_environment()

    parser = _create_argument_parser()
    args = parser.parse_args()

    timestamp = _get_timestamp(args)
    default_mode = int(args.mode, 8) if args.mode else 0o555
    compression_args = _get_compression_args(
        args.compression_type, args.compression_level
    )

    manifest_path = Path(args.manifest)
    entries = _load_manifest_entries(manifest_path, args.files)
    output_path = Path(args.output).resolve()

    if args.compression_type.lower() == "stored" or args.compression_level == 0:
        create_zip_stored(
            output_path=output_path,
            entries=entries,
            dir_prefix=args.directory,
            default_mode=default_mode,
            timestamp=timestamp,
        )
    else:
        create_zip_deflated(
            sevenzip_bin=Path(args.sevenzip).resolve(),
            output_path=output_path,
            entries=entries,
            dir_prefix=args.directory,
            default_mode=default_mode,
            timestamp=timestamp,
            compression_args=compression_args,
        )


if __name__ == "__main__":
    main()
