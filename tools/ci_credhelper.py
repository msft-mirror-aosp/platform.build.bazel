#! /usr/bin/env python3

"""A credential helper for Bazel, intended for CI builds on Android Build."""

import datetime
import json
import os
import re
import sys
from typing import Dict, Optional, Sequence
import urllib.error
import urllib.request


_GOOGLE_URI_RE = re.compile(r"^https://[^.]+\.(?:pkg\.dev|googleapis\.com)(?:/.*)$")
_RFC3339_FORMAT = "%Y-%m-%dT%H:%M:%SZ"
_TIMEOUT = 60


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
  try:
    response_str = _request(
        "GET",
        {"Metadata-Flavor": "Google"},
        f"http://{metadata_server}/computeMetadata/v1/instance/service-accounts/default/token?alt=json",
    )
  except (urllib.error.HTTPError, urllib.error.URLError) as e:
    raise CredentialError("Failed to read token from metadata server") from e

  try:
    response = json.loads(response_str)
    token, expires_in = response["access_token"], response["expires_in"]
  except (json.JSONDecodeError, KeyError) as e:
    raise CredentialError(f"Failed to parse response from metadata server: {response_str}") from e

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


def _request(
    method: Optional[str],
    headers: Dict[str, str],
    url: str,
) -> str:
  """Makes an HTTP request and returns the response body."""
  req = urllib.request.Request(
      url,
      headers=headers,
      method=method,
  )
  with urllib.request.urlopen(req, timeout=_TIMEOUT) as resp:
    return resp.read().decode("utf-8")


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
