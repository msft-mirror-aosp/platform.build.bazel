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
import argparse
import os
from enum import Enum
from collections import defaultdict

class Severity(Enum):
  ENABLED_ERRORS=0
  ENABLED_WARNINGS=1
  DISABLED_CHECKS=2

  def to_flag_string(self):
    if self == Severity.ENABLED_ERRORS:
      return "ERROR"
    elif self == Severity.ENABLED_WARNINGS:
      return "WARN"
    else:
      return "OFF"

def extract_error_prone_default_checks_by_severity(filename):
  """
  Args:
    filename: filename containing the default checks in a version of Errorprone

  Returns:
    default_checks: a dictionary representing the Default Errorprone checks, a
    check_name maps to a severity.
  """
  default_checks = {}

  with open(filename) as f:
    lines = f.readlines()

  current_severity = ""
  for line in lines:
    line = line[:-1]
    if line in [severity.name for severity in Severity]:
      current_severity = Severity[line]
    else:
      default_checks[line] = current_severity
  return default_checks

def get_bazel_compatibility_checks(soong_file, bazel_file):
  """
  Args:
    soong_file: name of file containing the default checks in the Soong version
      of Errorprone
    bazel_file: name of  file containing the default checks in the Bazel version
      of Errorprone


  Returns:
    a dictionary representing the checks that need to be modified in
    Bazel in order for its checks to match Soong's default checks.
    check_name maps to a severity.
  """
  soong_defaults = extract_error_prone_default_checks_by_severity(soong_file)
  bazel_defaults= extract_error_prone_default_checks_by_severity(bazel_file)

  return {
      check:Severity.DISABLED_CHECKS
      for check in bazel_defaults
      if check not in soong_defaults and bazel_defaults[check] != Severity.DISABLED_CHECKS
  }|{
      check:soong_severity
      for check, soong_severity in soong_defaults.items()
      if check not in bazel_defaults or soong_severity != bazel_defaults[check]
  }


def check_to_flag_string(check_name, severity):
  return "-Xep:" + check_name + ":" + severity.to_flag_string()

def checks_to_flags(compatibility_checks):
  """
  iterates over items in compatibility_checks dic and returns a dic of the flags
  using the -Xep:<checkName>[:severity] format

  Args:
    compatibility_checks: output from checks_dic.

  Returns:
    severity_to_flag: Dic mapping severities to the command-line flag

  """
  severity_to_flag = defaultdict(list)

  for check_name, severity in compatibility_checks.items():
    severity_to_flag[severity].append(check_to_flag_string(check_name, severity))

  for severity in severity_to_flag:
    severity_to_flag[severity].sort()

  return severity_to_flag


def license_header():
  return "# Copyright (C) 2023 The Android Open Source Project\n" \
         "#\n" \
         "# Licensed under the Apache License, Version 2.0 (the \"License\");\n" \
         "# you may not use this file except in compliance with the License.\n" \
         "# You may obtain a copy of the License at\n" \
         "#\n" \
         "#      http://www.apache.org/licenses/LICENSE-2.0\n" \
         "#\n" \
         "# Unless required by applicable law or agreed to in writing, software\n" \
         "# distributed under the License is distributed on an \"AS IS\" BASIS,\n" \
         "# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n" \
         "# See the License for the specific language governing permissions and\n" \
         "# limitations under the License.\n\n" \

def output_as_bzl_file(flags):
  filename =  os.path.dirname(os.path.abspath(__file__)) + "/errorprone_flags.bzl"

  with open(filename, 'w') as f:
    f.write(license_header())
    f.write("#  DO NOT MODIFY: This file is auto-generated by errorProneCompatibilityFlags.sh\n")
    f.write("errorprone_soong_bazel_diffs = [\n")
    for severity in Severity:
      f.write("    # Errorprone {severity}\n".format(severity=severity.name))
      for flag in flags[severity]:
        f.write("    \"{flag}\",\n".format(flag=flag))

    f.write("]\n")

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("--soong_file", required=True,
                      help="file containing the default checks in the "
                           "Soong version of Error Prone")
  parser.add_argument("--bazel_file",required=True,
                      help="file containing the default checks in the"
                           "Bazel version of the Error Prone")
  args = parser.parse_args()

  compatibility_checks = get_bazel_compatibility_checks(args.soong_file, args.bazel_file)
  compatibility_flags = checks_to_flags(compatibility_checks)

  output_as_bzl_file(compatibility_flags)

if __name__ == '__main__':
  main()