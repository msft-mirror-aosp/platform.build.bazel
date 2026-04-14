#! /usr/bin/env python3

"""A cross-platform credential helper for Bazel."""

import datetime
import json
import os
import pathlib
import platform
import re
import shutil
import subprocess
import sys
from typing import Any, List, Mapping, Optional, Sequence


_HELPER_GOOGLE3_PATH = (
    "/google/src/head/depot/google3/devtools/blaze/bazel/credhelper/credhelper"
)
_GOOGLE_URI_RE = re.compile(
    r"^https://([^.]+\.)?((pa\.(sandbox\.)?)?googleapis\.com|pkg\.dev|googlesource\.com)(?:/.*)$"
)
_RFC3339_FORMAT = "%Y-%m-%dT%H:%M:%SZ"
_QUOTA_PROJECT = "emulator-builds"


class CredentialError(Exception):
  pass


def main(argv: Sequence[str]) -> Optional[int]:
  if argv[0] != "get":
    raise ValueError(f"Unknown command: {argv[0]}")
  request = sys.stdin.read()
  try:
    request_json = json.loads(request)
  except json.JSONDecodeError as e:
    raise ValueError(f"Invalid JSON: {request}") from e
  if "uri" not in request_json:
    raise ValueError(f"Missing 'uri' field: {request_json}")
  uri = request_json["uri"]

  if _GOOGLE_URI_RE.match(uri):
    return _respond_google(request_json)

  raise NotImplementedError(f"Unsupported URI: {uri}")


def _respond_google(request_json: Mapping[str, Any]) -> Optional[int]:
  """Responds to a request for a Google API or Artifact Registry URL."""
  if _try_google3_helper(request_json):
    return 0
  if _try_metadata_server():
    return 0
  if _try_adc_file():
    return 0
  if _try_gcloud_cli():
    return 0

  raise CredentialError("All authentication methods failed.")


def _try_google3_helper(request_json: Mapping[str, Any]) -> bool:
  """Try credhelper from google3."""
  if not shutil.which("stubby"):
    return False

  try:
    os.stat(_HELPER_GOOGLE3_PATH)
  except FileNotFoundError:
    return False  # The helper does not exist - fallback to other methods
  except OSError as e:
    if e.errno != 126:
      raise
    # This happens when srcfs is unmounted due to expired credentials
    raise CredentialError(
        f"Path {_HELPER_GOOGLE3_PATH} is not accessible - did you run gcert?"
    ) from None
  else:
    result = subprocess.run(
        [_HELPER_GOOGLE3_PATH, "get"],
        capture_output=True,
        check=False,
        input=json.dumps(request_json),
        encoding="utf-8",
    )
    if result.returncode == 0:
      response = json.loads(result.stdout)
      if "headers" in response and "Authorization" in response["headers"]:
        response["headers"]["X-Goog-User-Project"] = [_QUOTA_PROJECT]
        print(json.dumps(response))
        return True
    else:
      print(result.stderr, file=sys.stderr)
      # If the helper is present but fails then fail completely.
      sys.exit(result.returncode)
  return False


def _try_metadata_server() -> bool:
  """Try metadata server (CI builds only)."""
  if not os.getenv("BUILD_NUMBER"):
    return False

  metadata_server = os.getenv("GCE_METADATA_HOST", "metadata.google.internal")
  result = _curl(
      "GET",
      ["Metadata-Flavor: Google"],
      f"http://{metadata_server}/computeMetadata/v1/instance/service-accounts/default/token?alt=json",
  )
  if result.returncode == 0:
    try:
      response = json.loads(result.stdout)
      token, expires_in = response["access_token"], response["expires_in"]
    except (json.JSONDecodeError, KeyError) as e:
      raise CredentialError(
          f"Failed to read token from metadata server: {result.stdout}"
      ) from None

    now = datetime.datetime.now(datetime.timezone.utc)
    expires = now + datetime.timedelta(seconds=expires_in)
    _print_response(token, expires)
    return True
  return False


def _try_gcloud_cli() -> bool:
  """Fallback to gcloud application default credential."""
  gcloud_bin = shutil.which("gcloud")
  if not gcloud_bin:
    return False

  result = subprocess.run(
      [gcloud_bin, "auth", "application-default", "print-access-token", "--format=json"],
      capture_output=True,
      encoding="utf-8",
      check=False,
  )
  if result.returncode == 0:
    try:
      response = json.loads(result.stdout)
      token = response.get("token")
      if token:
        _print_response(token, None)
        return True
    except json.JSONDecodeError:
      pass
  return False


def _try_adc_file() -> bool:
  """Fallback to local application default credential file manual refresh."""
  config_home = (
      pathlib.Path(os.getenv("APPDATA")) / "gcloud"
      if platform.system() == "Windows"
      else pathlib.Path("~/.config/gcloud").expanduser()
  )
  if os.getenv("CLOUDSDK_CONFIG"):
    config_home = pathlib.Path(os.getenv("CLOUDSDK_CONFIG"))
  credential_path = config_home / "application_default_credentials.json"
  if not credential_path.exists():
    raise FileNotFoundError(
        f"{credential_path} is not found. Create it with `gcloud auth "
        f"application-default login --project={_QUOTA_PROJECT}`."
    )
  credential = json.loads(credential_path.read_text(encoding="utf-8"))
  request = json.dumps({
      "client_id": credential["client_id"],
      "client_secret": credential["client_secret"],
      "refresh_token": credential["refresh_token"],
      "grant_type": "refresh_token",
  })
  result = _curl(
      "POST",
      ["Content-Type: application/json"],
      "https://oauth2.googleapis.com/token",
      "--data-raw",
      request,
      check=True,
  )
  token_json = json.loads(result.stdout)
  try:
    token, expires_in = token_json["access_token"], token_json["expires_in"]
  except KeyError as e:
    raise CredentialError(
        f"Failed to read token: {result.stdout}\n",
        "Try re-auth with `gcloud auth application-default login "
        f"--project={_QUOTA_PROJECT}`"
    ) from None

  now = datetime.datetime.now(datetime.timezone.utc)
  expires = now + datetime.timedelta(seconds=expires_in)
  _print_response(token, expires)
  return True


def _print_response(
    token: Optional[str], expires: Optional[datetime.datetime]
) -> None:
  response = {}
  if token:
    response["headers"] = {
        "Authorization": [f"Bearer {token}"],
        "X-Goog-User-Project": [_QUOTA_PROJECT],
    }
  if expires:
    response["expires"] = expires.astimezone(datetime.timezone.utc).strftime(
        _RFC3339_FORMAT
    )
  print(json.dumps(response))


def _curl(
    method: Optional[str],
    headers: List[str],
    url: str,
    *args: str,
    check: bool = False,
) -> subprocess.CompletedProcess[str]:
  """Makes a curl request and returns the response."""
  curl_bin = shutil.which("curl")
  if not curl_bin:
    raise RuntimeError("curl is not installed but is required for this operation.")

  cmd = [curl_bin, "-L"]
  if method:
    cmd.extend(["-X", method])
  for header in headers:
    cmd.extend(["-H", header])
  cmd.extend(args)
  cmd.append(url)
  return subprocess.run(cmd, capture_output=True, encoding="utf-8", check=check)


if __name__ == "__main__":
  sys.tracebacklimit = 0
  sys.exit(main(sys.argv[1:]))
