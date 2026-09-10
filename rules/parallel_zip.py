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
"""Parallel zip archive builder driving 7-Zip from a rules_pkg manifest."""

import argparse
import contextlib
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
        description="Create a zip archive using 7-Zip",
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


def _safe_dest_path(staging_root: Path, rel_path: str) -> Path:
    """Resolves target path and guarantees it remains inside the staging root."""
    target = (staging_root / rel_path).resolve()
    try:
        target.relative_to(staging_root)
    except ValueError:
        raise ValueError(
            f"Path traversal detected: destination '{rel_path}' resolves outside staging root"
        )
    return target


def _force_rmtree(path: Path) -> None:
    """Removes a directory tree, resetting read-only permissions on failure (Windows)."""
    if not path.exists():
        return

    def _on_error(func, p, _):
        try:
            os.chmod(p, 0o777)
            func(p)
        except OSError:
            pass

    shutil.rmtree(path, onerror=_on_error)


def _safe_remove_target(target: Path) -> None:
    """Safely removes an existing target whether it is a directory, file, or symlink."""
    if target.is_dir() and not target.is_symlink():
        _force_rmtree(target)
    elif target.exists() or target.is_symlink():
        try:
            target.unlink()
        except OSError:
            pass


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


def _stage_file(src: Path, target: Path, mode: int, timestamp: int) -> None:
    if not src.exists() and not src.is_symlink():
        raise FileNotFoundError(f"Manifest source file not found: {src}")
    target.parent.mkdir(parents=True, exist_ok=True)
    _safe_remove_target(target)
    shutil.copyfile(src, target)
    target.chmod(mode)
    try:
        os.utime(target, (timestamp, timestamp), follow_symlinks=False)
    except (OSError, NotImplementedError):
        pass


def _stage_symlink(link_target: str, target: Path, timestamp: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    _safe_remove_target(target)
    target.symlink_to(link_target)
    try:
        os.utime(target, (timestamp, timestamp), follow_symlinks=False)
    except (OSError, NotImplementedError):
        pass


def _stage_empty_file(target: Path, mode: int, timestamp: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    _safe_remove_target(target)
    target.write_bytes(b"")
    target.chmod(mode)
    try:
        os.utime(target, (timestamp, timestamp), follow_symlinks=False)
    except (OSError, NotImplementedError):
        pass


def _stage_dir(target: Path, mode: int = 0o755) -> None:
    target.mkdir(parents=True, exist_ok=True)
    target.chmod(mode)


def _stage_tree(
    src_dir: Path,
    target_dir: Path,
    default_mode: int,
    mode_str: str | None,
    timestamp: int,
) -> None:
    if not src_dir.exists():
        raise FileNotFoundError(f"Manifest source tree not found: {src_dir}")
    target_dir.mkdir(parents=True, exist_ok=True)
    target_dir.chmod(0o755)
    for root, dirs, files in os.walk(src_dir, followlinks=True):
        rel_root = Path(root).relative_to(src_dir)
        for d in dirs:
            tp = target_dir / rel_root / d
            tp.mkdir(parents=True, exist_ok=True)
            tp.chmod(0o755)
        for f in files:
            p = Path(root) / f
            tp = target_dir / rel_root / f
            if mode_str:
                file_mode = int(mode_str, 8)
            else:
                file_mode = 0o755 if os.access(p, os.X_OK) else default_mode
            _stage_file(p, tp, file_mode, timestamp)


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


@contextlib.contextmanager
def _staging_environment(output_path: Path):
    """Context manager setting up an isolated staging dir and listfile, ensuring cleanup."""
    staging_dir = output_path.parent / (output_path.name + ".staging")
    listfile_path = output_path.parent / (output_path.name + ".list")

    _force_rmtree(staging_dir)
    staging_dir.mkdir(parents=True, exist_ok=True)
    try:
        yield staging_dir, listfile_path
    finally:
        _force_rmtree(staging_dir)
        if listfile_path.exists():
            try:
                listfile_path.unlink()
            except OSError:
                pass


def _stage_manifest_entries(
    entries: list[dict],
    staging_dir: Path,
    dir_prefix: str,
    default_mode: int,
    timestamp: int,
) -> None:
    """Populates the staging directory according to manifest entry specifications."""
    for entry in entries:
        etype = entry.get("type", "file")
        raw_dest = entry.get("dest", "").strip("/")
        if not raw_dest:
            continue

        dest_rel = _combine_paths(dir_prefix, raw_dest)
        target = _safe_dest_path(staging_dir, dest_rel)

        src_str = entry.get("src")
        mode_str = entry.get("mode")
        mode = int(mode_str, 8) if mode_str else default_mode

        if etype == "file":
            if not src_str:
                raise ValueError(f"Missing 'src' for file entry: {dest_rel}")
            _stage_file(Path(src_str), target, mode, timestamp)
        elif etype == "tree":
            if not src_str:
                raise ValueError(f"Missing 'src' for tree entry: {dest_rel}")
            _stage_tree(Path(src_str), target, default_mode, mode_str, timestamp)
        elif etype in ("symlink", "link"):
            if not src_str:
                raise ValueError(
                    f"Missing 'src' (link target) for symlink entry: {dest_rel}"
                )
            _stage_symlink(src_str, target, timestamp)
        elif etype == "dir":
            _stage_dir(target, mode if mode_str else 0o755)
        elif etype in ("empty_file", "empty-file"):
            _stage_empty_file(target, mode, timestamp)
        else:
            raise ValueError(f"Unknown manifest entry type: {etype}")


def _normalize_staging_metadata(staging_dir: Path, timestamp: int) -> None:
    """Normalizes directory permissions and deterministic timestamps bottom-up."""
    for root, dirs, _ in os.walk(staging_dir, topdown=False):
        for d in dirs:
            p = Path(root) / d
            if not p.is_symlink():
                try:
                    p.chmod(0o755)
                except OSError:
                    pass
            try:
                os.utime(p, (timestamp, timestamp), follow_symlinks=False)
            except (OSError, NotImplementedError):
                pass

    try:
        staging_dir.chmod(0o755)
        os.utime(staging_dir, (timestamp, timestamp))
    except OSError:
        pass


def _create_empty_zip(output_path: Path) -> None:
    """Creates a standard 22-byte empty ZIP archive directly."""
    if output_path.exists():
        output_path.unlink()
    with zipfile.ZipFile(output_path, "w") as _:
        pass


def _generate_sorted_listfile(staging_dir: Path, listfile_path: Path) -> bool:
    """Generates an explicitly sorted listfile for 7-Zip. Returns False if staging dir is empty."""
    items_to_archive: list[str] = []
    for p in staging_dir.rglob("*"):
        rel_str = str(p.relative_to(staging_dir)).replace("\\", "/")
        if p.is_dir() and not p.is_symlink():
            items_to_archive.append(rel_str + "/")
        else:
            items_to_archive.append(rel_str)

    if not items_to_archive:
        return False

    items_to_archive.sort()
    listfile_path.write_text(
        "\n".join(items_to_archive) + "\n",
        encoding="utf-8",
    )
    return True


def _run_sevenzip(
    sevenzip_bin: Path,
    output_path: Path,
    listfile_path: Path,
    staging_dir: Path,
    compression_args: list[str],
) -> None:
    """Invokes 7-Zip to produce the final archive from the staged entries."""
    if output_path.exists():
        output_path.unlink()

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

    proc = subprocess.run(
        cmd,
        cwd=staging_dir,
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

    with _staging_environment(output_path) as (staging_dir, listfile_path):
        _stage_manifest_entries(
            entries=entries,
            staging_dir=staging_dir,
            dir_prefix=args.directory,
            default_mode=default_mode,
            timestamp=timestamp,
        )
        _normalize_staging_metadata(staging_dir, timestamp)

        if not _generate_sorted_listfile(staging_dir, listfile_path):
            _create_empty_zip(output_path)
            return

        _run_sevenzip(
            sevenzip_bin=Path(args.sevenzip).resolve(),
            output_path=output_path,
            listfile_path=listfile_path,
            staging_dir=staging_dir,
            compression_args=compression_args,
        )


if __name__ == "__main__":
    main()
