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

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//build/bazel/rules:gensrcs.bzl", "gensrcs")

SRCS = [
    "texts/src1.txt",
    "texts/src2.txt",
    "src3.txt",
]

OUTPUT_EXTENSION = "out"

EXPECTED_OUTS = [
    "texts/src1.out",
    "texts/src2.out",
    "src3.out",
]

# ==== Check the actions created by gensrcs ====

def _test_actions_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)

    # Expect an action for each pair of input/output file
    asserts.equals(env, expected = len(SRCS), actual = len(actions))

    asserts.set_equals(
        env,
        sets.make([
            # given an input file build/bazel/rules/texts/src1.txt
            # the corresponding output file is
            # <GENDIR>/build/bazel/rules/build/bazel/rules/texts/src1.out
            # the second "build/bazel/rules" is to accomodate the srcs from
            # external package
            paths.join(
                ctx.genfiles_dir.path,
                "build/bazel/rules",
                "build/bazel/rules",
                out,
            )
            for out in EXPECTED_OUTS
        ]),
        sets.make([file.path for file in target.files.to_list()]),
    )

    return analysistest.end(env)

actions_test = analysistest.make(_test_actions_impl)

def _test_actions():
    name = "gensrcs_output_paths"
    test_name = name + "_test"

    # Rule under test
    gensrcs(
        name = name,
        cmd = "cat $(SRC) > $(OUT)",
        srcs = SRCS,
        output_extension = OUTPUT_EXTENSION,
        tags = ["manual"],  # make sure it's not built using `:all`
    )

    actions_test(
        name = test_name,
        target_under_test = name,
    )
    return test_name

# ==== Check the output file when out_extension is unset ====

def _test_unset_output_extension_impl(ctx):
    env = analysistest.begin(ctx)

    actions = analysistest.target_actions(env)
    asserts.equals(env, expected = 1, actual = len(actions))
    action = actions[0]
    asserts.equals(
        env,
        expected = "input.",
        actual = action.outputs.to_list()[0].basename,
    )

    return analysistest.end(env)

unset_output_extension_test = analysistest.make(_test_unset_output_extension_impl)

def _test_unset_output_extension():
    name = "unset_output_extension"
    test_name = name + "_test"

    # Rule under test
    gensrcs(
        name = "TSTSS",
        cmd = "cat $(SRC) > $(OUT)",
        srcs = ["input.txt"],
        tags = ["manual"],  # make sure it's not built using `:all`
    )

    unset_output_extension_test(
        name = test_name,
        target_under_test = "TSTSS",
    )
    return test_name

TOOL_FILE_NAME = "out.sh"

def _test_gensrcs_tool_builds_for_host_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(env, expected = 1, actual = len(actions), msg = "expected actions")

    action = actions[0]
    inputs = action.inputs.to_list()
    asserts.equals(env, expected = 2, actual = len(inputs), msg = "expected inputs")

    input_map = {}
    for i in inputs:
        input_map[i.basename] = i
    tool = input_map[TOOL_FILE_NAME]
    asserts.true(
        env,
        # because we set --experimental_platform_in_output_dir, we expect the
        # platform to be in the output path of a generated file
        "darwin" in tool.path,  # host platform
        "expected 'darwin' in tool path, got '%s'" % tool.path,
    )

    outputs = action.outputs.to_list()
    asserts.equals(env, expected = 1, actual = len(outputs), msg = "expected outputs %s" % outputs)
    output = outputs[0]
    asserts.true(
        env,
        # because we set --experimental_platform_in_output_dir, we expect the
        # platform to be in the output path of a generated file
        "android_x86" in output.path,  # target platform
        "expected 'android_x86' in output path, got '%s'" % output.path,
    )

    return analysistest.end(env)

_gensrcs_tool_builds_for_host_test = analysistest.make(
    _test_gensrcs_tool_builds_for_host_impl,
    config_settings = {
        "//command_line_option:platforms": "@//build/bazel/platforms:android_x86",  # ensure target != host so there is a transition
        "//command_line_option:host_platform": "@//build/bazel/platforms:darwin_x86_64",  # ensure target != host so there is a transition
    },
)

def _test_gensrcs_tool_builds_for_host():
    native.genrule(
        name = "gensrcs_test_bin",
        outs = [TOOL_FILE_NAME],
        executable = True,
        cmd = "touch $@",
        target_compatible_with = select({
            # only supported OS is that specified as host_platform
            "//build/bazel/platforms/os:darwin": [],
            "//conditions:default": ["@platforms//:incompatible"],
        }),
        tags = ["manual"],
    )

    gensrcs(
        name = "gensrcs_test_tool_builds_for_host",
        tools = [":gensrcs_test_bin"],
        srcs = ["input.txt"],
        output_extension = OUTPUT_EXTENSION,
        cmd = "",
        tags = ["manual"],
    )

    test_name = "gensrcs_tools_build_for_host_test"
    _gensrcs_tool_builds_for_host_test(
        name = test_name,
        target_under_test = ":gensrcs_test_tool_builds_for_host",
    )
    return test_name

def gensrcs_tests_suite(name):
    """Creates test targets for gensrcs.bzl"""
    native.test_suite(
        name = name,
        tests = [
            _test_actions(),
            _test_unset_output_extension(),
            _test_gensrcs_tool_builds_for_host(),
        ],
    )
