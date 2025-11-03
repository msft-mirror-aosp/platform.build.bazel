#!/bin/bash

set -e

MODULE_FILE="$(git rev-parse --show-toplevel)/toplevel.MODULE.bazel"
FETCH_ARTIFACT="/google/data/ro/projects/android/fetch_artifact"

USAGE="Usage: $0 -b <build_id>"

BUILD_ID=""

while getopts "b:" opt; do
  case $opt in
    b) BUILD_ID="$OPTARG" >&2 ;;
    *) echo "$USAGE" >&2; exit 1 ;;
  esac
done

if [[ -z "$BUILD_ID" ]]; then
  echo "Error: Build ID is required." >&2
  echo "$USAGE" >&2
  exit 1
fi

update_target() {
  local arch="$1"
  local is_16k=$2
  local build_id="$3"
  local arch_suffix=""
  local k_suffix="64"
  local a_suffix=""
  local target_name=""
  local zip_filename=""
  local gcs_target_dir=""
  local archive_name=""

  if [[ "$arch" == "arm64" ]]; then
    arch_suffix="-v8a"
  fi

  if $is_16k; then
    k_suffix="16k"
    a_suffix="16k"
  fi

  target_name="sdk_gphone${k_suffix}_${arch}_minigbm-userdebug"
  zip_filename="sdk-repo-linux-system-images-${build_id}.zip"
  gcs_target_dir="sdk_gphone${k_suffix}_${arch}_minigbm-userdebug"
  archive_name="android_minigbm${a_suffix}-${arch}${arch_suffix}"

  echo "--------------------------------------------------" >&2
  echo "Updating $archive_name for build $build_id..." >&2
  echo "--------------------------------------------------" >&2

  # Fetch artifact
  echo "Fetching $zip_filename for $target_name..." >&2
  if ! $FETCH_ARTIFACT --bid "$build_id" --target "$target_name" "$zip_filename"; then
    echo "Error: Failed to fetch artifact for $archive_name. Skipping." >&2
    return
  fi

  # Calculate SHA256
  echo "Calculating SHA256 for $zip_filename..." >&2
  SHA256=$(shasum -a 256 "$zip_filename" | awk '{print $1}')
  if [[ -z "$SHA256" ]]; then
    echo "Error: Failed to calculate SHA256 for $archive_name. Skipping." >&2
    rm -f "$zip_filename"
    return
  fi
  echo "SHA256: $SHA256" >&2

  # Check if object exists and upload to GCS if not
  GCS_PATH="gs://emu-next-bazel/sys-img/${gcs_target_dir}/${zip_filename}"
  if gsutil stat "$GCS_PATH" >/dev/null 2>&1; then
    echo "Object $GCS_PATH already exists. Skipping upload." >&2
  else
    echo "Uploading $zip_filename to $GCS_PATH..." >&2
    if ! gsutil cp "$zip_filename" "$GCS_PATH"; then
      echo "Error: Failed to upload to GCS for $archive_name. Skipping." >&2
      rm -f "$zip_filename"
      return
    fi
  fi

  # Update MODULE.bazel
  echo "Updating $MODULE_FILE for $archive_name..." >&2
  START_MARKER="# BEGIN ${archive_name}"
  END_MARKER="# END ${archive_name}"

  sed -i "$MODULE_FILE" -e "/${START_MARKER}/,/${END_MARKER}/{
    s|url = \".*\"|url = \"${GCS_PATH}\"|
    s|sha256 = \".*\"|sha256 = \"${SHA256}\"|
  }"

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update $MODULE_FILE for $archive_name." >&2
  else
    echo "Successfully updated $archive_name to build $build_id." >&2
  fi

  # Clean up
  rm -f "$zip_filename"
}

# Update all four targets
update_target "x86_64" false "$BUILD_ID"
update_target "x86_64" true  "$BUILD_ID"
update_target "arm64"  false "$BUILD_ID"
update_target "arm64"  true  "$BUILD_ID"

echo "--------------------------------------------------" >&2
echo "Minigbm image update process complete." >&2

exit 0
