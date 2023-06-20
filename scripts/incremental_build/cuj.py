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
import dataclasses
import enum
import logging
import os
from pathlib import Path
from typing import Callable
from typing import TypeAlias
import util


Action: TypeAlias = Callable[[], None]
Verifier: TypeAlias = Callable[[], None]


def de_src(p: Path) -> str:
  return str(p.relative_to(util.get_top_dir()))


def src(p: str) -> Path:
  return util.get_top_dir().joinpath(p)


class InWorkspace(enum.Enum):
  """For a given file in the source tree, the counterpart in the symlink forest
   could be one of these kinds.
  """
  SYMLINK = enum.auto()
  NOT_UNDER_SYMLINK = enum.auto()
  UNDER_SYMLINK = enum.auto()
  OMISSION = enum.auto()

  @staticmethod
  def ws_counterpart(src_path: Path) -> Path:
    return util.get_out_dir().joinpath('soong/workspace').joinpath(
        de_src(src_path))

  def verifier(self, src_path: Path) -> Verifier:
    @skip_when_soong_only
    def f():
      ws_path = InWorkspace.ws_counterpart(src_path)
      actual: InWorkspace | None = None
      if ws_path.is_symlink():
        actual = InWorkspace.SYMLINK
        if not ws_path.exists():
          logging.warning('Dangling symlink %s', ws_path)
      elif not ws_path.exists():
        actual = InWorkspace.OMISSION
      else:
        for p in ws_path.parents:
          if not p.is_relative_to(util.get_out_dir()):
            actual = InWorkspace.NOT_UNDER_SYMLINK
            break
          if p.is_symlink():
            actual = InWorkspace.UNDER_SYMLINK
            break

      if self != actual:
        raise AssertionError(
            f'{ws_path} expected {self.name} but got {actual.name}')
      logging.info(f'VERIFIED {de_src(ws_path)} {self.name}')

    return f


def skip_when_soong_only(func: Verifier) -> Verifier:
  """A decorator for Verifiers that are not applicable to soong-only builds"""

  def wrapper():
    if InWorkspace.ws_counterpart(util.get_top_dir()).exists():
      func()

  return wrapper


@skip_when_soong_only
def verify_symlink_forest_has_only_symlink_leaves():
  """Verifies that symlink forest has only symlinks or directories but no
  files except for merged BUILD.bazel files"""

  top_in_ws = InWorkspace.ws_counterpart(util.get_top_dir())

  for root, dirs, files in os.walk(top_in_ws, topdown=True, followlinks=False):
    for file in files:
      if file == 'symlink_forest_version' and top_in_ws.samefile(root):
        continue
      f = Path(root).joinpath(file)
      if file != 'BUILD.bazel' and not f.is_symlink():
        raise AssertionError(f'{f} unexpected')

  logging.info('VERIFIED Symlink Forest has no real files except BUILD.bazel')


@dataclasses.dataclass(frozen=True)
class CujStep:
  verb: str
  """a human-readable description"""
  apply_change: Action
  """user action(s) that are performed prior to a build attempt"""
  verify: Verifier = verify_symlink_forest_has_only_symlink_leaves
  """post-build assertions, i.e. tests.
  Should raise `Exception` for failures.
  """


@dataclasses.dataclass(frozen=True)
class CujGroup:
  """A sequence of steps to be performed, such that at the end of all steps the
  initial state of the source tree is attained.
  NO attempt is made to achieve atomicity programmatically. It is left as the
  responsibility of the user.
  """
  description: str
  steps: list[CujStep]

  def __str__(self) -> str:
    if len(self.steps) < 2:
      return f'{self.steps[0].verb} {self.description}'.strip()
    return ' '.join(
        [f'({chr(ord("a") + i)}) {step.verb} {self.description}'.strip() for
         i, step in enumerate(self.steps)])
