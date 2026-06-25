# Copyright 2026 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Starlark macro for importing libraries with static/dynamic select on Windows."""

load("@rules_cc//cc:cc_library.bzl", "cc_library")

def cc_import_library(
        name,
        srcs = [],
        hdrs = [],
        deps = None,
        static_deps = None,
        shared_import_deps = None,
        local_defines = [],
        defines = [],
        static_defines = [],
        shared_defines = [],
        **kwargs):
    """Declares both a static target and a dynamic/import target on Windows.

    Keeps dependencies and defines strictly separated.

    Args:
      name: The name of the library.
      srcs: The list of source files.
      hdrs: The list of header files.
      deps: The list of common dependencies.
      static_deps: The list of static-only dependencies.
      shared_import_deps: The list of shared-only dependencies.
      local_defines: The list of common local defines.
      defines: The list of common defines.
      static_defines: The list of static-only defines.
      shared_defines: The list of shared-only defines.
      **kwargs: Additional arguments to pass to cc_library.
    """
    deps_list = deps if deps != None else []
    static_deps_list = static_deps if static_deps != None else []
    shared_import_deps_list = shared_import_deps if shared_import_deps != None else []

    # 1. Define the core static compilation target (name)
    cc_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        local_defines = local_defines + static_defines,
        defines = defines + static_defines,
        deps = deps_list + static_deps_list,
        **kwargs
    )

    # 2. Define the dynamic import compilation target (name_import)
    cc_library(
        name = name + "_import",
        srcs = srcs,
        hdrs = hdrs,
        local_defines = local_defines + shared_defines,
        defines = defines + shared_defines,
        deps = deps_list + shared_import_deps_list,
        **kwargs
    )
