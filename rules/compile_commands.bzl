# Copyright 2025 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the',  help='License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an',  help='AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Provides a rule to create a compile_commands.json database for clangd."""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

# --- Constants ---

_HEADER_EXTS = (".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".H")
_SRC_EXTS = [".c", ".cc", ".cpp", ".cxx", ".c++", ".C"] + list(_HEADER_EXTS)

_UNSUPPORTED_FLAGS = [
    "-fno-canonical-system-headers",
    "-fstack-usage",
    "-fdebug-prefix-map={BAZEL_EXECUTION_ROOT}=.",  # Mac thingie
    "-fstack-protector-strong",
    "-fcolor-diagnostics",
]

CompileCommandsInfo = provider(
    doc = "Propagates compile command json snippets up the graph",
    fields = {"files": "A depset of json files"},
)

# --- Action Helpers ---

def _emit_combine_action(ctx, action_tool, inputs, output_file):
    """Generates the action to combine multiple JSON snippets."""
    inputs_file = ctx.actions.declare_file(output_file.path + ".inputs")
    ctx.actions.write(inputs_file, "\n".join([f.path for f in inputs]))

    args = ctx.actions.args()
    args.add("combine")
    args.add("--output_file", output_file.path)
    args.add("--inputs_file", inputs_file.path)

    # Our tool is going to stich together individual json snippets.
    ctx.actions.run(
        inputs = inputs + [inputs_file],
        outputs = [output_file],
        executable = action_tool,
        arguments = [args],
        mnemonic = "CCJsonCombine",
        use_default_shell_env = True,
        progress_message = "Merging compile commands: {}".format(output_file.short_path),
    )

def _emit_generate_action(ctx, action_tool, infile, flags, toolchain_files, additional_files, discriminator):
    """Generates the action to create a single JSON snippet."""

    # So for every compile action we are going to create a single compile_commands .json entry
    # We write this to disk and will later stitch them back together, this also makes sure
    # we create this nice dependency graph of snippets.
    outfile = ctx.actions.declare_file(
        "bazel_compile_commands_{}.{}.json".format(infile.path, discriminator),
    )
    flags_file = ctx.actions.declare_file(
        "bazel_compile_commands_{}.{}.flags".format(infile.path, discriminator),
    )
    ctx.actions.write(flags_file, "\n".join(flags))

    inputs = depset(
        direct = [infile, flags_file],
        transitive = [additional_files, toolchain_files],
    )

    args = ctx.actions.args()
    args.add("generate")
    args.add("--output_file", outfile.path)
    args.add("--input_file", infile)
    args.add("--flags_file", flags_file.path)

    ctx.actions.run(
        inputs = inputs,
        outputs = [outfile],
        executable = action_tool,
        arguments = [args],
        mnemonic = "CCJsonGenerate",
        use_default_shell_env = True,
        progress_message = "Generating compile commands: {}".format(infile.short_path),
    )
    return outfile

# --- Analysis Helpers ---

def _get_sources(attr):
    """Extracts valid source files from srcs and hdrs attributes."""
    srcs = []

    def _is_valid(f):
        return f.is_source and any([f.basename.endswith(ext) for ext in _SRC_EXTS])

    # Iterate over both attributes generically
    for attr_name in ["srcs", "hdrs"]:
        if hasattr(attr, attr_name):
            val = getattr(attr, attr_name)
            for target in val:
                srcs.extend([f for f in target.files.to_list() if _is_valid(f)])

    # Let's throw out the header files for now.
    return [src for src in srcs if not src.basename.endswith(_HEADER_EXTS)]

def _get_toolchain_flags(ctx, cc_toolchain, action_name = ACTION_NAMES.cpp_compile):
    feature_config = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    # Merge user flags (copts, cxxopts, conlyopts)
    user_flags = list(ctx.fragments.cpp.copts)
    if action_name == ACTION_NAMES.cpp_compile:
        user_flags.extend(ctx.fragments.cpp.cxxopts)
    elif action_name == ACTION_NAMES.c_compile and hasattr(ctx.fragments.cpp, "conlyopts"):
        user_flags.extend(ctx.fragments.cpp.conlyopts)

    compile_vars = cc_common.create_compile_variables(
        feature_configuration = feature_config,
        cc_toolchain = cc_toolchain,
        user_compile_flags = user_flags,
    )

    tool_path = cc_common.get_tool_for_action(
        feature_configuration = feature_config,
        action_name = action_name,
    )

    # Check environment for wrapper overrides (Mac/Windows hacks)
    # because in mac land we are using a wrapper, so not the real
    # clang, which will confuse clangd.
    tool_env = cc_common.get_environment_variables(
        feature_configuration = feature_config,
        action_name = action_name,
        variables = cc_common.create_compile_variables(
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_config,
        ),
    )

    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_config,
        action_name = action_name,
        variables = compile_vars,
    )

    # For mac this WRAPPER_WRAP_BINARY will be the "real clang
    cc = tool_env.get("WRAPPER_WRAP_BINARY", tool_path)
    return [cc] + flags

def _get_deps_flags(deps):
    """Extracts include paths and defines from dependencies."""
    compilation_contexts = [dep[CcInfo].compilation_context for dep in deps]

    additional_files = depset(transitive = [
        cc.headers
        for cc in compilation_contexts
    ])

    flags = []
    for cc in compilation_contexts:
        # Defines
        flags.extend(["-D" + d for d in cc.defines.to_list()])
        flags.extend(["-D" + d for d in cc.local_defines.to_list()])

        # Includes
        flags.extend(["-F" + i for i in cc.framework_includes.to_list()])
        flags.extend(["-I" + i for i in cc.includes.to_list()])

        # And the others.
        for i in cc.quote_includes.to_list():
            flags.extend(["-iquote", i])
        for i in cc.system_includes.to_list():
            flags.extend(["-isystem", i])
        for i in cc.external_includes.to_list():
            flags.extend(["-isystem", i])

    return flags, additional_files

def _filter_safe_flags(flags):
    """Throw out flags we don't care about."""
    return [f for f in flags if f not in _UNSUPPORTED_FLAGS]

def _is_c_source(src):
    return src.extension == "c"

# --- Implementations ---

def _compile_commands_aspect_impl(target, ctx):
    # 1. Collect Transitive State
    transitive_files = []

    # These are all the things we are willing to descend down..
    attr_aspects_to_check = ["deps", "implementation_deps", "srcs", "data"]

    for attr_name in attr_aspects_to_check:
        if hasattr(ctx.rule.attr, attr_name):
            val = getattr(ctx.rule.attr, attr_name)
            if type(val) == "list":
                for dep in val:
                    # Safety check: we only care if the dependency actually HAS our provider
                    # This safely ignores raw source files (.cpp etc) inside 'srcs'
                    if CompileCommandsInfo in dep:
                        transitive_files.append(dep[CompileCommandsInfo].files)

    # If not C++, return deps only
    if CcInfo not in target:
        return [CompileCommandsInfo(files = depset(transitive = transitive_files))]

    # 2. Generate Flags
    action_tool = ctx.attr._generator.files_to_run
    deps = [target] + getattr(ctx.rule.attr, "implementation_deps", [])

    dep_flags, additional_files = _get_deps_flags(deps)

    # Expand make variables in copts
    copts = ctx.rule.attr.copts if hasattr(ctx.rule.attr, "copts") else []
    expanded_copts = [ctx.expand_make_variables("copts", copt, {}) for copt in copts]

    combined_flags = dep_flags + expanded_copts

    cc_toolchain = find_cpp_toolchain(ctx)
    c_flags = _filter_safe_flags(_get_toolchain_flags(ctx, cc_toolchain, ACTION_NAMES.c_compile) + combined_flags)
    cxx_flags = _filter_safe_flags(_get_toolchain_flags(ctx, cc_toolchain, ACTION_NAMES.cpp_compile) + combined_flags)

    # 3. Generate Snippets
    srcs = _get_sources(ctx.rule.attr)
    snippet_outputs = []

    for src in srcs:
        flags = c_flags if _is_c_source(src) else cxx_flags
        snippet_outputs.append(
            _emit_generate_action(
                ctx,
                action_tool,
                src,
                flags,
                cc_toolchain.all_files,
                additional_files,
                target.label.name,
            ),
        )

    # 4. Combine current target snippets (Intermediate Step) to a small compiler_commands.json
    # this is a valid snippet, but likely only for a cc_library/cc_binary
    target_combined_file = ctx.actions.declare_file("bazel_compile_commands_{}.json".format(target.label.name))
    _emit_combine_action(ctx, action_tool, snippet_outputs, target_combined_file)

    # 5. Merge with Transitive, we have to collect them all!
    all_json_files = depset(
        direct = [target_combined_file],
        transitive = transitive_files,
    )

    return [
        OutputGroupInfo(report = all_json_files),
        CompileCommandsInfo(files = all_json_files),
    ]

def _is_windows(ctx):
    # HACK ATTACK!
    # If the host path separator is ';', we are running on Windows.
    return ctx.configuration.host_path_separator == ";"

def _compile_commands_rule_impl(ctx):
    # 1. Collect inputs and filter the ones we don't care about
    all_inputs = []
    for target in ctx.attr.targets:
        if CompileCommandsInfo in target:
            all_inputs.append(target[CompileCommandsInfo].files)

    raw_depset = depset(transitive = all_inputs)
    filtered_inputs = []

    # Let's remove all the external dependencies we don't care about.
    # we are not going to develop @abseil-cpp, @grpc etc..
    # (Unless the user specifically requests it)
    allowed_external = ctx.attr.allow_external_workspaces
    for f in raw_depset.to_list():
        ws_name = f.owner.workspace_name
        if ws_name == "" or ws_name in allowed_external:
            filtered_inputs.append(f)

    # 3. Final Merge Action, we now have all our individual actions
    # that in theory can compile a file.
    outfile = ctx.actions.declare_file("compile_commands.json")
    _emit_combine_action(ctx, ctx.executable._generator, filtered_inputs, outfile)

    # 4. Generate Simple Launcher Script
    # We just invoke the python tool with the 'install' command.
    runner_script = ctx.actions.declare_file(ctx.label.name + ("_update.bat" if _is_windows(ctx) else "_update.sh"))

    if _is_windows(ctx):
        # Windows Batch Stub
        content = """@echo off
"{tool}" install --input_file "{json}"
""".format(
            tool = ctx.executable._generator.short_path.replace("/", "\\"),
            json = outfile.short_path.replace("/", "\\"),
        )
    else:
        # POSIX Shell Stub
        content = """#!/bin/bash
# We use $0.runfiles to find the tool relative to this script
ROOT="$0.runfiles/{workspace}"
exec "$ROOT/{tool}" install --input_file "$ROOT/{json}"
""".format(
            workspace = ctx.workspace_name,
            tool = ctx.executable._generator.short_path,
            json = outfile.short_path,
        )

    ctx.actions.write(runner_script, content, is_executable = True)

    return [
        DefaultInfo(
            files = depset([outfile]),
            executable = runner_script,
            # IMPORTANT: We must include both the JSON *and* the tool in runfiles
            runfiles = ctx.runfiles(files = [outfile]).merge(
                ctx.attr._generator[DefaultInfo].default_runfiles,
            ),
        ),
    ]

# --- Rules ---

compile_commands_aspect = aspect(
    implementation = _compile_commands_aspect_impl,
    fragments = ["cpp"],
    attr_aspects = ["implementation_deps", "deps", "srcs", "data"],
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_generator": attr.label(default = Label("//utils:gen-cc-snippet")),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

compile_commands_json = rule(
    implementation = _compile_commands_rule_impl,
    doc = """
Generates a `compile_commands.json` database for Clang tooling (clangd, VSCode, etc.).

This rule aggregates compilation actions from the transitive closure of the specified
`targets`. It automatically filters out external dependencies (e.g., @bazel_tools,
@com_google_absl) to keep the database size manageable and IDE performance high.

If you need to edit sources in an external repository (e.g., a vendored library or
a co-developed workspace), add its workspace name to `allow_external_workspaces`.

Example Usage:

    ```python
    compile_commands_json(
        name = "compile_commands",
        targets = [
            "//my/project:server",
            "//my/project:client",
            "//my/project:tests",
        ],
        # Optional: Include specific external repos in the output
        allow_external_workspaces = [
            "gfxstream+",
            "aemu+",
        ],
    )
    ```

Run `bazel build //:compile_commands` to generate the file.

Note: This tool is best effort, it might not find all the header deps, but it is doing pretty well.
""",
    executable = True,
    attrs = {
        "targets": attr.label_list(
            aspects = [compile_commands_aspect],
            doc = "The list of top-level targets to generate commands for.",
        ),
        "allow_external_workspaces": attr.string_list(
            doc = "List of external workspace names (e.g., 'aemu') to include. The main workspace is always included.",
        ),
        "_generator": attr.label(
            default = Label("//utils:gen-cc-snippet"),
            executable = True,
            cfg = "exec",
        ),
    },
)
