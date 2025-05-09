#!/usr/bin/env bash

# Simple credential helper using gcloud
# Consider using this instead:
# https://github.com/tweag/credential-helper

#set -euo pipefail
#set -o errtrace

if [ "$1" != "get" ]; then
  echo "Unknown subcommand $1" >&2
  exit 1
fi

echo "credentials_helper.sh running" >&2

TOKEN=

#if [ -e /google/src/head/depot/google3/devtools/blaze/bazel/credhelper/credhelper ]; then
#  TOKEN=$(/google/src/head/depot/google3/devtools/blaze/bazel/credhelper/credhelper get)
#fi

if [ -z $TOKEN ]; then
  echo "Trying to get access token from metadata server" >&2
  TOKEN=$(curl -s -X 'GET' -H 'Metadata-Flavor:Google' http://${GCE_METADATA_HOST:-metadata.google.internal}/computeMetadata/v1/instance/service-accounts/default/token | python3 -c $'import json\nimport sys\nj = json.load( sys.stdin )\nprint(j.get("access_token", ""))')
fi

if [ -z $TOKEN ]; then
  echo "Trying to get access token from gcloud auth" >&2
  TOKEN=$(gcloud auth application-default print-access-token || gcloud auth print-access-token)
fi

if [ -z $TOKEN ]; then
  echo "Error, no gcloud access token found" >&2
  exit 1
fi

cat << EOF
{
  "headers": {
    "Authorization": ["Bearer ${TOKEN}"]
  }
}
EOF
