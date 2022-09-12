#!/usr/bin/env python3
#
# Copyright (C) 2022 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Utility functions to produce module or module type dependency graphs using json-module-graph or queryview."""

from typing import Set
import collections
import dataclasses
import json
import os
import os.path
import subprocess
import sys
import xml.etree.ElementTree


@dataclasses.dataclass(frozen=True, order=True)
class _ModuleKey:
  """_ModuleKey uniquely identifies a module by name nad variations."""
  name: str
  variations: list

  def __str__(self):
    return f"{self.name}, {self.variations}"

  def __hash__(self):
    return (self.name + str(self.variations)).__hash__()


# This list of module types are omitted from the report and graph
# for brevity and simplicity. Presence in this list doesn't mean
# that they shouldn't be converted, but that they are not that useful
# to be recorded in the graph or report currently.
IGNORED_KINDS = set([
    "license_kind",
    "license",
    "cc_defaults",
    "java_defaults",
    "hidl_interface.go_android/soong/hidl.hidlGenFactory__loadHookModule",  # implementation detail of hidl_interface
    "hidl_package_root",  # not being converted, contents converted as part of hidl_interface
    "aidl_interface.go_android/soong/aidl.wrapLibraryFactory.func1__topDownMutatorModule", # implementation detail of aidl_interface
    "aidl_gen_rule.go_android/soong/aidl.aidlGenFactory__loadHookModule", # implementation detail of aidl_interface
])

# queryview doesn't have information on the type of deps, so we explicitly skip
# prebuilt types
_QUERYVIEW_IGNORE_KINDS = set([
    "android_app_import",
    "android_library_import",
    "cc_prebuilt_library",
    "cc_prebuilt_library_headers",
    "cc_prebuilt_library_shared",
    "cc_prebuilt_library_static",
    "cc_prebuilt_library_static",
    "cc_prebuilt_object",
    "java_import",
    "java_import_host",
    "java_sdk_library_import",
])

SRC_ROOT_DIR = os.path.abspath(__file__ + "/../../../../..")

LUNCH_ENV = {
    # Use aosp_arm as the canonical target product.
    "TARGET_PRODUCT": "aosp_arm",
    "TARGET_BUILD_VARIANT": "userdebug",
}

BANCHAN_ENV = {
    # Use module_arm64 as the canonical banchan target product.
    "TARGET_PRODUCT": "module_arm64",
    "TARGET_BUILD_VARIANT": "eng",
    # just needs to be non-empty, not the specific module for Soong
    # analysis purposes
    "TARGET_BUILD_APPS": "all",
}


def _build_with_soong(target, banchan_mode=False):
  subprocess.check_output(
      [
          "build/soong/soong_ui.bash",
          "--make-mode",
          "--skip-soong-tests",
          target,
      ],
      cwd=SRC_ROOT_DIR,
      env=BANCHAN_ENV if banchan_mode else LUNCH_ENV,
  )


def get_properties(json_module):
  set_properties = {}
  if "Module" not in json_module:
    return set_properties
  if "Android" not in json_module["Module"]:
    return set_properties
  if "SetProperties" not in json_module["Module"]["Android"]:
    return set_properties

  for prop in json_module['Module']['Android']['SetProperties']:
    if prop["Values"]:
      value = prop["Values"]
    else:
      value = prop["Value"]
    set_properties[prop["Name"]] = value
  return set_properties


def get_property_names(json_module):
  return get_properties(json_module).keys()


def get_queryview_module_info(module, banchan_mode=False):
  """Returns the list of transitive dependencies of input module as built by queryview."""
  _build_with_soong("queryview", banchan_mode)

  queryview_xml = subprocess.check_output(
      [
          "tools/bazel", "query", "--config=ci", "--config=queryview",
          "--output=xml",
          'deps(attr("soong_module_name", "^{}$", //...))'.format(module)
      ],
      cwd=SRC_ROOT_DIR,
  )
  try:
    return xml.etree.ElementTree.fromstring(queryview_xml)
  except xml.etree.ElementTree.ParseError as err:
    sys.exit(f"""Could not parse XML:
{queryview_xml}
ParseError: {err}""")


def get_json_module_info(module, banchan_mode=False):
  """Returns the list of transitive dependencies of input module as provided by Soong's json module graph."""
  _build_with_soong("json-module-graph", banchan_mode)
  try:
    with open(os.path.join(SRC_ROOT_DIR,"out/soong/module-graph.json")) as f:
      return json.load(f)
  except json.JSONDecodeError as err:
    sys.exit(f"""Could not decode json:
out/soong/module-graph.json
JSONDecodeError: {err}""")


def _ignore_json_module(json_module, ignore_by_name):
  # windows is not a priority currently
  if is_windows_variation(json_module):
    return True
  if ignore_kind(json_module['Type']):
    return True
  if json_module['Name'] in ignore_by_name:
    return True
  # for filegroups with a name the same as the source, we are not migrating the
  # filegroup and instead just rely on the filename being exported
  if json_module['Type'] == 'filegroup':
    set_properties = get_properties(json_module)
    srcs = set_properties.get('Srcs', [])
    if len(srcs) == 1:
      return json_module['Name'] in srcs
  return False


def visit_json_module_graph_post_order(module_graph, ignore_by_name,
                                       filter_predicate, visit):
  # The set of ignored modules. These modules (and their dependencies) are not shown
  # in the graph or report.
  ignored = set()

  # name to all module variants
  module_graph_map = {}
  root_module_keys = []

  # Do a single pass to find all top-level modules to be ignored
  for module in module_graph:
    name = module["Name"]
    key = _ModuleKey(name, module["Variations"])
    if _ignore_json_module(module, ignore_by_name):
      ignored.add(key)
      continue
    module_graph_map[key] = module
    if filter_predicate(module):
      root_module_keys.append(key)

  visited = set()

  def json_module_graph_post_traversal(module_key):
    if module_key in ignored or module_key in visited:
      return
    visited.add(module_key)

    deps = set()
    module = module_graph_map[module_key]
    for dep in module["Deps"]:
      if ignore_json_dep(dep, module["Name"], ignored):
        continue

      dep_name = dep["Name"]
      deps.add(dep_name)
      dep_key = _ModuleKey(dep_name, dep["Variations"])

      if dep_key not in visited:
        json_module_graph_post_traversal(dep_key)

    visit(module, deps)

  for module_key in root_module_keys:
    json_module_graph_post_traversal(module_key)


QueryviewModule = collections.namedtuple("QueryviewModule", [
    "name",
    "kind",
    "variant",
    "dirname",
    "deps",
    "srcs",
])


def _bazel_target_to_dir(full_target):
  dirname, _ = full_target.split(":")
  return dirname[len("//"):]  # discard prefix


def _get_queryview_module(name_with_variant, module, kind):
  name = None
  variant = ""
  deps = []
  srcs = []
  for attr in module:
    attr_name = attr.attrib["name"]
    if attr.tag == "rule-input":
      deps.append(attr_name)
    elif attr_name == "soong_module_name":
      name = attr.attrib["value"]
    elif attr_name == "soong_module_variant":
      variant = attr.attrib["value"]
    elif attr_name == "soong_module_type" and kind == "generic_soong_module":
      kind = attr.attrib["value"]
    elif attr_name == "srcs":
      for item in attr:
        srcs.append(item.attrib["value"])

  return QueryviewModule(
      name=name,
      kind=kind,
      variant=variant,
      dirname=_bazel_target_to_dir(name_with_variant),
      deps=deps,
      srcs=srcs,
  )


def _ignore_queryview_module(module, ignore_by_name):
  if module.name in ignore_by_name:
    return True
  if ignore_kind(module.kind, queryview=True):
    return True
  # special handling for filegroup srcs, if a source has the same name as
  # the filegroup module, we don't convert it
  if module.kind == "filegroup" and module.name in module.srcs:
    return True
  return module.variant.startswith("windows")


def visit_queryview_xml_module_graph_post_order(module_graph, ignored_by_name,
                                                filter_predicate, visit):
  # The set of ignored modules. These modules (and their dependencies) are
  # not shown in the graph or report.
  ignored = set()

  # queryview embeds variant in long name, keep a map of the name with vaiarnt
  # to just name
  name_with_variant_to_name = dict()

  module_graph_map = dict()
  to_visit = []

  for module in module_graph:
    ignore = False
    if module.tag != "rule":
      continue
    kind = module.attrib["class"]
    name_with_variant = module.attrib["name"]

    qv_module = _get_queryview_module(name_with_variant, module, kind)

    if _ignore_queryview_module(qv_module, ignored_by_name):
      ignored.add(name_with_variant)
      continue

    if filter_predicate(qv_module):
      to_visit.append(name_with_variant)

    name_with_variant_to_name.setdefault(name_with_variant, qv_module.name)
    module_graph_map[name_with_variant] = qv_module

  visited = set()

  def queryview_module_graph_post_traversal(name_with_variant):
    module = module_graph_map[name_with_variant]
    if name_with_variant in ignored or name_with_variant in visited:
      return
    visited.add(name_with_variant)

    name = name_with_variant_to_name[name_with_variant]

    deps = set()
    for dep_name_with_variant in module.deps:
      if dep_name_with_variant in ignored:
        continue
      dep_name = name_with_variant_to_name[dep_name_with_variant]
      if dep_name == "prebuilt_" + name:
        continue
      if dep_name_with_variant not in visited:
        queryview_module_graph_post_traversal(dep_name_with_variant)

      if name != dep_name:
        deps.add(dep_name)

    visit(module, deps)

  for name_with_variant in to_visit:
    queryview_module_graph_post_traversal(name_with_variant)


def get_bp2build_converted_modules() -> Set[str]:
  """ Returns the list of modules that bp2build can currently convert. """
  _build_with_soong("bp2build")
  # Parse the list of converted module names from bp2build
  with open(
      os.path.join(SRC_ROOT_DIR,
                   "out/soong/soong_injection/metrics/converted_modules.txt"),
      "r") as f:
    # Read line by line, excluding comments.
    # Each line is a module name.
    ret = set(line.strip() for line in f if not line.strip().startswith("#"))
  return ret


def get_json_module_type_info(module_type):
  """Returns the combined transitive dependency closures of all modules of module_type."""
  _build_with_soong("json-module-graph")
  # Run query.sh on the module graph for the top level module type
  result = subprocess.check_output(
      [
          "build/bazel/json_module_graph/query.sh",
          "fullTransitiveModuleTypeDeps", "out/soong/module-graph.json",
          module_type
      ],
      cwd=SRC_ROOT_DIR,
  )
  return json.loads(result)


def is_windows_variation(module):
  """Returns True if input module's variant is Windows.

  Args:
    module: an entry parsed from Soong's json-module-graph
  """
  dep_variations = module.get("Variations")
  dep_variation_os = ""
  if dep_variations != None:
    for v in dep_variations:
      if v["Mutator"] == "os":
        dep_variation_os = v["Variation"]
  return dep_variation_os == "windows"


def ignore_kind(kind, queryview=False):
  if queryview and kind in _QUERYVIEW_IGNORE_KINDS:
    return True
  return kind in IGNORED_KINDS or "defaults" in kind


def is_prebuilt_to_source_dep(dep):
  # Soong always adds a dependency from a source module to its corresponding
  # prebuilt module, if it exists.
  # https://cs.android.com/android/platform/superproject/+/master:build/soong/android/prebuilt.go;l=395-396;drc=5d6fa4d8571d01a6e5a63a8b7aa15e61f45737a9
  # This makes it appear that the prebuilt is a transitive dependency regardless
  # of whether it is actually necessary. Skip these to keep the graph to modules
  # used to build.
  return dep["Tag"] == "android.prebuiltDependencyTag {BaseDependencyTag:{}}"


def ignore_json_dep(dep, module_name, ignored_keys):
  """Whether to ignore a json dependency based on heuristics.

  Args:
    dep: dependency struct from an entry in Soogn's json-module-graph
    module_name: name of the module this is a dependency of
    ignored_names: a set of _ModuleKey to ignore
  """
  if is_prebuilt_to_source_dep(dep):
    return True
  name = dep["Name"]
  return _ModuleKey(name,
                    dep["Variations"]) in ignored_keys or name == module_name
