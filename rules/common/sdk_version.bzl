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

load("//build/bazel/rules/common:api.bzl", "api")

# Only scopes that are available in prebuilts (and "none") are listed
# here for now, but the list should eventually match Soong's SdkKind
# enum.
ALL_KINDS = [
    "public",
    "system",
    "test",
    "system_server",
    "module",
    "core",
    "none",
]

# Starlark implementation of SdkSpecFrom at https://cs.android.com/android/platform/build/soong/+/master:android/sdk_version.go;l=248-299;drc=69f4218c4feaeca953237cd9e76a9a8cc423d3e3.
def sdk_spec_from(sdk_version):
    """Parses an sdk_version string into kind and api_level.

    Args:
        sdk_version: a string to specify which SDK version to depend on.
            - The empty string maps to the full set of private APIs and is currently unsupported.
            - "core_platform" maps to the module scope of the core system modules.
            - "none" maps to no SDK (used for bootstrapping the core).
            - Otherwise, the format is "{kind}_{api_level}", where kind must be one of the strings
              in ALL_KINDS, and api_level is either an integer, and android codename, or "current".
              The default kind is "public", and can be omitted by simply providing "{api_level}".

    Returns:
        A struct with a kind attribute set to one of the string in ALL_KINDS, and an api_level
        attribute as returned by api.bzl's parse_api_level_from_version.
    """
    if not sdk_version:
        fail("Only prebuilt SDK versions are available, sdk_version must be specified and non-empty.")
    if sdk_version == "core_platform":
        fail("Only prebuilt SDK versions are available, sdk_version core_platform is not yet supported.")
    if sdk_version == "none":
        return struct(kind = "none", api_level = api.NONE_API_LEVEL)
    if type(sdk_version) != type(""):
        fail("sdk_version must be a string")
    sep_index = sdk_version.rfind("_")
    api_level_string = sdk_version if sep_index < 0 else sdk_version[sep_index + 1:]
    api_level = api.parse_api_level_from_version(api_level_string)
    kind = "public" if sep_index == -1 else sdk_version[:sep_index]
    if kind not in ALL_KINDS:
        fail("kind %s parsed from sdk_version %s must be one of %s" % (
            kind,
            sdk_version,
            ",".join(ALL_KINDS),
        ))
    return struct(kind = kind, api_level = api_level)
