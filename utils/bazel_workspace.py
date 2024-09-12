# Copyright 2024 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the',  help="License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an',  help="AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This file prints a Bazel workspace status, and is loaded with bazel's
# --workspace_status_command flag. See the Bazel manual for more:
# https://docs.bazel.build/versions/main/user-manual.html#workspace_status
import getpass
import socket
import os


def getuser() -> str:
    """Gets the logged in user.

    Fallback to os.getlogin() since getpass on Windows may raise an exception.
    """
    try:
        return getpass.getuser()
    except:
        return os.getlogin()


# These keys are needed by Sponge, as the bazel default `BAZEL_USER` and `BAZEL_HOST` are not supported.
print(f"BUILD_USERNAME {getuser()}")
print(f"BUILD_HOSTNAME {socket.gethostname()}")
build_id = os.getenv("BUILD_NUMBER")
if build_id:
    print(f"ab_build_id {build_id}")
build_target = os.getenv("BUILD_TARGET_NAME")
if build_target:
    print(f"ab_target {build_target}")
