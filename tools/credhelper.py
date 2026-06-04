#! /usr/bin/env python3
"""A credential helper for Bazel.

If on glinux, uses the credhelper from devtools/blaze/bazel/credhelper.
If BUILD_NUMBER is set, uses ci_credhelper.py.
Otherwise, uses gcloud to get an access token.
"""

import datetime
import json
import os
import pathlib
import platform
import re
import subprocess
import sys
from typing import Optional, Sequence
from urllib import parse


ALLOWED_DOMAIN_REGEXS = [
    r".*\.googleapis\.com",
    "chrome-infra-packages.appspot.com",
    r".*\.pkg\.dev",
]


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
  domain = parse.urlsplit(uri).netloc
  for allowed_domain in ALLOWED_DOMAIN_REGEXS:
    if re.match(allowed_domain, domain):
      break
  else:
    raise ValueError(f"Unsupported URI: {uri}")
  if is_glinux():
    result = subprocess.run(
        [
            "/google/src/head/depot/google3/devtools/blaze/bazel/credhelper/credhelper",
            "get",
        ],
        input=request.encode("utf-8"),
        capture_output=True,
    )
    print(result.stdout.decode("utf-8"), end="")
    return result.returncode
  if os.environ.get("BUILD_NUMBER"):
    result = subprocess.run(
        [
            sys.executable,
            "build/bazel/tools/ci_credhelper.py",
            "get",
        ],
        input=request.encode("utf-8"),
        capture_output=True,
    )
    print(result.stdout.decode("utf-8"), end="")
    return result.returncode

  expires = datetime.datetime.now() + datetime.timedelta(minutes=5)
  print(
      json.dumps({
          "headers": {
              "Authorization": [f"Bearer {get_gcloud_token()}"],
          },
          "expires": expires.strftime("%Y-%m-%dT%H:%M:%SZ"),
      })
  )
  return 0


def get_gcloud_token() -> str:
  """Returns an access token from gcloud."""
  result = subprocess.run(
      ["gcloud", "auth", "application-default", "print-access-token"],
      capture_output=True,
      text=True,
  )
  if result.returncode != 0:
    raise ValueError(f"Failed to get access token: {result.stderr}")
  return result.stdout.strip()


def is_glinux() -> bool:
  """Returns true if the script is running on glinux."""
  if platform.system() != "Linux":
    return False
  lsb_release = pathlib.Path("/etc/lsb-release").read_text()
  return "GOOGLE_ROLE=desktop" in lsb_release


if __name__ == "__main__":
  sys.tracebacklimit = 0
  sys.exit(main(sys.argv[1:]))
