"""Script to set up a local development environment."""

import enum
import hashlib
import logging
import pathlib
import platform

CARTFS_MOUNT = '/google/cartfs/mount'


class Platform(enum.Enum):
  UNKNOWN = 0
  GLINUX_DESKTOP = 1
  GLINUX_LAPTOP = 2
  WINDOWS = 3
  MAC = 4


def detect_platform() -> Platform:
  """Returns the platform the script is running on."""
  system = platform.system()
  if system == 'Linux':
    lsb_release = pathlib.Path('/etc/lsb-release').read_text()
    if 'GOOGLE_ROLE=desktop' in lsb_release:
      return Platform.GLINUX_DESKTOP
    if 'GOOGLE_ROLE=laptop' in lsb_release:
      return Platform.GLINUX_LAPTOP
  if system == 'Windows':
    return Platform.WINDOWS
  if system == 'Darwin':
    return Platform.MAC
  return Platform.UNKNOWN


def find_workspace_root() -> pathlib.Path:
  """Returns the path to the workspace root.

  Raises:
    FileNotFoundError: If the workspace root could not be found.
  """
  path = pathlib.Path(__file__)
  for path in path.parents:
    if (path / '.repo').is_dir():
      return path
    if (path / '.supermanifest').exists():
      return path
  else:
    raise FileNotFoundError('Could not find workspace root')


def build_env_bazelrc(platform: Platform, workspace_root: pathlib.Path) -> str:
  """Returns the env.bazelrc file for the given platform."""
  bazelrc = ''
  if platform is Platform.GLINUX_DESKTOP:
    bazelrc += 'import %workspace%/tools/vendor/google/bazel/glinux.bazelrc\n'
    if pathlib.Path(CARTFS_MOUNT).exists():
      # Configure CartFS for reducing disk usage on output artifacts.
      workspace_hash = hashlib.md5(
          str(workspace_root).encode('utf-8'), usedforsecurity=False
      ).hexdigest()
      bazelrc += f'startup --output_base={CARTFS_MOUNT}/{workspace_hash}\n'
  else:
    bazelrc += 'common --google_default_credentials\n'
  bazelrc += 'common --config=rcache\n'
  bazelrc += 'common --config=release\n'
  return bazelrc


def main():
  logging.basicConfig(level=logging.INFO)

  platform = detect_platform()
  workspace_root = find_workspace_root()

  logging.info('Detected platform %s', platform)
  logging.info('Found workspace root %s', workspace_root)

  env_bazelrc_contents = build_env_bazelrc(platform, workspace_root)
  env_bazelrc_path = workspace_root / 'env.bazelrc'
  env_bazelrc_path.write_text(env_bazelrc_contents)
  logging.info('Wrote env.bazelrc')


if __name__ == '__main__':
  main()
