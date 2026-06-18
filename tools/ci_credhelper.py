#! /usr/bin/env python3

"""A credential helper for Bazel, intended for CI builds on Android Build."""

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from typing import List, Optional, Sequence


_GOOGLE_URI_RE = re.compile(r"^https://[^.]+\.(?:pkg\.dev|googleapis\.com)(?:/.*)$")
_RFC3339_FORMAT = "%Y-%m-%dT%H:%M:%SZ"


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

  if not os.getenv("BUILD_NUMBER"):
    raise NotImplementedError(f"Not a CI build: {uri}")

  if _GOOGLE_URI_RE.match(uri):
    return _respond_google()

  raise NotImplementedError(f"Unsupported URI: {uri}")


def _respond_google() -> Optional[int]:
  """Responds to a request by fetching a SA token from the metadata server."""
  metadata_server = "metadata.google.internal"
  if os.getenv("GCE_METADATA_HOST"):
    metadata_server = os.getenv("GCE_METADATA_HOST")
  result = _curl(
      "GET",
      ["Metadata-Flavor: Google"],
      f"http://{metadata_server}/computeMetadata/v1/instance/service-accounts/default/token?alt=json",
  )
  if result.returncode != 0:
    raise CredentialError(
        f"Failed to fetch token from metadata server: {result.stderr}"
    )

  try:
    response = json.loads(result.stdout)
    token, expires_in = response["access_token"], response["expires_in"]
  except (json.JSONDecodeError, KeyError):
    raise CredentialError(
        f"Failed to read token from metadata server: {result.stdout}"
    ) from None
  expires = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
      seconds=expires_in
  )
  _print_response(token, expires)


def _print_response(
    token: Optional[str], expires: Optional[datetime.datetime]
) -> None:
  response = {}
  if token:
    response["headers"] = {
        "Authorization": [f"Bearer {token}"],
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
  cmd = [shutil.which("curl"), "-L"]
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
