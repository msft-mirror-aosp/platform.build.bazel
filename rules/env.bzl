"""
Copyright (C) 2022 The Android Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

_CAPTURED_ENV_VARS = [
    "ALLOW_LOCAL_TIDY_TRUE",
    "DEFAULT_TIDY_HEADER_DIRS",
    "TIDY_TIMEOUT",
    "WITH_TIDY",
    "WITH_TIDY_FLAGS",
    "SKIP_ABI_CHECKS",
    "UNSAFE_DISABLE_APEX_ALLOWED_DEPS_CHECK",
    "AUTO_ZERO_INITIALIZE",
    "AUTO_PATTERN_INITIALIZE",
    "AUTO_UNINITIALIZE",
    "USE_CCACHE",
    "LLVM_NEXT",
    "ALLOW_UNKNOWN_WARNING_OPTION",

    # Overrides the version in the apex_manifest.json. The version is unique for
    # each branch (internal, aosp, mainline releases, dessert releases).  This
    # enables modules built on an older branch to be installed against a newer
    # device for development purposes.
    "OVERRIDE_APEX_MANIFEST_DEFAULT_VERSION",
]

_ALLOWED_SPECIAL_CHARACTERS = [
    "/",
    "_",
    "-",
    "'",
    ".",
    " ",
]

# Since we write the env var value literally into a .bzl file, ensure that the string
# does not contain special characters like '"', '\n' and '\'. Use an allowlist approach
# and check that the remaining string is alphanumeric.
def _validate_env_value(env_var, env_value):
    sanitized_env_value = env_value
    for allowed_char in _ALLOWED_SPECIAL_CHARACTERS:
        sanitized_env_value = sanitized_env_value.replace(allowed_char, "")
    if not sanitized_env_value.isalnum():
        fail("The value of " +
             env_var +
             " can only consist of alphanumeric and " +
             str(_ALLOWED_SPECIAL_CHARACTERS) +
             " characters: " +
             str(env_value))

def _env_impl(rctx):
    captured_env = {}
    for var in _CAPTURED_ENV_VARS:
        value = rctx.os.environ.get(var)
        if value != None:
            _validate_env_value(var, value)
            captured_env[var] = value

    rctx.file("BUILD.bazel", """
exports_files(["env.bzl"])
""")

    rctx.file("env.bzl", """
env = {
    %s
}
""" % "\n    ".join([
        '"%s": "%s",' % (var, value)
        for var, value in captured_env.items()
    ]))

env_repository = repository_rule(
    implementation = _env_impl,
    configure = True,
    local = True,
    environ = _CAPTURED_ENV_VARS,
    doc = "A repository rule to capture environment variables.",
)
