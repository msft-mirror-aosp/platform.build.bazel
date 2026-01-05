"""Script to set up a local development environment."""

import dataclasses
import enum
import hashlib
import logging
import os
import pathlib
import platform

CARTFS_MOUNT = '/google/cartfs/mount'


class Platform(enum.Enum):
  UNKNOWN = 0
  GLINUX_DESKTOP = 1
  GLINUX_LAPTOP = 2
  WINDOWS = 3
  MAC = 4


@dataclasses.dataclass(frozen=True)
class WorkspaceInfo:
  """Contains information about the detected workspace."""
  is_cog: bool
  root: pathlib.Path


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


def check_app_default_credentials(host_platform: Platform):
  """Checks Google ADC are set, and prompts the user to set them otherwise."""
  if host_platform == Platform.GLINUX_DESKTOP:
    return
  if host_platform == Platform.WINDOWS:
    config_path = pathlib.Path(os.environ.get('APPDATA'))
  else:
    config_path = pathlib.Path(os.environ.get('HOME')) / '.config'
  adc_path = config_path / 'gcloud' / 'application_default_credentials.json'

  if adc_path.exists():
    logging.info('Found application default credentials at %s', adc_path)
  else:
    logging.error(
        'Google Application Default Credentials (ADC) not found.'
    )
    cmd = (
        'gcloud auth application-default login'
        ' --project="google.com:android-studio-alphasource"'
    )
    logging.error(f'Please set up ADC by running `{cmd}`')
    logging.error('Download gcloud CLI from https://docs.cloud.google.com/sdk/docs/install-sdk')


def find_workspace_root() -> WorkspaceInfo:
  """Returns information about the workspace root.

  Raises:
    FileNotFoundError: If the workspace root could not be found.
  """
  path = pathlib.Path(__file__)
  for path in path.parents:
    if (path / '.repo').is_dir():
      return WorkspaceInfo(is_cog=False, root=path)
    if (path / '.supermanifest').exists():
      return WorkspaceInfo(is_cog=True, root=path)
  else:
    raise FileNotFoundError('Could not find workspace root')


def build_env_bazelrc(host_platform: Platform, workspace_root: pathlib.Path) -> str:
  """Returns the env.bazelrc file for the given platform."""
  bazelrc = ''
  if host_platform is Platform.GLINUX_DESKTOP:
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


def check_python_env_vars():
  """Displays a warning if Python bytecode will pollute the Cog workspace."""
  if (
      'PYTHONPYCACHEPREFIX' in os.environ
      or 'PYTHONDONTWRITEBYTECODE' in os.environ
  ):
    return
  logging.error("""
    Environment variables PYTHONPYCACHEPREFIX or PYTHONDONTWRITEBYTECODE must
    be set to avoid writing *.pyc bytecode in the Cog workspace. Without this,
    python build actions will write *.pyc in the workspace and you can run into
    go/cider-g-common-issues#why-workspaces-become-unresponsive.

    Add the following to your shell profile:
    export PYTHONPYCACHEPREFIX=~/.pycache
    """)


def main():
  logging.basicConfig(level=logging.INFO)

  host_platform = detect_platform()
  workspace_info = find_workspace_root()

  logging.info('Detected platform %s', host_platform)
  logging.info('Found workspace root %s', workspace_info.root)

  env_bazelrc_contents = build_env_bazelrc(host_platform, workspace_info.root)
  env_bazelrc_path = workspace_info.root / 'env.bazelrc'
  env_bazelrc_path.write_text(env_bazelrc_contents)
  if workspace_info.is_cog:
    check_python_env_vars()
  logging.info('Wrote env.bazelrc')
  check_app_default_credentials(host_platform)


if __name__ == '__main__':
  logging.basicConfig(format='%(levelname)s: %(message)s', level=logging.INFO)
  main()
