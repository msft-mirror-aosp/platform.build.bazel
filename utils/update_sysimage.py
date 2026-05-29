#!/usr/bin/env python3
"""Script to update system images in MODULE.bazel (Internal Google use only)."""

import argparse
from dataclasses import dataclass
import difflib
import hashlib
import logging
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import List, Optional, Tuple

# --- Constants ---
FETCH_ARTIFACT = "/google/data/ro/projects/android/fetch_artifact"
DEFAULT_BUCKET = "gs://emu-next-bazel"

# Regex patterns for finding blocks in MODULE.bazel
GOOG_DICT_PATTERN = r"(goog\s*=\s*\{.*?\})"
GCS_ARCHIVE_PATTERN = r'(gcs_archive\s*\(\s*name\s*=\s*"{archive}".*?\))'

# Regex patterns for updating attributes within a block
URL_PATTERN = r'url\s*=\s*"[^"]*"'
SHA256_PATTERN = r'sha256\s*=\s*"[^"]*"'
DICT_URL_PATTERN = r'"url"\s*:\s*"[^"]*"'
DICT_SHA256_PATTERN = r'"sha256"\s*:\s*"[^"]*"'


@dataclass(frozen=True)
class ImageTarget:
    """Represents a system image target and its associated metadata."""

    arch: str
    is_16k: bool

    @property
    def archive_name(self) -> str:
        """Name used in MODULE.bazel markers and archive attributes."""
        arch_suffix = "-arm64-v8a" if self.arch == "arm64" else f"-{self.arch}"
        a_suffix = "16k" if self.is_16k else ""
        return f"android{a_suffix}{arch_suffix}"

    @property
    def target_name(self) -> str:
        """Internal Android Build target name."""
        k_suffix = "16k" if self.is_16k else "64"
        return f"sdk_gphone{k_suffix}_{self.arch}-userdebug"

    def get_gcs_path(self, bucket: str, build_id: str) -> str:
        """Full GCS path for the image zip."""
        zip_filename = f"sdk-repo-linux-system-images-{build_id}.zip"
        return f"{bucket}/sys-img/{self.target_name}/{zip_filename}"


def setup_logging(verbose: bool = False) -> None:
    """Configures the logging module."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level, format="%(levelname)s: %(message)s", stream=sys.stderr
    )


def run_command(
    args: List[str],
    capture_output: bool = True,
    check: bool = True,
    text: bool = True,
) -> subprocess.CompletedProcess:
    """Wrapper for subprocess.run with common defaults."""
    logging.debug(f"Running: {' '.join(args)}")
    try:
        return subprocess.run(
            args, capture_output=capture_output, check=check, text=text
        )
    except subprocess.CalledProcessError as e:
        logging.debug(f"Command failed with exit code {e.returncode}")
        if e.stderr:
            logging.debug(f"Error output: {e.stderr}")
        raise


def calculate_sha256(file_path: Path) -> str:
    """Calculates the SHA256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def find_source_block(
    content: str, target: ImageTarget
) -> Tuple[Optional[str], Optional[str]]:
    """Finds the source block and the surrounding marker block in MODULE.bazel content."""
    archive = target.archive_name
    start_marker = f"# BEGIN {archive}"
    end_marker = f"# END {archive}"

    pattern = re.compile(
        f"({re.escape(start_marker)}.*?{re.escape(end_marker)})", re.DOTALL
    )
    match = pattern.search(content)
    if not match:
        return None, None

    block = match.group(1)

    # 1. Try to find goog dict (new multisource_repo style)
    goog_match = re.search(GOOG_DICT_PATTERN, block, re.DOTALL)
    if goog_match:
        return goog_match.group(1), block

    # 2. Try to find legacy gcs_archive style
    gcs_match = re.search(
        GCS_ARCHIVE_PATTERN.format(archive=re.escape(archive)), block, re.DOTALL
    )
    if gcs_match:
        return gcs_match.group(1), block

    return None, block


def validate_targets(
    targets: List[ImageTarget], module_file: Path
) -> Tuple[bool, Optional[str]]:
    """Checks if all targets have the required markers in MODULE.bazel."""
    with open(module_file, "r") as f:
        content = f.read()

    missing = [t.archive_name for t in targets if not find_source_block(content, t)[0]]

    if missing:
        error_msg = (
            f"Error: Required markers or source blocks for the following targets "
            f"were not found in {module_file}:\n  "
            + "\n  ".join(missing)
            + "\n\nPlease ensure your MODULE.bazel contains both # BEGIN <target> and "
            "# END <target> markers surrounding a valid 'gcs_archive' or 'multisource_repo' block.\n"
            "\nUse --force to ignore this check and proceed anyway."
        )
        return False, error_msg

    return True, None


def check_gcs_existence(gcs_path: str) -> bool:
    """Checks if a file already exists on Google Cloud Storage."""
    try:
        run_command(["gcloud", "storage", "ls", gcs_path])
        return True
    except subprocess.CalledProcessError:
        return False


def fetch_and_hash(target: ImageTarget, build_id: str) -> Optional[str]:
    """Downloads the artifact and returns its SHA256 hash."""
    zip_filename = f"sdk-repo-linux-system-images-{build_id}.zip"
    zip_path = Path(zip_filename)

    logging.info(f"Fetching {zip_filename} for {target.target_name}...")
    try:
        run_command(
            [
                FETCH_ARTIFACT,
                "--bid",
                build_id,
                "--target",
                target.target_name,
                zip_filename,
            ],
            capture_output=False,
        )
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        logging.error(f"Failed to fetch artifact for {target.archive_name}: {e}")
        logging.error(
            "Hint: Ensure you have active 'gcert' credentials and internal network access."
        )
        return None

    logging.info(f"Calculating SHA256 for {zip_filename}...")
    try:
        return calculate_sha256(zip_path)
    except Exception as e:
        logging.error(f"Failed to calculate hash: {e}")
        return None


def upload_to_gcs(zip_path: Path, gcs_path: str) -> bool:
    """Uploads a local file to GCS."""
    logging.info(f"Uploading {zip_path} to {gcs_path}...")
    try:
        run_command(
            ["gcloud", "storage", "cp", str(zip_path), gcs_path], capture_output=False
        )
        return True
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to upload to GCS: {e}")
        return False


def update_target(
    target: ImageTarget,
    build_id: str,
    gcs_bucket: str,
    force: bool,
    dry_run: bool,
    current_content: str,
) -> str:
    """Coordinates the update process for a single system image target."""
    logging.info("-" * 50)
    logging.info(f"Processing {target.archive_name}...")
    logging.info("-" * 50)

    gcs_full_path = target.get_gcs_path(gcs_bucket, build_id)
    zip_path = Path(f"sdk-repo-linux-system-images-{build_id}.zip")

    # 1. Existence check
    exists_on_gcs = check_gcs_existence(gcs_full_path)
    if exists_on_gcs:
        logging.info(f"Object {gcs_full_path} already exists on GCS.")
        logging.info(
            f"If you believe this image is corrupt, use --force to overwrite it, "
            f"or manually delete it using: gcloud storage rm {gcs_full_path}"
        )

    # 2. Fetch and Hash
    sha256 = fetch_and_hash(target, build_id)
    if not sha256:
        return current_content

    # 3. Upload (if needed)
    try:
        if not dry_run and (not exists_on_gcs or force):
            if not upload_to_gcs(zip_path, gcs_full_path):
                return current_content
        elif dry_run:
            logging.info(f"Dry-run: Skipping upload to {gcs_full_path}.")

        # 4. Prepare updated content
        source_block, full_marker_block = find_source_block(current_content, target)
        if not source_block:
            logging.warning(
                f"Markers or source block not found for {target.archive_name}. Skipping."
            )
            return current_content

        if source_block.strip().startswith("goog"):
            updated_source = re.sub(
                DICT_URL_PATTERN, f'"url": "{gcs_full_path}"', source_block
            )
            updated_source = re.sub(
                DICT_SHA256_PATTERN, f'"sha256": "{sha256}"', updated_source
            )
        else:
            updated_source = re.sub(
                URL_PATTERN, f'url = "{gcs_full_path}"', source_block
            )
            updated_source = re.sub(
                SHA256_PATTERN, f'sha256 = "{sha256}"', updated_source
            )

        new_marker_block = full_marker_block.replace(source_block, updated_source)
        logging.info(f"Successfully prepared update for {target.archive_name}.")
        return current_content.replace(full_marker_block, new_marker_block)

    finally:
        if zip_path.exists():
            zip_path.unlink()


def check_prerequisites() -> None:
    """Verifies that all required tools and authentications are available."""
    if not shutil.which("gcloud"):
        logging.error("Error: 'gcloud' not found. Please install Google Cloud SDK.")
        sys.exit(1)

    try:
        res = run_command(
            [
                "gcloud",
                "auth",
                "list",
                "--filter=status:ACTIVE",
                "--format=value(account)",
            ]
        )
        if not res.stdout.strip():
            logging.error("Error: No active gcloud account. Run 'gcloud auth login'.")
            sys.exit(1)
    except subprocess.CalledProcessError as e:
        logging.warning(f"Could not verify gcloud authentication: {e}")

    if not Path(FETCH_ARTIFACT).exists():
        logging.error(
            f"Error: {FETCH_ARTIFACT} not found. This script requires internal Android build access."
        )
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Update system images in MODULE.bazel (Internal Google use only).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-b", "--build-id", required=True, help="Android build ID to fetch."
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose logging."
    )
    parser.add_argument("--gcs-bucket", help="Override target GCS bucket.")
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Force upload even if file exists on GCS.",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Show diff without uploading or modifying.",
    )
    args = parser.parse_args()

    setup_logging(args.verbose)
    check_prerequisites()

    # Find MODULE.bazel relative to script
    script_dir = Path(__file__).parent
    module_file = (
        script_dir.parent
        / "registry"
        / "modules"
        / "goldfish"
        / "0.0.1"
        / "MODULE.bazel"
    )
    if not module_file.exists():
        logging.error(f"Module file not found: {module_file}")
        sys.exit(1)

    gcs_bucket = args.gcs_bucket or os.environ.get(
        "AEMU_BUILD_GCS_BUCKET", DEFAULT_BUCKET
    )
    targets = [ImageTarget("x86_64", True), ImageTarget("arm64", True)]

    if not args.force:
        success, error_msg = validate_targets(targets, module_file)
        if not success:
            logging.error(error_msg)
            sys.exit(1)

    original_content = module_file.read_text()
    current_content = original_content

    for target in targets:
        current_content = update_target(
            target, args.build_id, gcs_bucket, args.force, args.dry_run, current_content
        )

    if args.dry_run:
        logging.info("Dry-run complete. Showing diff:")
        diff = difflib.unified_diff(
            original_content.splitlines(keepends=True),
            current_content.splitlines(keepends=True),
            fromfile=f"a/{module_file}",
            tofile=f"b/{module_file}",
        )
        sys.stdout.writelines(diff)
    elif current_content != original_content:
        logging.info(f"Writing updates to {module_file}...")
        module_file.write_text(current_content)
        logging.info("Update process complete.")
    else:
        logging.info("No changes were made to MODULE.bazel.")


if __name__ == "__main__":
    main()
