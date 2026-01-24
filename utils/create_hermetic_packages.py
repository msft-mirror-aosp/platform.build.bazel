import os
import zipfile
import subprocess
import shutil
import argparse
from datetime import datetime
import json
import hashlib
import logging
import tempfile
from pathlib import Path
import re
import sys

# Try importing winreg, but don't fail if it's missing (e.g. on non-Windows)
try:
    import winreg
except ImportError:
    winreg = None

# --- Configuration & Constants ---


DEFAULT_GCS_BUCKET = "gs://emu-next-bazel/hermetic-msvc"
BAZEL_FILE_REL_PATH = Path("../extensions/toolchain.bzl")

# --- Generic Helper Functions ---


def setup_logging(verbose=False):
    """Configures the logging module."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(levelname)s - %(message)s",
        datefmt="%H:%M:%S",
    )


def get_datestamp():
    """Returns the current date and time as a YYYYMMDDHHMM string."""
    return datetime.now().strftime("%Y%m%d%H%M")


def calculate_sha256(file_path):
    """Calculates the SHA256 hash of a file."""
    logging.info(f"Calculating SHA256 for {file_path}...")
    hasher = hashlib.sha256()
    with open(file_path, "rb") as f:
        while True:
            chunk = f.read(8192)  # Read in 8KB chunks
            if not chunk:
                break
            hasher.update(chunk)
    digest = hasher.hexdigest()
    logging.debug(f"SHA256: {digest}")
    return digest


def upload_to_gcs(local_file_path, gcs_bucket_path):
    """Uploads a file to Google Cloud Storage."""
    gsutil_path = shutil.which("gsutil")
    if not gsutil_path:
        logging.error("'gsutil' command not found. Cannot upload to GCS.")
        return False

    destination = f"{gcs_bucket_path}/{Path(local_file_path).name}"
    command = [gsutil_path, "cp", str(local_file_path), destination]

    logging.info(f"Uploading to GCS: {' '.join(command)}")
    try:
        subprocess.run(command, check=True)
        logging.info("Upload completed successfully.")
        return destination
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during GCS upload: {e}")
        return None


def update_bazel_file(target_name, new_url, new_sha256):
    """Updates the toolchain.bzl file with the new URL and SHA256."""

    # "BUILD_WORKSPACE_DIRECTORY" is set by `bazel run`.
    workspace_dir_str = os.environ.get("BUILD_WORKSPACE_DIRECTORY")

    if workspace_dir_str:
        # If running via Bazel, the file is in extensions/toolchain.bzl relative to root
        bzl_path = Path(workspace_dir_str) / "extensions" / "toolchain.bzl"
    else:
        # If running directly, assume script is in utils/ and file is in ../extensions/
        script_dir = Path(__file__).resolve().parent
        bzl_path = (script_dir / BAZEL_FILE_REL_PATH).resolve()

    if not bzl_path.exists():
        logging.error(f"Bazel file not found at {bzl_path}. Skipping update.")
        return

    logging.info(f"Updating {bzl_path} for target '{target_name}'...")

    content = bzl_path.read_text()

    # This regex looks for:
    # 1. gcs_archive( ... name = "target_name", ...
    # 2. captures the content until the closing )
    # It uses non-greedy matching .*? and re.DOTALL to match across lines.
    # It handles potentially different field orders, but assumes standard formatting.

    # Strategy: Find the specific block first.
    block_pattern = re.compile(
        rf'(gcs_archive\s*\(\s*name\s*=\s*"{re.escape(target_name)}",.*?\))', re.DOTALL
    )

    match = block_pattern.search(content)
    if not match:
        logging.error(
            f"Could not find gcs_archive definition for '{target_name}' in {bzl_path}."
        )
        return

    original_block = match.group(1)
    new_block = original_block

    # Update sha256
    new_block = re.sub(r"sha256\s*=\s*\".*?\"", f'sha256 = "{new_sha256}"', new_block)

    # Update url
    new_block = re.sub(r"url\s*=\s*\".*?\"", f'url = "{new_url}"', new_block)

    if new_block == original_block:
        logging.warning(
            "No changes were made to the Bazel file (values might be identical)."
        )
        return

    new_content = content.replace(original_block, new_block)

    bzl_path.write_text(new_content)

    logging.info(f"Successfully updated {bzl_path}")


def _handle_version_logic(args, available_versions, name, path_for_error=""):
    """Handles listing and selecting a version. Returns selected version or None."""
    if not available_versions:
        logging.error(f"No {name} versions found in '{path_for_error}'.")
        return None

    if args.list_versions:
        print(f"Available {name} versions:")
        if available_versions:
            print(f"Defaulting to latest: {available_versions[0]}")
            for v in available_versions:
                print(f"  - {v}")
        return None  # Indicate to caller that we are done

    selected_version = args.version or available_versions[0]
    if selected_version not in available_versions:
        logging.error(
            f"Specified {name} version '{selected_version}' is not available."
        )
        logging.info(f"Available versions are: {', '.join(available_versions)}")
        return None

    return selected_version


def check_prerequisites(args, command_name):
    """Checks if necessary tools and modules are available."""
    logging.info("Checking prerequisites...")

    if args.upload:
        if not shutil.which("gsutil"):
            logging.error(
                "'gsutil' is required for uploading but was not found in PATH."
            )
            return False

    if command_name == "msvc" or command_name == "sdk":
        # These commands are Windows-only for creation
        if not sys.platform.startswith("win"):
            logging.error("Creating MSVC/SDK packages is only supported on Windows.")
            # Unless we are just listing versions? No, listing also requires windows registry/vswhere
            return False

    if command_name == "msvc":
        # Check for vswhere
        vswhere_path = _get_vswhere_path()
        if not vswhere_path.exists():
            logging.error(
                f"vswhere.exe not found at {vswhere_path}. Is Visual Studio installed?"
            )
            return False

    if command_name == "sdk":
        # Check for winreg
        if winreg is None:
            logging.error(
                "The 'winreg' module is missing. Are you running this on Windows?"
            )
            return False

    return True


def create_zip_package(
    output_zip_path, copy_instructions, args, bazel_target_name=None
):
    """
    Creates a zip file, calculates its SHA256, and optionally uploads it and updates Bazel.
    """

    with tempfile.TemporaryDirectory(prefix="hermetic_pkg_") as temp_staging_dir_str:
        temp_staging_dir = Path(temp_staging_dir_str)
        logging.info(f"Using temporary staging directory: {temp_staging_dir}")

        logging.info("Staging files...")
        for source_path_str, staging_dest in copy_instructions:
            source_path = Path(source_path_str)
            if not source_path.exists():
                logging.warning(f"Source '{source_path}' not found, skipping.")
                continue

            full_staging_path = temp_staging_dir / staging_dest
            # logging.debug(f"Copying '{source_path}' to '{full_staging_path}'")
            shutil.copytree(source_path, full_staging_path, dirs_exist_ok=True)

        logging.info(f"Creating zip file: {output_zip_path}")
        with zipfile.ZipFile(
            output_zip_path, "w", zipfile.ZIP_DEFLATED, allowZip64=True
        ) as zf:
            for root_str, _, files in os.walk(temp_staging_dir):
                root = Path(root_str)
                for file in files:
                    full_path = root / file
                    archive_path = full_path.relative_to(temp_staging_dir)
                    zf.write(full_path, archive_path)

    logging.info(f"Successfully created {output_zip_path}")

    sha256_hash = calculate_sha256(output_zip_path)
    print(f"\nSHA256: {sha256_hash}")  # Always print hash to stdout for easy copying

    final_url = None
    if args.upload:
        final_url = upload_to_gcs(output_zip_path, args.gcs_bucket)
        if final_url:
            print(f"URL: {final_url}")

    if args.update_bzl and bazel_target_name:
        if final_url:
            update_bazel_file(bazel_target_name, final_url, sha256_hash)
        else:
            logging.warning(
                "Skipping Bazel file update because upload failed or was not requested (URL is unknown)."
            )


# --- MSVC Specific Functions ---


def _get_vswhere_path():
    """Returns the full path to vswhere.exe."""
    program_files = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)"))
    return program_files / "Microsoft Visual Studio" / "Installer" / "vswhere.exe"


def find_vs_info():
    vswhere_path = _get_vswhere_path()
    command = [
        vswhere_path,
        "-latest",
        "-prerelease",
        "-format",
        "json",
        "-requires",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    ]
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    installations = json.loads(result.stdout)
    if not installations:
        raise Exception(
            "vswhere did not find any Visual Studio installation with C++ tools."
        )
    return installations[0]


def find_all_msvc_versions(vs_install_path):
    msvc_tools_base = Path(vs_install_path) / "VC" / "Tools" / "MSVC"
    if not msvc_tools_base.is_dir():
        return []
    versions = [d.name for d in msvc_tools_base.iterdir() if d.is_dir()]
    versions.sort(key=lambda v: [int(part) for part in v.split(".")], reverse=True)
    return versions


def run_msvc_creation(args):
    try:
        vs_info = find_vs_info()
    except Exception as e:
        logging.error(e)
        return

    vs_install_path_str = vs_info.get("installationPath")
    if not vs_install_path_str:
        logging.error("Could not find Visual Studio installation path.")
        return
    vs_install_path = Path(vs_install_path_str)

    msvc_base_path = vs_install_path / "VC" / "Tools" / "MSVC"
    available_versions = find_all_msvc_versions(vs_install_path)

    msvc_version = _handle_version_logic(
        args, available_versions, "MSVC", msvc_base_path
    )
    if not msvc_version:
        return

    version_str = msvc_version.replace(".", "_")
    output_filename = f"msvc_tools_{version_str}_{get_datestamp()}.zip"
    final_output_path = Path(args.output_dir) / output_filename

    logging.info(f"Preparing to create MSVC package for version {msvc_version}")

    msvc_version_path = msvc_base_path / msvc_version
    dia_sdk_path = vs_install_path / "DIA SDK"

    copy_instructions = []
    for d in ["bin", "include", "lib", "atlmfc", "modules"]:
        copy_instructions.append((str(msvc_version_path / d), f"msvc/{d}"))
    for d in ["bin", "idl", "include", "lib"]:
        copy_instructions.append((str(dia_sdk_path / d), f"ms_dia_sdk/{d}"))

    create_zip_package(
        final_output_path, copy_instructions, args, bazel_target_name="vctools_hermetic"
    )


# --- Windows SDK Specific Functions ---


def find_windows_sdk_root():
    if winreg is None:
        raise ImportError("winreg module required")

    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\Windows Kits\Installed Roots",
        ) as key:
            return winreg.QueryValueEx(key, "KitsRoot10")[0]
    except FileNotFoundError:
        raise FileNotFoundError(
            "Windows SDK installation key not found in the registry."
        )


def find_all_sdk_versions(sdk_root):
    include_path = Path(sdk_root) / "Include"
    if not include_path.is_dir():
        return []
    versions = [
        d.name
        for d in include_path.iterdir()
        if d.is_dir() and d.name.startswith("10.")
    ]
    versions.sort(key=lambda v: [int(p) for p in v.split(".")], reverse=True)
    return versions


def run_sdk_creation(args):
    try:
        sdk_root_str = find_windows_sdk_root()
    except Exception as e:
        logging.error(e)
        return
    sdk_root = Path(sdk_root_str)

    include_path = sdk_root / "Include"
    available_versions = find_all_sdk_versions(sdk_root)

    sdk_version = _handle_version_logic(
        args, available_versions, "Windows SDK", include_path
    )
    if not sdk_version:
        return

    version_str = sdk_version.replace(".", "_")
    output_filename = f"windows_sdk_{version_str}_{get_datestamp()}.zip"
    final_output_path = Path(args.output_dir) / output_filename

    logging.info(f"Preparing to create Windows SDK package for version {sdk_version}")

    copy_instructions = []
    for d in ["Include", "Lib", "bin"]:
        copy_instructions.append((str(sdk_root / d / sdk_version), d))
    for d in ["App Certification Kit", "Licenses", "Redist"]:
        copy_instructions.append((str(sdk_root / d), d))

    create_zip_package(
        final_output_path,
        copy_instructions,
        args,
        bazel_target_name="windows_sdk_hermetic",
    )


# --- Main Application ---


def main():
    # Common arguments
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument(
        "-o",
        "--output-dir",
        type=str,
        default=".",
        help="Directory to save the output zip file. Defaults to current directory.",
    )
    parent_parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload the resulting zip file to Google Cloud Storage.",
    )
    parent_parser.add_argument(
        "--gcs-bucket",
        type=str,
        default=DEFAULT_GCS_BUCKET,
        help=f"GCS bucket path for upload.\nDefault: {DEFAULT_GCS_BUCKET}",
    )
    parent_parser.add_argument(
        "--update-bzl",
        action="store_true",
        help="Automatically update 'extensions/toolchain.bzl' with the new URL and SHA256. This implies --upload.",
    )
    parent_parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose logging."
    )

    parser = argparse.ArgumentParser(
        description="Create hermetic packages for MSVC and Windows SDK.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""
Examples:
  # Create MSVC package, upload it, and update Bazel config automatically (--update-bzl implies --upload)
  python create_hermetic_packages.py msvc --update-bzl

  # Create Windows SDK package, save to specific dir, no upload
  python create_hermetic_packages.py sdk -o C:\\Temp

  # List available MSVC versions
  python create_hermetic_packages.py msvc --list-versions
""",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # --- MSVC sub-command ---
    parser_msvc = subparsers.add_parser(
        "msvc", help="Create an MSVC package.", parents=[parent_parser]
    )
    parser_msvc.add_argument(
        "--list-versions",
        action="store_true",
        help="List available MSVC versions and exit.",
    )
    parser_msvc.add_argument(
        "--version",
        type=str,
        help="Specify the MSVC version to package.\nDefaults to the latest version found.",
    )
    parser_msvc.set_defaults(func=run_msvc_creation)

    # --- SDK sub-command ---
    parser_sdk = subparsers.add_parser(
        "sdk", help="Create a Windows SDK package.", parents=[parent_parser]
    )
    parser_sdk.add_argument(
        "--list-versions",
        action="store_true",
        help="List available Windows SDK versions and exit.",
    )
    parser_sdk.add_argument(
        "--version",
        type=str,
        help="Specify the SDK version to package.\nDefaults to the latest version found.",
    )
    parser_sdk.set_defaults(func=run_sdk_creation)

    args = parser.parse_args()

    setup_logging(args.verbose)

    # If --update-bzl is specified, it should always imply --upload.
    if args.update_bzl:
        args.upload = True

    # Check common prerequisites before dispatching
    # Note: We check args.command here which is set by dest="command"
    if not check_prerequisites(args, args.command):
        sys.exit(1)

    try:
        args.func(args)
    except (FileNotFoundError, Exception) as e:
        logging.exception("An unexpected error occurred:")
        sys.exit(1)


if __name__ == "__main__":
    main()
