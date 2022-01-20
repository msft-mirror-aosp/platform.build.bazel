"""
Copyright (C) 2021 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

# Configuration transitions for APEX rules.
#
# Transitions are a Bazel mechanism to analyze/build dependencies in a different
# configuration (i.e. options and flags). The APEX transition is applied from a
# top level APEX rule to its dependencies via an outgoing edge, so that the
# dependencies can be built specially for APEXes (vs the platform).
#
# e.g. if an apex A depends on some target T, building T directly as a top level target
# will use a different configuration from building T indirectly as a dependency of A. The
# latter will contain APEX specific configuration settings that its rule or an aspect can
# use to create different actions or providers for APEXes specifically..

def _impl(settings, attr):
    # Perform a transition to apply APEX specific build settings on the
    # destination target (i.e. an APEX dependency).
    return {
        "//build/bazel/rules/apex:apex_name": attr.name,  # Name of the APEX
        "//build/bazel/rules/apex:min_sdk_version": attr.min_sdk_version,  # Min SDK version of the APEX
    }

apex_transition = transition(
    implementation = _impl,
    inputs = [],
    outputs = [
        "//build/bazel/rules/apex:apex_name",
        "//build/bazel/rules/apex:min_sdk_version",
    ],
)

def _impl_shared_lib_transition_32(settings, attr):
    # Perform a transition to apply APEX specific build settings on the
    # destination target (i.e. an APEX dependency).

    # TODO: We need to check if this is a x86 or arm arch then only set one platform
    # instead of this 1:2 split to avoid performance hit.
    return {
        "x86": {
            "//command_line_option:platforms": "//build/bazel/platforms:android_x86",
            "//build/bazel/rules/apex:apex_name": attr.name,  # Name of the APEX
            "//build/bazel/rules/apex:min_sdk_version": attr.min_sdk_version,  # Min SDK version of the APEX
        },
        "arm": {
            "//command_line_option:platforms": "//build/bazel/platforms:android_arm",
            "//build/bazel/rules/apex:apex_name": attr.name,  # Name of the APEX
            "//build/bazel/rules/apex:min_sdk_version": attr.min_sdk_version,  # Min SDK version of the APEX
        },
    }

shared_lib_transition_32 = transition(
    implementation = _impl_shared_lib_transition_32,
    inputs = [],
    outputs = [
        "//build/bazel/rules/apex:apex_name",
        "//build/bazel/rules/apex:min_sdk_version",
        "//command_line_option:platforms",
    ],
)

def _impl_shared_lib_transition_64(settings, attr):
    # Perform a transition to apply APEX specific build settings on the
    # destination target (i.e. an APEX dependency).

    # TODO: We need to check if this is a x86 or arm arch then only set one platform
    # instead of this 1:2 split to avoid performance hit.
    return {
        "x86_64": {
            "//command_line_option:platforms": "//build/bazel/platforms:android_x86_64",
            "//build/bazel/rules/apex:apex_name": attr.name,  # Name of the APEX
            "//build/bazel/rules/apex:min_sdk_version": attr.min_sdk_version,  # Min SDK version of the APEX
        },
        "arm64": {
            "//command_line_option:platforms": "//build/bazel/platforms:android_arm64",
            "//build/bazel/rules/apex:apex_name": attr.name,  # Name of the APEX
            "//build/bazel/rules/apex:min_sdk_version": attr.min_sdk_version,  # Min SDK version of the APEX
        },
    }

shared_lib_transition_64 = transition(
    implementation = _impl_shared_lib_transition_64,
    inputs = [],
    outputs = [
        "//build/bazel/rules/apex:apex_name",
        "//build/bazel/rules/apex:min_sdk_version",
        "//command_line_option:platforms",
    ],
)
