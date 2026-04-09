#!/usr/bin/env python3

import datetime
import json
import os
import pathlib
import subprocess
import sys
import unittest
from unittest import mock

# Add the directory containing cred_helper to the path so we can import it
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import cred_helper


class TestCredHelper(unittest.TestCase):

    def setUp(self):
        # Patch print to capture output
        self.mock_print_patcher = mock.patch("builtins.print")
        self.mock_print = self.mock_print_patcher.start()

    def tearDown(self):
        self.mock_print_patcher.stop()

    # --- main() Tests ---

    def test_main_invalid_command(self):
        with self.assertRaisesRegex(ValueError, "Unknown command"):
            cred_helper.main(["store"])

    @mock.patch("sys.stdin")
    def test_main_invalid_json(self, mock_stdin):
        mock_stdin.read.return_value = "{ invalid json"
        with self.assertRaisesRegex(ValueError, "Invalid JSON"):
            cred_helper.main(["get"])

    @mock.patch("sys.stdin")
    def test_main_missing_uri(self, mock_stdin):
        mock_stdin.read.return_value = '{"not_uri": "test"}'
        with self.assertRaisesRegex(ValueError, "Missing 'uri' field"):
            cred_helper.main(["get"])

    @mock.patch("sys.stdin")
    def test_main_unsupported_uri(self, mock_stdin):
        mock_stdin.read.return_value = '{"uri": "https://example.com"}'
        with self.assertRaisesRegex(NotImplementedError, "Unsupported URI"):
            cred_helper.main(["get"])

    @mock.patch("sys.stdin")
    @mock.patch("cred_helper._respond_google")
    def test_main_valid_uri_delegation(self, mock_respond_google, mock_stdin):
        mock_stdin.read.return_value = '{"uri": "https://test.googlesource.com/foo"}'
        mock_respond_google.return_value = 0
        result = cred_helper.main(["get"])
        self.assertEqual(result, 0)
        mock_respond_google.assert_called_once_with(
            {"uri": "https://test.googlesource.com/foo"}
        )

    # --- _respond_google() Orchestration Tests ---

    @mock.patch("cred_helper._try_google3_helper")
    @mock.patch("cred_helper._try_metadata_server")
    @mock.patch("cred_helper._try_gcloud_cli")
    @mock.patch("cred_helper._try_adc_file")
    def test_respond_google_first_success(
        self, mock_adc, mock_gcloud, mock_metadata, mock_google3
    ):
        # google3 fails, metadata succeeds. gcloud and adc should NOT be called.
        mock_google3.return_value = False
        mock_metadata.return_value = True

        result = cred_helper._respond_google({"uri": "test"})

        self.assertEqual(result, 0)
        mock_google3.assert_called_once()
        mock_metadata.assert_called_once()
        mock_gcloud.assert_not_called()
        mock_adc.assert_not_called()

    @mock.patch("cred_helper._try_google3_helper")
    @mock.patch("cred_helper._try_metadata_server")
    @mock.patch("cred_helper._try_gcloud_cli")
    @mock.patch("cred_helper._try_adc_file")
    def test_respond_google_all_fail(
        self, mock_adc, mock_gcloud, mock_metadata, mock_google3
    ):
        mock_google3.return_value = False
        mock_metadata.return_value = False
        mock_gcloud.return_value = False
        mock_adc.return_value = False

        with self.assertRaisesRegex(
            cred_helper.CredentialError, "All authentication methods failed"
        ):
            cred_helper._respond_google({"uri": "test"})

    # --- _try_google3_helper() Tests ---

    @mock.patch("shutil.which")
    @mock.patch("os.stat")
    @mock.patch("subprocess.run")
    def test_try_google3_helper_success(self, mock_run, mock_stat, mock_which):
        mock_which.return_value = "/path/to/stubby"
        mock_run.return_value = mock.MagicMock(
            returncode=0,
            stdout=json.dumps({"headers": {"Authorization": ["Bearer token123"]}}),
        )

        result = cred_helper._try_google3_helper(
            {"uri": "https://test.googlesource.com"}
        )

        self.assertTrue(result)
        mock_run.assert_called_once()
        # Verify the printed output
        args, _ = self.mock_print.call_args
        printed_json = json.loads(args[0])
        self.assertEqual(printed_json["headers"]["Authorization"], ["Bearer token123"])
        self.assertEqual(
            printed_json["headers"]["X-Goog-User-Project"], ["emulator-builds"]
        )

    @mock.patch("shutil.which")
    def test_try_google3_helper_no_stubby(self, mock_which):
        mock_which.return_value = None
        result = cred_helper._try_google3_helper(
            {"uri": "https://test.googlesource.com"}
        )
        self.assertFalse(result)

    @mock.patch("shutil.which")
    @mock.patch("os.stat")
    def test_try_google3_helper_no_credhelper(self, mock_stat, mock_which):
        mock_which.return_value = "/path/to/stubby"
        mock_stat.side_effect = FileNotFoundError()
        result = cred_helper._try_google3_helper(
            {"uri": "https://test.googlesource.com"}
        )
        self.assertFalse(result)

    @mock.patch("shutil.which")
    @mock.patch("os.stat")
    def test_try_google3_helper_oserror_126(self, mock_stat, mock_which):
        # Tests the specific "srcfs unmounted" errno 126 branch
        mock_which.return_value = "/path/to/stubby"
        err = OSError()
        err.errno = 126
        mock_stat.side_effect = err

        with self.assertRaisesRegex(cred_helper.CredentialError, "is not accessible"):
            cred_helper._try_google3_helper({"uri": "https://test.googlesource.com"})

    @mock.patch("shutil.which")
    @mock.patch("os.stat")
    def test_try_google3_helper_oserror_other(self, mock_stat, mock_which):
        mock_which.return_value = "/path/to/stubby"
        err = OSError()
        err.errno = 13  # Permission denied
        mock_stat.side_effect = err

        with self.assertRaises(OSError):
            cred_helper._try_google3_helper({"uri": "https://test.googlesource.com"})

    @mock.patch("shutil.which")
    @mock.patch("os.stat")
    @mock.patch("subprocess.run")
    @mock.patch("sys.exit")
    def test_try_google3_helper_failure_exit(
        self, mock_exit, mock_run, mock_stat, mock_which
    ):
        # Tests that if credhelper exists but fails, it triggers sys.exit(returncode)
        mock_which.return_value = "/path/to/stubby"
        mock_run.return_value = mock.MagicMock(returncode=1, stderr="Credhelper failed")

        cred_helper._try_google3_helper({"uri": "https://test.googlesource.com"})
        mock_exit.assert_called_once_with(1)

    # --- _try_metadata_server() Tests ---

    @mock.patch("os.getenv")
    @mock.patch("cred_helper._curl")
    @mock.patch("cred_helper.datetime")
    def test_try_metadata_server_success(self, mock_datetime, mock_curl, mock_getenv):
        # Mock environment variables
        def getenv_side_effect(key, default=None):
            if key == "BUILD_NUMBER":
                return "12345"
            if key == "GCE_METADATA_HOST":
                return default
            return default

        mock_getenv.side_effect = getenv_side_effect

        mock_curl.return_value = mock.MagicMock(
            returncode=0,
            stdout=json.dumps({"access_token": "meta_token", "expires_in": 3600}),
        )

        real_now = datetime.datetime(2023, 1, 1, 12, 0, 0, tzinfo=datetime.timezone.utc)
        mock_datetime.datetime.now.return_value = real_now
        mock_datetime.timezone = datetime.timezone
        mock_datetime.timedelta = datetime.timedelta

        result = cred_helper._try_metadata_server()

        self.assertTrue(result)
        mock_curl.assert_called_once()

        # Verify output
        args, _ = self.mock_print.call_args
        printed_json = json.loads(args[0])
        self.assertEqual(
            printed_json["headers"]["Authorization"], ["Bearer meta_token"]
        )
        self.assertEqual(printed_json["expires"], "2023-01-01T13:00:00Z")

    @mock.patch("os.getenv")
    def test_try_metadata_server_not_ci(self, mock_getenv):
        mock_getenv.return_value = None
        result = cred_helper._try_metadata_server()
        self.assertFalse(result)

    @mock.patch("os.getenv")
    @mock.patch("cred_helper._curl")
    def test_try_metadata_server_bad_json(self, mock_curl, mock_getenv):
        mock_getenv.return_value = "12345"  # BUILD_NUMBER
        mock_curl.return_value = mock.MagicMock(returncode=0, stdout='{"bad": "key"}')

        with self.assertRaisesRegex(
            cred_helper.CredentialError, "Failed to read token from metadata server"
        ):
            cred_helper._try_metadata_server()

    # --- _try_gcloud_cli() Tests ---

    @mock.patch("shutil.which")
    @mock.patch("subprocess.run")
    def test_try_gcloud_cli_success(self, mock_run, mock_which):
        mock_which.return_value = "/path/to/gcloud"
        mock_run.return_value = mock.MagicMock(
            returncode=0, stdout=json.dumps({"token": "gcloud_token"})
        )

        result = cred_helper._try_gcloud_cli()

        self.assertTrue(result)
        args, _ = self.mock_print.call_args
        printed_json = json.loads(args[0])
        self.assertEqual(
            printed_json["headers"]["Authorization"], ["Bearer gcloud_token"]
        )

    @mock.patch("shutil.which")
    def test_try_gcloud_cli_no_gcloud(self, mock_which):
        mock_which.return_value = None
        result = cred_helper._try_gcloud_cli()
        self.assertFalse(result)

    @mock.patch("shutil.which")
    @mock.patch("subprocess.run")
    def test_try_gcloud_cli_failure(self, mock_run, mock_which):
        mock_which.return_value = "/path/to/gcloud"
        mock_run.return_value = mock.MagicMock(returncode=1)
        result = cred_helper._try_gcloud_cli()
        self.assertFalse(result)

    # --- _try_adc_file() Tests ---

    @mock.patch("pathlib.Path.exists")
    @mock.patch("pathlib.Path.read_text")
    @mock.patch("cred_helper._curl")
    @mock.patch("cred_helper.datetime")
    def test_try_adc_file_success(
        self, mock_datetime, mock_curl, mock_read_text, mock_exists
    ):
        mock_exists.return_value = True
        mock_read_text.return_value = json.dumps(
            {
                "client_id": "test_client",
                "client_secret": "test_secret",
                "refresh_token": "test_refresh",
            }
        )
        mock_curl.return_value = mock.MagicMock(
            returncode=0,
            stdout=json.dumps({"access_token": "adc_token", "expires_in": 3600}),
        )

        real_now = datetime.datetime(2023, 1, 1, 12, 0, 0, tzinfo=datetime.timezone.utc)
        mock_datetime.datetime.now.return_value = real_now
        mock_datetime.timezone = datetime.timezone
        mock_datetime.timedelta = datetime.timedelta

        result = cred_helper._try_adc_file()

        self.assertTrue(result)
        args, _ = self.mock_print.call_args
        printed_json = json.loads(args[0])
        self.assertEqual(printed_json["headers"]["Authorization"], ["Bearer adc_token"])

    @mock.patch("pathlib.Path.exists")
    def test_try_adc_file_no_file(self, mock_exists):
        mock_exists.return_value = False
        with self.assertRaises(FileNotFoundError):
            cred_helper._try_adc_file()

    @mock.patch("pathlib.Path.exists")
    @mock.patch("pathlib.Path.read_text")
    @mock.patch("cred_helper._curl")
    def test_try_adc_file_bad_json(self, mock_curl, mock_read_text, mock_exists):
        mock_exists.return_value = True
        mock_read_text.return_value = json.dumps(
            {"client_id": "c", "client_secret": "s", "refresh_token": "r"}
        )
        mock_curl.return_value = mock.MagicMock(
            returncode=0, stdout='{"not_a_token": "missing"}'
        )

        with self.assertRaisesRegex(
            cred_helper.CredentialError, "Failed to read token"
        ):
            cred_helper._try_adc_file()

    # --- _curl() Tests ---

    @mock.patch("shutil.which")
    def test_curl_missing_binary(self, mock_which):
        mock_which.return_value = None
        with self.assertRaisesRegex(RuntimeError, "curl is not installed"):
            cred_helper._curl("GET", [], "http://test")

    @mock.patch("shutil.which")
    @mock.patch("subprocess.run")
    def test_curl_command_construction(self, mock_run, mock_which):
        mock_which.return_value = "/usr/bin/curl"

        cred_helper._curl(
            "POST",
            ["Content-Type: application/json"],
            "http://test",
            "--data",
            "{}",
            check=True,
        )

        mock_run.assert_called_once_with(
            [
                "/usr/bin/curl",
                "-L",
                "-X",
                "POST",
                "-H",
                "Content-Type: application/json",
                "--data",
                "{}",
                "http://test",
            ],
            capture_output=True,
            encoding="utf-8",
            check=True,
        )


if __name__ == "__main__":
    unittest.main()
