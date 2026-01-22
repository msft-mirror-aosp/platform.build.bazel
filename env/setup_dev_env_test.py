"""Tests for setup_dev_env."""

from absl.testing import absltest
from build.bazel.env import setup_dev_env


class SetupDevEnvTest(absltest.TestCase):
  """Tests for local dev setup script."""
  workspace_root = '/google/cog/cloud/user/workspace-name/googleplex-android'

  def setUp(self):
    super().setUp()
    setup_dev_env.CARTFS_MOUNT = '/path/does/not/exist'

  def test_build_env_bazelrc_glinux_desktop(self):
    env_bazelrc = setup_dev_env.build_env_bazelrc(
        setup_dev_env.Platform.GLINUX_DESKTOP, self.workspace_root)
    self.assertEqual(
        env_bazelrc,
        (
            'import %workspace%/tools/vendor/google/bazel/glinux.bazelrc\n'
            'build --config=rcache\n'
            'build --config=release\n'
        ),
    )

  def test_build_env_bazelrc_with_cartfs(self):
    setup_dev_env.CARTFS_MOUNT = absltest.get_default_test_tmpdir()
    env_bazelrc = setup_dev_env.build_env_bazelrc(
        setup_dev_env.Platform.GLINUX_DESKTOP, self.workspace_root)
    self.assertEqual(
        env_bazelrc,
        (
            'import %workspace%/tools/vendor/google/bazel/glinux.bazelrc\n'
            f'startup --output_base={setup_dev_env.CARTFS_MOUNT}/a4b9186eaa242a59f802b0b2b29770df\n'
            'build --config=rcache\n'
            'build --config=release\n'
        ),
    )

  def test_build_env_bazelrc_others(self):
    for platform in {
        setup_dev_env.Platform.GLINUX_LAPTOP,
        setup_dev_env.Platform.WINDOWS,
        setup_dev_env.Platform.MAC,
    }:
      env_bazelrc = setup_dev_env.build_env_bazelrc(platform, self.workspace_root)
      self.assertEqual(
          env_bazelrc,
          (
              'build --google_default_credentials\n'
              'build --config=rcache\n'
              'build --config=release\n'
          ),
      )


if __name__ == '__main__':
  absltest.main()
