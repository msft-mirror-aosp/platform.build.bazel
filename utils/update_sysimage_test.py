#!/usr/bin/env python3
"""Tests for update_sysimage.py."""

import unittest
from unittest.mock import patch, MagicMock
import os
import tempfile
from pathlib import Path
import sys
import subprocess

# Add the directory containing the script to the python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import update_sysimage
from update_sysimage import ImageTarget


class TestUpdateSysimage(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.module_file = Path(self.temp_dir.name) / "MODULE.bazel"
        self.module_content = """
# BEGIN android-x86_64
multisource_repo.archive(
    name = "android-x86_64",
    goog = {
        "url": "old_url",
        "sha256": "old_sha256",
    },
)
# END android-x86_64
# BEGIN android16k-x86_64
gcs_archive(
    name = "android16k-x86_64",
    sha256 = "old_sha256",
    url = "old_url",
)
# END android16k-x86_64
# BEGIN android-arm64-v8a
gcs_archive(
    name = "android-arm64-v8a",
    sha256 = "old_sha256",
    url = "old_url",
)
# END android-arm64-v8a
# BEGIN android16k-arm64-v8a
gcs_archive(
    name = "android16k-arm64-v8a",
    sha256 = "old_sha256",
    url = "old_url",
)
# END android16k-arm64-v8a
"""
        with open(self.module_file, "w") as f:
            f.write(self.module_content)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_validate_targets_success(self):
        targets = [
            ImageTarget("x86_64", True),
            ImageTarget("arm64", True),
        ]
        success, error_msg = update_sysimage.validate_targets(targets, self.module_file)
        self.assertTrue(success)
        self.assertIsNone(error_msg)

    def test_validate_targets_missing(self):
        # Create a module file with a missing target
        with open(self.module_file, "w") as f:
            f.write("# BEGIN android-x86_64\n# END android-x86_64")

        targets = [ImageTarget("x86_64", False)]
        success, error_msg = update_sysimage.validate_targets(targets, self.module_file)
        self.assertFalse(success)
        self.assertIn("android-x86_64", error_msg)

    @patch("update_sysimage.subprocess.run")
    @patch("update_sysimage.calculate_sha256")
    @patch("update_sysimage.Path.exists")
    @patch("update_sysimage.Path.unlink")
    def test_update_target_success(
        self, mock_remove, mock_exists, mock_sha256, mock_run
    ):
        mock_sha256.return_value = "new_sha256"
        mock_exists.return_value = True

        # Mock subprocess.run based on arguments
        def mock_run_cmd(args, **kwargs):
            if "gcloud" in args and "ls" in args:
                m = MagicMock()
                m.returncode = 1  # Not found on GCS
                return m
            return MagicMock(returncode=0)

        mock_run.side_effect = mock_run_cmd

        target = ImageTarget("x86_64", False)
        updated_content = update_sysimage.update_target(
            target=target,
            build_id="12345",
            gcs_bucket="gs://dummy-bucket",
            force=False,
            dry_run=False,
            current_content=self.module_content,
        )

        self.assertIn(
            '"url": "gs://dummy-bucket/sys-img/sdk_gphone64_x86_64-userdebug/sdk-repo-linux-system-images-12345.zip"',
            updated_content,
        )
        self.assertIn('"sha256": "new_sha256"', updated_content)

    @patch("update_sysimage.subprocess.run")
    @patch("update_sysimage.calculate_sha256")
    @patch("update_sysimage.Path.exists")
    @patch("update_sysimage.Path.unlink")
    def test_update_target_success_separated_attributes(
        self, mock_remove, mock_exists, mock_sha256, mock_run
    ):
        # Setup content with separated attributes
        separated_content = """
# BEGIN android-x86_64
multisource_repo.archive(
    name = "android-x86_64",
    goog = {
        "sha256": "old_sha256",
        "url": "old_url",
    },
)
# END android-x86_64
"""
        mock_sha256.return_value = "new_sha256"
        mock_exists.return_value = True

        def mock_run_cmd(args, **kwargs):
            if "gcloud" in args and "ls" in args:
                m = MagicMock()
                m.returncode = 1
                return m
            return MagicMock(returncode=0)

        mock_run.side_effect = mock_run_cmd

        target = ImageTarget("x86_64", False)
        updated_content = update_sysimage.update_target(
            target=target,
            build_id="12345",
            gcs_bucket="gs://dummy-bucket",
            force=False,
            dry_run=False,
            current_content=separated_content,
        )

        self.assertIn('"sha256": "new_sha256"', updated_content)
        self.assertIn(
            '"url": "gs://dummy-bucket/sys-img/sdk_gphone64_x86_64-userdebug/sdk-repo-linux-system-images-12345.zip"',
            updated_content,
        )

    @patch("update_sysimage.subprocess.run")
    @patch("update_sysimage.calculate_sha256")
    @patch("update_sysimage.Path.exists")
    @patch("update_sysimage.Path.unlink")
    def test_update_target_exists_on_gcs_still_updates_module(
        self, mock_remove, mock_exists, mock_sha256, mock_run
    ):
        mock_sha256.return_value = "new_sha256"
        mock_exists.return_value = True

        # Mock subprocess.run
        def mock_run_cmd(args, **kwargs):
            if "gcloud" in args and "ls" in args:
                m = MagicMock()
                m.returncode = 0  # File exists
                return m
            return MagicMock(returncode=0)

        mock_run.side_effect = mock_run_cmd

        target = ImageTarget("x86_64", False)
        updated_content = update_sysimage.update_target(
            target=target,
            build_id="12345",
            gcs_bucket="gs://dummy-bucket",
            force=False,
            dry_run=False,
            current_content=self.module_content,
        )

        self.assertIn('"sha256": "new_sha256"', updated_content)

        # Verify gcloud storage cp was NOT called
        cp_called = any(
            "cp" in call.args[0]
            for call in mock_run.call_args_list
            if "gcloud" in call.args[0]
        )
        self.assertFalse(
            cp_called,
            "gcloud storage cp should not be called when file exists and force=False",
        )

    @patch("update_sysimage.subprocess.run")
    @patch("update_sysimage.calculate_sha256")
    @patch("update_sysimage.Path.exists")
    @patch("update_sysimage.Path.unlink")
    def test_update_target_dry_run(
        self, mock_remove, mock_exists, mock_sha256, mock_run
    ):
        mock_sha256.return_value = "dry_run_sha256"
        mock_exists.return_value = True
        mock_run.return_value = MagicMock(returncode=0)

        target = ImageTarget("x86_64", True)
        updated_content = update_sysimage.update_target(
            target=target,
            build_id="54321",
            gcs_bucket="gs://dummy-bucket",
            force=False,
            dry_run=True,
            current_content=self.module_content,
        )

        # Verify hash is in the returned content
        self.assertIn("dry_run_sha256", updated_content)
        self.assertIn("sdk-repo-linux-system-images-54321.zip", updated_content)

        # Verify gcloud storage cp was NOT called
        cp_called = any(
            "cp" in call.args[0]
            for call in mock_run.call_args_list
            if "gcloud" in call.args[0]
        )
        self.assertFalse(
            cp_called, "gcloud storage cp should not be called in dry-run mode"
        )

    @patch("update_sysimage.subprocess.run")
    @patch("update_sysimage.calculate_sha256")
    @patch("update_sysimage.Path.exists")
    @patch("update_sysimage.Path.unlink")
    def test_update_target_gcs_archive(
        self, mock_remove, mock_exists, mock_sha256, mock_run
    ):
        # Setup content with gcs_archive
        gcs_content = """
# BEGIN android16k-x86_64
gcs_archive(
    name = "android16k-x86_64",
    sha256 = "old_sha256",
    url = "old_url",
)
# END android16k-x86_64
"""
        mock_sha256.return_value = "new_sha256"
        mock_exists.return_value = True

        def mock_run_cmd(args, **kwargs):
            if "gcloud" in args and "ls" in args:
                m = MagicMock()
                m.returncode = 1
                return m
            return MagicMock(returncode=0)

        mock_run.side_effect = mock_run_cmd

        target = ImageTarget("x86_64", True)
        updated_content = update_sysimage.update_target(
            target=target,
            build_id="12345",
            gcs_bucket="gs://dummy-bucket",
            force=False,
            dry_run=False,
            current_content=gcs_content,
        )

        self.assertIn('sha256 = "new_sha256"', updated_content)
        self.assertIn(
            'url = "gs://dummy-bucket/sys-img/sdk_gphone16k_x86_64-userdebug/sdk-repo-linux-system-images-12345.zip"',
            updated_content,
        )

    @patch("update_sysimage.subprocess.run")
    def test_update_target_fetch_fail(self, mock_run):
        # Mock fetch_artifact to fail
        mock_run.side_effect = subprocess.CalledProcessError(1, "fetch")

        target = ImageTarget("x86_64", False)
        updated_content = update_sysimage.update_target(
            target=target,
            build_id="12345",
            gcs_bucket="gs://dummy-bucket",
            force=False,
            dry_run=False,
            current_content=self.module_content,
        )

        # Verify content was NOT updated
        self.assertEqual(updated_content, self.module_content)


if __name__ == "__main__":
    unittest.main()
