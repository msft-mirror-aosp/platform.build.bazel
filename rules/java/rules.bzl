# Copyright (C) 2023 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(
    "@rules_java//java:defs.bzl",
    _java_binary = "java_binary",
)
load(
    "@rules_java//java:defs.bzl",
    _java_import = "java_import",
)
load(
    "//build/bazel/rules/java:library.bzl",
    _java_library = "java_library",
)

java_binary = _java_binary
java_library = _java_library
java_import = _java_import
