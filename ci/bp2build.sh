#!/bin/bash -eux
# Verifies that bp2build-generated BUILD files result in successful Bazel
# builds.
#
# This verification script is designed to be used for continuous integration
# tests, though may also be used for manual developer verification.

#######
# Setup
#######

if [[ -z ${DIST_DIR+x} ]]; then
  echo "DIST_DIR not set. Using out/dist. This should only be used for manual developer testing."
  DIST_DIR="out/dist"
fi

# Generate BUILD files into out/soong/bp2build
AOSP_ROOT="$(dirname $0)/../../.."
"${AOSP_ROOT}/build/soong/soong_ui.bash" --make-mode BP2BUILD_VERBOSE=1 --skip-soong-tests bp2build dist

# Dist the entire workspace of generated BUILD files, rooted from
# out/soong/bp2build. This is done early so it's available even if builds/tests
# fail.
tar -czf "${DIST_DIR}/bp2build_generated_workspace.tar.gz" -C out/soong/bp2build .

# Remove the ninja_build output marker file to communicate to buildbot that this is not a regular Ninja build, and its
# output should not be parsed as such.
rm -f out/ninja_build

# Before you add flags to this list, cosnider adding it to the "ci" bazelrc
# config instead of this list so that flags are not duplicated between scripts
# and bazelrc, and bazelrc is the Bazel-native way of organizing flags.
FLAGS_LIST=(
  --config=bp2build
  --config=ci
)
FLAGS="${FLAGS_LIST[@]}"

###############
# Build targets
###############
BUILD_TARGETS_LIST=(
  //art/...
  //bionic/...
  //bootable/recovery/tools/recovery_l10n/...
  //build/...
  //cts/...
  //development/...
  //external/...
  //frameworks/...
  //libnativehelper/...
  //packages/...
  //prebuilts/clang/host/linux-x86:all
  //system/...
  //tools/apksig/...
  //tools/platform-compat/...
)
BUILD_TARGETS="${BUILD_TARGETS_LIST[@]}"
# Iterate over various architectures supported in the platform build.
tools/bazel --max_idle_secs=5 build ${FLAGS} --platforms //build/bazel/platforms:android_x86 -k ${BUILD_TARGETS}
tools/bazel --max_idle_secs=5 build ${FLAGS} --platforms //build/bazel/platforms:android_x86_64 -k ${BUILD_TARGETS}
tools/bazel --max_idle_secs=5 build ${FLAGS} --platforms //build/bazel/platforms:android_arm -k ${BUILD_TARGETS}
tools/bazel --max_idle_secs=5 build ${FLAGS} --platforms //build/bazel/platforms:android_arm64 -k ${BUILD_TARGETS}

HOST_INCOMPATIBLE_TARGETS=(
  # TODO(b/217756861): Apex toolchain is incompatible with host arches but apex modules do
  # not have this restriction
  -//build/bazel/examples/apex/...
  -//packages/modules/adb/apex:com.android.adbd
  -//system/timezone/apex:com.android.tzdata
  -//build/bazel/tests/apex/...

  # TODO(b/217927043): Determine how to address targets that are device only
  -//system/core/libpackagelistparser:all
  -//external/icu/libicu:all
  //external/icu/libicu:libicu
  -//external/icu/icu4c/source/tools/ctestfw:all

  # TODO(b/217926427): determine why these host_supported modules do not build on host
  -//packages/modules/adb:all
  -//packages/modules/adb/pairing_connection:all
)

# build for host
tools/bazel --max_idle_secs=5 build ${FLAGS} \
  --platforms //build/bazel/platforms:linux_x86_64 \
  -- ${BUILD_TARGETS} "${HOST_INCOMPATIBLE_TARGETS[@]}"

###########
# Run tests
###########
tools/bazel --max_idle_secs=5 test ${FLAGS} //build/bazel/tests/... //build/bazel/rules/apex/...

# Test copying of some files to $DIST_DIR (set above, or from the CI invocation).
tools/bazel --max_idle_secs=5 run //build/bazel_common_rules/dist:dist_bionic_example --config=bp2build --config=ci -- --dist_dir="${DIST_DIR}"
if [[ ! -f "${DIST_DIR}/bionic/libc/libc.so" ]]; then
  >&2 echo "Expected dist dir to exist at ${DIST_DIR} and contain the libc shared library, but the file was not found."
  exit 1
fi

###################
# bp2build-progress
###################

# Generate bp2build progress reports and graphs for these modules into the dist
# dir so that they can be downloaded from the CI artifact list.
BP2BUILD_PROGRESS_MODULES=(
  com.android.runtime
  com.android.neuralnetworks
  com.android.media.swcodec
)
bp2build_progress_script="${AOSP_ROOT}/build/bazel/scripts/bp2build-progress/bp2build-progress.py"
bp2build_progress_output_dir="${DIST_DIR}/bp2build-progress"
mkdir -p "${bp2build_progress_output_dir}"

report_args=""
for m in "${BP2BUILD_PROGRESS_MODULES[@]}"; do
  report_args="$report_args -m ""${m}"
  "${bp2build_progress_script}" graph  -m "${m}" --use_queryview=true > "${bp2build_progress_output_dir}/${m}_graph.dot"
done

"${bp2build_progress_script}" report ${report_args} --use_queryview=true > "${bp2build_progress_output_dir}/progress_report.txt"
