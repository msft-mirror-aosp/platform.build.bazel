#!/usr/bin/env python3

# Copyright (C) 2022 The Android Open Source Project
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
import csv
import functools
import re
import statistics
import sys
from decimal import Decimal
from typing import Callable

from typing.io import TextIO

NA = "--:--"


def mark_if_clean(line: dict) -> dict:
  if line['build_type'].startswith("CLEAN "):
    line["description"] = "CLEAN " + line["description"]
    line["build_type"] = line["build_type"].replace("CLEAN ", "", 1)
  return line


def normalize_rebuild(line: dict) -> dict:
  line['description'] = re.sub(r'^(rebuild)-[\d+](.*)$', '\\1\\2',
                               line['description'])
  return line


def groupby(xs: list[dict], keyfn: Callable[[dict], str]) -> dict[
  str, list[dict]]:
  grouped = {}
  for x in xs:
    k = keyfn(x)
    grouped.setdefault(k, []).append(x)
  return grouped


def pretty_time(t_secs: Decimal) -> str:
  s = int(t_secs.to_integral_exact())
  h = int(s / 3600)
  s = s % 3600
  m = int(s / 60)
  s = s % 60
  if h > 0:
    as_str = f'{h}:{m:02d}:{s:02d}'
  elif m > 0:
    as_str = f'{m}:{s:02d}'
  else:
    as_str = str(s)
  return f'{as_str:>8s}'


def write_table(out: TextIO, rows: list[list[str]]):
  def cell_width(prev, row):
    for i in range(len(row)):
      if len(prev) <= i:
        prev.append(0)
      prev[i] = max(prev[i], len(str(row[i])))
    return prev

  separators = ["-" * len(cell) for cell in rows[0]]
  rows.insert(1, separators)
  widths = functools.reduce(cell_width, rows, [])
  fmt = "  ".join([f"%-{width}s" for width in widths]) + "\n"
  for r in rows:
    out.write(fmt % tuple([str(cell) for cell in r]))


def seconds(s, acc=Decimal(0.0)) -> Decimal:
  colonpos = s.find(':')
  if colonpos > 0:
    left_part = s[0:colonpos]
  else:
    left_part = s
  acc = acc * 60 + Decimal(left_part)
  if colonpos > 0:
    return seconds(s[colonpos + 1:], acc)
  else:
    return acc


def pretty(filename: str, include_rebuilds: bool):
  with open(filename) as f:
    lines = [mark_if_clean(normalize_rebuild(line)) for line in
             csv.DictReader(f) if
             include_rebuilds or not line['description'].startswith('rebuild-')]

  for line in lines:
    if line["build_result"] != "SUCCESS":
      print(f"{line['build_result']}: "
            f"{line['description']} / {line['build_type']}")

  by_cuj = groupby(lines, lambda l: l["description"])
  by_cuj_by_build_type = {
    k: groupby(v, lambda l: l["build_type"]) for k, v in
    by_cuj.items()}

  build_types = []
  for line in lines:
    build_type = line["build_type"]
    if build_type not in build_types:
      build_types.append(line["build_type"])

  rows = [["cuj", "target"] + build_types]  # headers
  for cuj, by_build_type in by_cuj_by_build_type.items():
    targets = next(iter(by_build_type.values()))[0]["targets"]
    row = [cuj, str(targets)]
    for build_type in build_types:
      lines = by_build_type.get(build_type)
      if not lines:
        row.append(NA)
      else:
        times = [seconds(line['time']) for line in lines]
        cell = pretty_time(statistics.median(times))
        if len(lines) > 1:
          cell = f'{cell}[N={len(lines)}]'
        row.append(cell)
    rows.append(row)

  write_table(sys.stdout, rows)


if __name__ == "__main__":
  p = argparse.ArgumentParser()
  p.add_argument('--include-rebuilds', default=False, action='store_true')
  p.add_argument('summary_file')
  options = p.parse_args()
  pretty(options.summary_file, options.include_rebuilds)
