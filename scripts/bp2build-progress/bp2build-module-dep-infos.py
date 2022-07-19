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
"""A script to produce a csv report of all modules of a given type.

There is one output row per module of the input type, each column corresponds
to one of the fields of the _ModuleTypeInfo named tuple described below.
The script allows to ignore certain dependency edges based on the target module
name, or the dependency tag name.

Usage:
  ./bp2build-module-dep-infos.py -m <module type>
                                 --ignore-by-name <modules to ignore>

"""

import argparse
import collections
import csv
import dependency_analysis
import sys

_ModuleTypeInfo = collections.namedtuple(
    "_ModuleTypeInfo",
    [
        # map of module type to the set of properties used by modules
        # of the given type in the dependency tree.
        "type_to_properties",
        # [java modules only] list of source file extensions used by this module.
        "java_source_extensions",
    ])

_DependencyRelation = collections.namedtuple("_DependencyRelation", [
    "transitive_dependency",
    "top_level_module",
])


def _get_java_source_extensions(module):
  out = set()
  if "Module" not in module:
    return out
  if "Java" not in module["Module"]:
    return out
  if "SourceExtensions" not in module["Module"]["Java"]:
    return out
  if module["Module"]["Java"]["SourceExtensions"]:
    out.update(module["Module"]["Java"]["SourceExtensions"])
  return out


def _get_set_properties(module):
  set_properties = set()
  if "Module" not in module:
    return set_properties
  if "Android" not in module["Module"]:
    return set_properties
  if "SetProperties" not in module["Module"]["Android"]:
    return set_properties
  for prop in module["Module"]["Android"]["SetProperties"]:
    set_properties.add(prop["Name"])
  return set_properties


def module_type_info_from_json(module_graph, module_type, ignored_dep_names):
  """Builds a map of module name to _ModuleTypeInfo for each module of module_type.

     Dependency edges pointing to modules in ignored_dep_names are not followed.
  """

  modules_of_type = set()

  def filter_by_type(json):
    if json["Type"] == module_type:
      modules_of_type.add(json["Name"])
      return True
    return False

  # dictionary of module name to _ModuleTypeInfo.

  type_infos = {}

  def update_infos(module, deps):
    module_name = module["Name"]
    info = type_infos.get(
        module_name,
        _ModuleTypeInfo(
            java_source_extensions=set(),
            type_to_properties=collections.defaultdict(set),
        ))

    java_source_extensions = _get_java_source_extensions(module)

    if module["Type"]:
      info.type_to_properties[module["Type"]].update(
          _get_set_properties(module))

    for dep_name in deps:
      for dep_type, dep_type_properties in type_infos[
          dep_name].type_to_properties.items():
        info.type_to_properties[dep_type].update(dep_type_properties)
        java_source_extensions.update(
            type_infos[dep_name].java_source_extensions)

    info.java_source_extensions.update(java_source_extensions)
    # for a module, collect all properties and java source extensions specified by
    # transitive dependencies and the module itself
    type_infos[module_name] = info

  dependency_analysis.visit_json_module_graph_post_order(
      module_graph, ignored_dep_names, filter_by_type, update_infos)

  return {
      name: info for name, info in type_infos.items() if name in modules_of_type
  }


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--module-type", "-m", help="name of Soong module type.")
  parser.add_argument(
      "--ignore-by-name",
      default="",
      help="Comma-separated list. When building the tree of transitive dependencies, will not follow dependency edges pointing to module names listed by this flag."
  )
  args = parser.parse_args()

  module_type = args.module_type
  ignore_by_name = args.ignore_by_name

  module_graph = dependency_analysis.get_json_module_type_info(module_type)
  type_infos = module_type_info_from_json(module_graph, module_type,
                                          ignore_by_name.split(","))
  writer = csv.writer(sys.stdout)
  writer.writerow([
      "module name",
      "properties",
      "java source extensions",
  ])
  for module, module_type_info in sorted(type_infos.items()):
    writer.writerow([
        module,
        ("[\"%s\"]" % '"\n"'.join([
            "%s: %s" % (mtype, ",".join(sorted(properties))) for mtype,
            properties in sorted(module_type_info.type_to_properties.items())
        ]) if len(module_type_info.type_to_properties) else "[]"),
        ("[\"%s\"]" %
         '", "'.join(sorted(module_type_info.java_source_extensions))
         if len(module_type_info.java_source_extensions) else "[]"),
    ])


if __name__ == "__main__":
  main()
