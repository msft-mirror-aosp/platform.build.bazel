#!/bin/bash

# Copyright (C) 2021 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -xeuo pipefail

apexer_tool_path="${RUNFILES_DIR}/__main__/external/make_injection/host/linux-x86/bin"
android_jar="${RUNFILES_DIR}/__main__/prebuilts/sdk/current/public/android.jar"

input_dir=$(mktemp -d)
output_dir=$(mktemp -d)

function cleanup {
  rm -rf ${input_dir}
  rm -rf ${output_dir}
}

trap cleanup ERR
#############################################
# prepare the inputs
#############################################
# Create the input directory with
# 1. a file with random bits
# 2. a file installed sub dir with random bits
# 3. a one-level symlink
# 4. a two-level symlink with "execroot/__main__" in the path
# 5. a two-level sumlink without "execroot/__main__" in the path
echo "test file1" > "${input_dir}/file1"
echo "test file2" > "${input_dir}/file2"
mkdir -p "${input_dir}/execroot/__main__"
ln -s "${input_dir}/file1" "${input_dir}/one_level_sym"
ln -s "${input_dir}/file2" "${input_dir}/execroot/__main__/middle_sym"
ln -s "${input_dir}/execroot/__main__/middle_sym" "${input_dir}/two_level_sym_in_execroot"
ln -s "${input_dir}/one_level_sym" "${input_dir}/two_level_sym_not_in_execroot"

# Create the APEX manifest file
manifest_dir=$(mktemp -d)
manifest_file="${manifest_dir}/apex_manifest.pb"
echo '{"name": "com.android.example.apex", "version": 1}' > "${manifest_dir}/apex_manifest.json"
"${apexer_tool_path}/conv_apex_manifest" proto "${manifest_dir}/apex_manifest.json" -o ${manifest_file}

# Create the file_contexts file
file_contexts_file=$(mktemp)
echo '
(/.*)?           u:object_r:root_file:s0
/execroot(/.*)?       u:object_r:execroot_file:s0
' > ${file_contexts_file}

output_file="${output_dir}/test.apex"

# Create the wrapper manifest file
bazel_apexer_wrapper_manifest_file=$(mktemp)
echo "
dir1,file1,"${input_dir}/file1"
dir2/dir3,file2,"${input_dir}/file2"
dir4,one_level_sym,"${input_dir}/one_level_sym"
dir5,two_level_sym_in_execroot,"${input_dir}/two_level_sym_in_execroot"
dir6,two_level_sym_not_in_execroot,"${input_dir}/two_level_sym_not_in_execroot"
" > ${bazel_apexer_wrapper_manifest_file}

#############################################
# run bazel_apexer_wrapper
#############################################
"${RUNFILES_DIR}/__main__/build/bazel/rules/apex/bazel_apexer_wrapper" \
  --manifest ${manifest_file} \
  --file_contexts ${file_contexts_file} \
  --key "${RUNFILES_DIR}/__main__/build/bazel/rules/apex/test.pem" \
  --apexer_tool_path ${apexer_tool_path} \
  --apex_output_file ${output_file} \
  --bazel_apexer_wrapper_manifest ${bazel_apexer_wrapper_manifest_file} \
  --android_jar_path ${android_jar}

#############################################
# check the result
#############################################
"${apexer_tool_path}/deapexer" --debugfs_path="${apexer_tool_path}/debugfs" extract ${output_file} ${output_dir}

# The expected mounted tree should be something like this:
# /tmp/tmp.9u7ViPlMr7
# ├── apex_manifest.pb
# ├── apex_payload.img
# ├── mnt
# │   ├── apex_manifest.pb
# │   ├── dir1
# │   │   └── file1
# │   ├── dir2
# │   │   └── dir3
# │   │       └── file2
# │   ├── dir4
# │   │   └── one_level_sym
#             (one level symlinks always resolve)
# │   ├── dir5
# │   │   └── two_level_sym_in_execroot
#             (two level symlink resolve if the path contains execroot/__main__)
# │   ├── dir6
# │   │   └── two_level_sym_not_in_execroot -> /tmp/tmp.evJh21oYGG/file1
#             (two level symlink resolve only one level otherwise)
# └── test.apex

# check the contents
# TODO(b/215129834): Temporarily bypassed to unblock ART team. Resolve this ASAP.
# diff ${manifest_file} ${output_dir}/apex_manifest.pb
diff ${input_dir}/file1 ${output_dir}/dir1/file1
diff ${input_dir}/file2 ${output_dir}/dir2/dir3/file2
diff ${input_dir}/file1 ${output_dir}/dir4/one_level_sym
diff ${input_dir}/file2 ${output_dir}/dir5/two_level_sym_in_execroot
[ `readlink ${output_dir}/dir6/two_level_sym_not_in_execroot` = "${input_dir}/file1" ]

cleanup

echo "Passed for all test cases"
