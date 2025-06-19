"""Tests for setup_dev_env."""

from absl.testing import absltest
from build.bazel.env import setup_dev_env

class SetupDevEnvTest(absltest.TestCase):
  """Tests for local dev setup script."""

  def test_build_env_bazelrc_glinux_desktop(self):
    env_bazelrc = setup_dev_env.build_env_bazelrc(
        setup_dev_env.Platform.GLINUX_DESKTOP)
    self.assertEqual(
        env_bazelrc,
        (
            'import %workspace%/tools/vendor/google/bazel/glinux.bazelrc\n'
            'common --config=rcache\n'
            'common --config=release\n'
        ),
    )

  def test_build_env_bazelrc_others(self):
    for platform in {
        setup_dev_env.Platform.GLINUX_LAPTOP,
        setup_dev_env.Platform.WINDOWS,
        setup_dev_env.Platform.MAC,
    }:
      env_bazelrc = setup_dev_env.build_env_bazelrc(platform)
      self.assertEqual(
          env_bazelrc,
          (
              'common --google_default_credentials\n'
              'common --config=rcache\n'
              'common --config=release\n'
          ),
      )


if __name__ == '__main__':
  absltest.main()
