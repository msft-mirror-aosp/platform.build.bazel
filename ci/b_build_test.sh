#!/bin/bash -eu
# Copyright (C) 2023 The Android Open Source Project
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

# Build all _stable_ build targets with b to ensure that the workflow
# hasn't stopped working. This is a shortened version of bp2build.sh
source "$(dirname $0)/target_lists.sh"

build/bazel/bin/b build --config=android --  ${STABLE_BUILD_TARGETS[@]}