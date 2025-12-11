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
"""Provides a rule to run clang-tidy on a set of targets."""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

TidySourceProviderInfo = provider(
    "a set of source files that we can provide to clang-tidy so we 'only' check specific set of files.",
    fields = ["srcs"],
)

def _tidy_source_flag_impl(ctx):
    return TidySourceProviderInfo(srcs = ctx.build_setting_value)

tidy_source_flag = rule(
    implementation = _tidy_source_flag_impl,
    build_setting = config.string(flag = True, allow_multiple = True),
)

TidyRegexProviderInfo = provider(
    "a set of sed style regexes to apply",
    fields = ["regex"],
)

def _tidy_regex_flag_impl(ctx):
    return TidyRegexProviderInfo(regex = ctx.build_setting_value)

tidy_regex_flag = rule(
    implementation = _tidy_regex_flag_impl,
    build_setting = config.string(flag = True, allow_multiple = False),
)

# So an aspect rule operates on the build graph
# and it needs all the attributes used for operation
# of the rule to be available before it starts executing
# this in turn means that if you have a rule that is running
# you cannot modify/or set the parameters used by the aspect
# rule.

# To work around this bazel has this notion of a transition
# which basically allows us to replace the "contents" of an existing
# label with the "contents" that the label of our rule is pointing
# to.

def _tidy_report_transition_impl(_settings, attr):
    outputs = {
        "//:clang_tidy_regex": attr.rewrite_sed_pattern if attr.rewrite_sed_pattern else "",
    }

    if attr.tidy_config_file:
        # the label //:clang_tidy_config now has the value
        # for our attribute, overwriting the existing one.
        outputs["//:clang_tidy_config"] = attr.tidy_config_file

    if attr.source_path_substrings:
        outputs["//:clang_tidy_check_files"] = attr.source_path_substrings

    return outputs

tidy_report_transition = transition(
    implementation = _tidy_report_transition_impl,
    inputs = [],
    outputs = [
        "//:clang_tidy_config",
        "//:clang_tidy_check_files",
        "//:clang_tidy_regex",
    ],
)

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

def _is_windows(ctx):
    # HACK ATTACK!
    # If the host path separator is ';', we are running on Windows.
    return ctx.configuration.host_path_separator == ";"

ClangTidyInfo = provider(
    doc = "Propagates clang-tidy results up the graph",
    fields = {
        "fixes": "A depset of yaml files containing fixes.",
    },
)

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
            # Note, technically these should be -isystem, but then clang-tidy will ignore them
            # unless we start checking system headers, which is just noise!
            # So we go for -I (-iquote would force #include "my.h" and not allow #include <my.h>)
            flags.extend(["-I", i])
        for i in cc.external_includes.to_list():
            flags.extend(["-isystem", i])

    return flags, additional_files

def _filter_safe_flags(flags):
    """Throw out flags we don't care about."""
    return [f for f in flags if f not in _UNSUPPORTED_FLAGS]

def _is_c_source(src):
    return src.extension == "c"

# --- Action Helpers ---

def _emit_tidy_action(ctx, action_tool, src, flags, cc_toolchain, additional_files, clang_tidy_config = None):
    """Generates the action to run clang-tidy on a single source file."""
    clang_tidy_exec = None
    for f in cc_toolchain.all_files.to_list():
        if f.basename == "clang-tidy" or f.basename == "clang-tidy.exe":
            clang_tidy_exec = f
            break

    if not clang_tidy_exec:
        fail("Could not find clang-tidy executable in the toolchain {}".format(cc_toolchain.label))

    fixes_file = ctx.actions.declare_file(src.path + "." + ctx.label.name + ".tidy.yaml")

    args = ctx.actions.args()
    args.add("generate")
    args.add("--clang-tidy-exe", clang_tidy_exec)
    args.add("--config-file", clang_tidy_config)
    args.add("--fixes-file", fixes_file.path)
    args.add("--source-file", src.path)

    regex = ctx.attr._clang_tidy_regex[TidyRegexProviderInfo].regex
    if regex:
        args.add("--rewrite-rules", regex)

    args.add("--")
    args.add_all(flags)

    inputs = depset([src, clang_tidy_exec], transitive = [additional_files, cc_toolchain.all_files])
    if clang_tidy_config:
        inputs = depset([clang_tidy_config], transitive = [inputs])

    ctx.actions.run(
        inputs = inputs,
        executable = action_tool,
        arguments = [args],
        outputs = [fixes_file],
        mnemonic = "ClangTidy",
        use_default_shell_env = True,
        progress_message = "Running clang-tidy on {}".format(src.short_path),
    )

    return fixes_file

# --- Implementations ---

def _clang_tidy_aspect_impl(target, ctx):
    # 1. Collect Transitive State
    transitive_fixes = []
    attr_aspects_to_check = ["deps", "implementation_deps", "srcs", "data"]
    for attr_name in attr_aspects_to_check:
        if hasattr(ctx.rule.attr, attr_name):
            val = getattr(ctx.rule.attr, attr_name)
            if type(val) == "list":
                for dep in val:
                    if ClangTidyInfo in dep:
                        transitive_fixes.append(dep[ClangTidyInfo].fixes)

    # If not C++, return deps only
    if CcInfo not in target:
        return [ClangTidyInfo(
            fixes = depset(transitive = transitive_fixes),
        )]

    # 2. Generate Flags
    deps = [target] + getattr(ctx.rule.attr, "implementation_deps", [])
    dep_flags, additional_files = _get_deps_flags(deps)

    copts = ctx.rule.attr.copts if hasattr(ctx.rule.attr, "copts") else []
    expanded_copts = [ctx.expand_make_variables("copts", copt, {}) for copt in copts]

    combined_flags = dep_flags + expanded_copts

    cc_toolchain = find_cpp_toolchain(ctx)
    c_flags = _filter_safe_flags(_get_toolchain_flags(ctx, cc_toolchain, ACTION_NAMES.c_compile) + combined_flags)
    cxx_flags = _filter_safe_flags(_get_toolchain_flags(ctx, cc_toolchain, ACTION_NAMES.cpp_compile) + combined_flags)

    # 3. Generate tidy actions for each source file
    srcs = _get_sources(ctx.rule.attr)

    fix_files = []

    clang_tidy_config = ctx.file._clang_tidy_config
    action_tool = ctx.attr._run_tidy.files_to_run

    check_src = ctx.attr._clang_tidy_check_files[TidySourceProviderInfo].srcs

    # 4. Users need to explicitly specify the sources they want to chec
    # note that we do "fuzzy" matching using "str" in "path", this is
    # likely good enough for our use case.
    for src in srcs:
        for c in check_src:
            if c in src.path:
                flags = c_flags if _is_c_source(src) else cxx_flags
                fixes = _emit_tidy_action(
                    ctx,
                    action_tool,
                    src,
                    flags,
                    cc_toolchain,
                    additional_files,
                    clang_tidy_config,
                )
                fix_files.append(fixes)

    all_fixes = depset(direct = fix_files, transitive = transitive_fixes)
    return [
        OutputGroupInfo(tidy_fixes = all_fixes),
        ClangTidyInfo(fixes = all_fixes),
    ]

def _clang_tidy_report_impl(ctx):
    transitive_fix_depsets = []
    for target in ctx.attr.targets:
        if ClangTidyInfo in target:
            transitive_fix_depsets.append(target[ClangTidyInfo].fixes)

    all_fixes_depset = depset(transitive = transitive_fix_depsets)

    all_fixes = all_fixes_depset.to_list()
    combine_tool = ctx.executable._run_tidy

    # --- Combine ALL Fixes ---
    final_fixes_file = ctx.actions.declare_file(ctx.label.name + ".final_fixes.yaml")
    if all_fixes:
        args_fixes = ctx.actions.args()
        args_fixes.add("combine-tidy")  # Ensure this matches your tool's command
        args_fixes.add("--output-file", final_fixes_file.path)
        args_fixes.add_all(all_fixes)

        ctx.actions.run(
            inputs = all_fixes,
            executable = combine_tool,
            arguments = [args_fixes],
            outputs = [final_fixes_file],
            mnemonic = "ClangTidyFinalCombineFixes",
            progress_message = "Combining clang-tidy fixes for {} targets".format(len(ctx.attr.targets)),
        )
    else:
        ctx.actions.write(final_fixes_file, "")

    runner_script = ctx.actions.declare_file(ctx.label.name + ("_fix.bat" if _is_windows(ctx) else "_fix.sh"))
    if _is_windows(ctx):
        # Windows Batch Stub
        content = """@echo off
"{tool}" fix --subdir "{location}" "{yaml}"
""".format(
            tool = combine_tool.short_path.replace("/", "\\"),
            yaml = final_fixes_file.short_path.replace("/", "\\"),
            location = ctx.attr.apply_fixes_in.replace("/", "\\"),
        )
    else:
        # POSIX Shell Stub
        content = """#!/bin/bash
# We use $0.runfiles to find the tool relative to this script
ROOT="$0.runfiles/{workspace}"
exec "$ROOT/{tool}" fix --subdir "{location}" "$ROOT/{yaml}"
""".format(
            workspace = ctx.workspace_name,
            tool = combine_tool.short_path,
            yaml = final_fixes_file.short_path,
            location = ctx.attr.apply_fixes_in,
        )

    ctx.actions.write(runner_script, content, is_executable = True)

    return DefaultInfo(
        files = depset(
            [final_fixes_file],
        ),
        executable = runner_script,
        # IMPORTANT: We must include both the YAML *and* the tool in runfiles
        runfiles = ctx.runfiles(files = [final_fixes_file]).merge(
            ctx.attr._run_tidy[DefaultInfo].default_runfiles,
        ),
    )

# --- Rules ---

clang_tidy_aspect = aspect(
    implementation = _clang_tidy_aspect_impl,
    fragments = ["cpp"],
    attr_aspects = ["implementation_deps", "deps", "srcs", "data"],
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_run_tidy": attr.label(default = Label("//utils:run-clang-tidy")),
        "_allow_external_workspaces": attr.string_list(
            doc = "List of external workspace names (e.g., 'aemu') to include. The main workspace is always included.",
            default = [],
        ),
        "_clang_tidy_config": attr.label(
            doc = "The .clang-tidy configuration file to use.",
            allow_single_file = True,
            default = Label("//:clang_tidy_config"),
        ),
        "_clang_tidy_check_files": attr.label(
            doc = "The set of files we want to check. We use a simple x in str match.",
            default = Label("//:clang_tidy_check_files"),
        ),
        "_clang_tidy_regex": attr.label(
            doc = "The set of sed style regexes to apply before applying a rewrite rule.",
            default = Label("//:clang_tidy_regex"),
        ),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

clang_tidy_report = rule(
    implementation = _clang_tidy_report_impl,
    cfg = tidy_report_transition,
    executable = True,
    attrs = {
        "targets": attr.label_list(
            doc = "The list of cc_* targets to be analyzed by clang-tidy.",
            mandatory = True,
            aspects = [clang_tidy_aspect],
        ),
        "source_path_substrings": attr.string_list(
            doc = "A list of strings used to filter which source files to check. A file is checked only if its full path contains one of these substrings. If this list is empty, no files will be checked.",
        ),
        "rewrite_sed_pattern": attr.string(
            doc = "A sed-style regular expression (e.g., 's/old/new/g') applied to the replacement text of each clang-tidy fix. This is useful for performing systematic transformations on the generated code, such as renaming prefixes. The regex is applied before writing the fix to disk.",
            default = "",
        ),
        "apply_fixes_in": attr.string(
            doc = "The working directory, relative to the workspace root, from which to apply clang-tidy fixes. This path is prefixed to the file paths in the generated fixes, ensuring they resolve correctly.",
            default = ".",
        ),
        "tidy_config_file": attr.label(
            doc = "A label pointing to the .clang-tidy configuration file to use.",
            allow_single_file = True,
        ),
        "_run_tidy": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//utils:run-clang-tidy"),
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _clang_tidy_test_impl(ctx):
    """Implementation for the _clang_tidy_test."""
    report_yaml = ctx.file.report_yaml

    if _is_windows(ctx):
        script_name = ctx.label.name + ".bat"

        # Note: We need to use %%~zF to get file size in a batch for loop.
        # The single % is for the format string, the double %% is for batch escaping.
        script_content = """@echo off
setlocal
set YAML_FILE={yaml_path}

if not exist "%YAML_FILE%" (
    echo YAML file not found: %YAML_FILE%
    exit /b 1
)

for %%F in ("%YAML_FILE%") do set FILE_SIZE=%%~zF

if %FILE_SIZE% GTR 16 (
    echo Clang-tidy found issues:
    type "%YAML_FILE%"
    exit /b 1
) else (
    echo No clang-tidy issues found.
    exit /b 0
)
""".format(yaml_path = report_yaml.short_path.replace("/", "\\"))

    else:
        script_name = ctx.label.name + ".sh"
        script_content = """#!/bin/bash
YAML_FILE="{yaml_path}"
if [ ! -f "$YAML_FILE" ]; then
    echo "YAML file not found: $YAML_FILE"
    exit 1
fi
FILE_SIZE=$(wc -l "$YAML_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]].*//')
if [ "$FILE_SIZE" -gt 4 ]; then
    echo "Clang-tidy found issues:"
    cat "$YAML_FILE"
    exit 1
else
    echo "No clang-tidy issues found."
    cat "$YAML_FILE"
    exit 0
fi
""".format(yaml_path = report_yaml.short_path)

    script = ctx.actions.declare_file(script_name)
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    return [DefaultInfo(
        executable = script,
        runfiles = ctx.runfiles(files = [report_yaml]),
    )]

_clang_tidy_test = rule(
    implementation = _clang_tidy_test_impl,
    test = True,
    attrs = {
        "report_yaml": attr.label(
            doc = "The clang-tidy report yaml file.",
            allow_single_file = True,
            mandatory = True,
        ),
    },
)

def clang_tidy_test(
        name,
        targets,
        tidy_config_file,
        **kwargs):
    """A test that fails if clang-tidy finds any issues.

    This rule runs clang-tidy on the given targets and fails the test
    if any diagnostics are reported. It automatically filters sources
    to the repository where the test is defined.

    Args:
        name: The name of the test rule.
        targets: A list of cc_* targets to be analyzed.
        tidy_config_file: The .clang-tidy configuration file to use.
        **kwargs: Additional arguments to pass to the underlying clang_tidy_report rule.
    """
    repo = native.repository_name()
    substrings = []
    apply_fixes_in = ""
    rewrite_sed_pattern = ""
    if repo == "@goldfish+":
        substrings = ["goldfish+"]
        apply_fixes_in = "hardware/generic/goldfish"
        rewrite_sed_pattern = "s/^m_//g"
    elif not repo:
        # For the main repository, no explicit filtering is applied by default.
        pass  # User can still pass source_path_substrings via kwargs if needed.
    else:
        # For other external repositories, use the repository name (without '@') and a trailing slash.
        substrings = [repo.replace("@", "") + "/"]

    report_name = name + "_report"
    clang_tidy_report(
        name = report_name,
        targets = targets,
        tidy_config_file = tidy_config_file,
        source_path_substrings = substrings,
        apply_fixes_in = apply_fixes_in,
        rewrite_sed_pattern = rewrite_sed_pattern,
        testonly = True,
        **kwargs
    )

    _clang_tidy_test(
        name = name,
        report_yaml = report_name,
        testonly = True,
    )
