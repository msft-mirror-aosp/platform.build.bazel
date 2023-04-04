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

load("//build/bazel/rules/java:versions.bzl", "java_versions")
load("//build/bazel/rules/common:sdk_version.bzl", "sdk_spec_from")
load("//build/bazel/rules/common:api.bzl", "api")

def _sdk_transition_impl(settings, attr):
    host_platform = settings["//command_line_option:host_platform"]
    default_java_version = str(java_versions.get_version())

    # TODO: this condition should really be "platform is not a device".
    # More details on why we're treating java version for non-device platforms differently at the
    # definition of the //build/bazel/rules/java:host_version build setting.
    if all([host_platform == platform for platform in settings["//command_line_option:platforms"]]):
        return {
            "//build/bazel/rules/java:version": default_java_version,
            "//build/bazel/rules/java:host_version": str(java_versions.get_version(attr.java_version)),
            "//build/bazel/rules/java/sdk:kind": "none",
            "//build/bazel/rules/java/sdk:api_level": api.NONE_API_LEVEL,
        }
    sdk_spec = sdk_spec_from(attr.sdk_version)
    java_version = str(java_versions.get_version(attr.java_version, sdk_spec.api_level))

    return {
        "//build/bazel/rules/java:host_version": default_java_version,
        "//build/bazel/rules/java:version": java_version,
        "//build/bazel/rules/java/sdk:kind": sdk_spec.kind,
        "//build/bazel/rules/java/sdk:api_level": sdk_spec.api_level,
    }

sdk_transition = transition(
    implementation = _sdk_transition_impl,
    inputs = [
        "//command_line_option:host_platform",
        "//command_line_option:platforms",
    ],
    outputs = [
        "//build/bazel/rules/java:version",
        "//build/bazel/rules/java:host_version",
        "//build/bazel/rules/java/sdk:kind",
        "//build/bazel/rules/java/sdk:api_level",
    ],
)
