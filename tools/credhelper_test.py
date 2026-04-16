"""Tests for credhelper."""

import io
import json
from unittest import mock
from absl.testing import absltest
from build.bazel.tools import credhelper


class CredhelperTest(absltest.TestCase):

  @mock.patch("sys.stdin.read")
  @mock.patch("subprocess.run")
  @mock.patch("pathlib.Path.read_text")
  @mock.patch("platform.system")
  def test_main_gcloud_success(
      self, mock_system, mock_read_text, mock_run, mock_stdin_read
  ):
    # Setup: Not Glinux, Not CI
    mock_system.return_value = "Darwin"
    mock_stdin_read.return_value = json.dumps({"uri": "https://us-east1-maven.pkg.dev/foo"})

    # Mock gcloud token response
    mock_run.return_value = mock.Mock(returncode=0, stdout="fake-token")

    with mock.patch("os.environ", {}):
      with mock.patch("sys.stdout", new=io.StringIO()) as mock_stdout:
        exit_code = credhelper.main(["get"])

        self.assertEqual(exit_code, 0)
        output = json.loads(mock_stdout.getvalue())
        self.assertEqual(output["headers"]["Authorization"], ["Bearer fake-token"])

        # Verify gcloud was actually called
        mock_run.assert_called_once_with(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True,
            text=True,
        )

  @mock.patch("sys.stdin.read")
  @mock.patch("subprocess.run")
  @mock.patch("platform.system")
  def test_main_ci_build_number(self, mock_system, mock_run, mock_stdin_read):
    # Setup: Not Glinux, but CI (BUILD_NUMBER set)
    mock_system.return_value = "Darwin"
    mock_stdin_read.return_value = json.dumps({"uri": "https://us-east1-maven.pkg.dev/foo"})
    mock_run.return_value = mock.Mock(returncode=0, stdout=b"ci-output")

    with mock.patch("os.environ", {"BUILD_NUMBER": "12345"}):
      with mock.patch("sys.stdout", new=io.StringIO()) as mock_stdout:
        exit_code = credhelper.main(["get"])

        self.assertEqual(exit_code, 0)
        self.assertEqual(mock_stdout.getvalue(), "ci-output")

        # Verify it called ci_credhelper.py
        args = mock_run.call_args[0][0]
        self.assertIn("build/bazel/tools/ci_credhelper.py", args)

  @mock.patch("sys.stdin.read")
  @mock.patch("subprocess.run")
  @mock.patch("pathlib.Path.read_text")
  @mock.patch("platform.system")
  def test_main_glinux_behavior(self, mock_system, mock_read_text, mock_run, mock_stdin_read):
    # Setup: Glinux Desktop
    mock_system.return_value = "Linux"
    mock_read_text.return_value = "GOOGLE_ROLE=desktop"
    mock_stdin_read.return_value = json.dumps({"uri": "https://us-east1-maven.pkg.dev/foo"})
    mock_run.return_value = mock.Mock(returncode=0, stdout=b"glinux-output")

    with mock.patch("sys.stdout", new=io.StringIO()) as mock_stdout:
      exit_code = credhelper.main(["get"])

      self.assertEqual(exit_code, 0)
      self.assertEqual(mock_stdout.getvalue(), "glinux-output")

      # Verify it called the google3 credhelper path
      args = mock_run.call_args[0][0]
      self.assertTrue(any("devtools/blaze/bazel/credhelper" in a for a in args))

  @mock.patch("sys.stdin.read")
  def test_main_invalid_uri(self, mock_stdin_read):
    mock_stdin_read.return_value = json.dumps({"uri": "https://unsupported.com"})

    with self.assertRaisesRegex(ValueError, "Unsupported URI"):
      credhelper.main(["get"])

  @mock.patch("pathlib.Path.read_text")
  @mock.patch("platform.system")
  def test_is_glinux(self, mock_system, mock_read_text):
    # Test Linux with desktop role
    mock_system.return_value = "Linux"
    mock_read_text.return_value = "GOOGLE_ROLE=desktop\nOTHER_STUFF=1"
    self.assertTrue(credhelper.is_glinux())

    # Test Linux without desktop role
    mock_read_text.return_value = "GOOGLE_ROLE=laptop\n"
    self.assertFalse(credhelper.is_glinux())

    # Test non-Linux
    mock_system.return_value = "Darwin"
    self.assertFalse(credhelper.is_glinux())

  @mock.patch("subprocess.run")
  def test_get_gcloud_token_success(self, mock_run):
    mock_run.return_value = mock.Mock(returncode=0, stdout="  token-from-gcloud  \n")

    token = credhelper.get_gcloud_token()

    self.assertEqual(token, "token-from-gcloud")
    mock_run.assert_called_once_with(
        ["gcloud", "auth", "print-access-token"],
        capture_output=True,
        text=True,
    )

  @mock.patch("subprocess.run")
  def test_get_gcloud_token_failure(self, mock_run):
    mock_run.return_value = mock.Mock(returncode=1, stderr="gcloud error")

    with self.assertRaisesRegex(ValueError, "Failed to get access token: gcloud error"):
      credhelper.get_gcloud_token()


if __name__ == "__main__":
  absltest.main()
