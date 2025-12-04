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

ClangTidyInfo = provider(
    doc = "Propagates clang-tidy results up the graph",
    fields = {
        "warnings": "A depset of files containing tidy warnings.",
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

    warnings_file = ctx.actions.declare_file(src.path + "." + ctx.label.name + ".tidy.txt")
    fixes_file = ctx.actions.declare_file(src.path + "." + ctx.label.name + ".tidy.yaml")

    args = ctx.actions.args()
    args.add("generate")
    args.add("--tidy-exe", clang_tidy_exec)
    args.add("--config-file", clang_tidy_config)
    args.add("--warnings_file", warnings_file.path)
    args.add("--export-fixes", fixes_file.path)
    args.add("--source", src.path)

    regex = ctx.attr._clang_tidy_regex[TidyRegexProviderInfo].regex
    if regex:
        args.add("--re", regex)

    args.add("--")
    args.add_all(flags)

    inputs = depset([src, clang_tidy_exec], transitive = [additional_files, cc_toolchain.all_files])
    if clang_tidy_config:
        inputs = depset([clang_tidy_config], transitive = [inputs])

    ctx.actions.run(
        inputs = inputs,
        executable = action_tool,
        arguments = [args],
        outputs = [warnings_file, fixes_file],
        mnemonic = "ClangTidy",
        use_default_shell_env = True,
        progress_message = "Running clang-tidy on {}".format(src.short_path),
    )

    return warnings_file, fixes_file

# --- Implementations ---

def _clang_tidy_aspect_impl(target, ctx):
    # 1. Collect Transitive State
    transitive_warnings = []
    transitive_fixes = []
    attr_aspects_to_check = ["deps", "implementation_deps", "srcs", "data"]
    for attr_name in attr_aspects_to_check:
        if hasattr(ctx.rule.attr, attr_name):
            val = getattr(ctx.rule.attr, attr_name)
            if type(val) == "list":
                for dep in val:
                    if ClangTidyInfo in dep:
                        transitive_warnings.append(dep[ClangTidyInfo].warnings)
                        transitive_fixes.append(dep[ClangTidyInfo].fixes)

    # If not C++, return deps only
    if CcInfo not in target:
        return [ClangTidyInfo(
            warnings = depset(transitive = transitive_warnings),
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

    warning_files = []
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
                warnings, fixes = _emit_tidy_action(
                    ctx,
                    action_tool,
                    src,
                    flags,
                    cc_toolchain,
                    additional_files,
                    clang_tidy_config,
                )
                warning_files.append(warnings)
                fix_files.append(fixes)

    # 5. Merge with Transitive
    all_warnings = depset(direct = warning_files, transitive = transitive_warnings)
    all_fixes = depset(direct = fix_files, transitive = transitive_fixes)

    return [
        OutputGroupInfo(tidy_warnings = all_warnings, tidy_fixes = all_fixes),
        ClangTidyInfo(warnings = all_warnings, fixes = all_fixes),
    ]

def _clang_tidy_rule_impl(ctx):
    # Collect inputs from the aspect
    all_warnings = []
    all_fixes = []
    for target in ctx.attr.targets:
        if ClangTidyInfo in target:
            all_warnings.append(target[ClangTidyInfo].warnings)
            all_fixes.append(target[ClangTidyInfo].fixes)

    warnings_depset = depset(transitive = all_warnings)
    fixes_depset = depset(transitive = all_fixes)

    # Filter out external repositories we don't care about.
    allowed_external = ctx.attr.allow_external_workspaces
    filtered_warnings = [f for f in warnings_depset.to_list() if f.owner.workspace_name == "" or f.owner.workspace_name in allowed_external]
    filtered_fixes = [f for f in fixes_depset.to_list() if f.owner.workspace_name == "" or f.owner.workspace_name in allowed_external]

    # Combine warning files into a single file
    combined_warnings_file = ctx.actions.declare_file(ctx.label.name + "_warnings.txt")

    input_paths = [f.path for f in filtered_warnings]
    if input_paths:
        action_tool = ctx.attr._run_tidy.files_to_run
        args = ctx.actions.args()
        args.add("combine")
        args.add("--output_file", combined_warnings_file.path)
        args.add_all(input_paths)

        ctx.actions.run(
            inputs = filtered_warnings,
            executable = action_tool,
            arguments = [args],
            outputs = [combined_warnings_file],
            mnemonic = "ClangTidyCombine",
            use_default_shell_env = True,
            progress_message = "Combining clang-tidy warnings",
        )
    else:
        # Create an empty file if there are no warnings
        ctx.actions.write(output = combined_warnings_file, content = "")

    # For fixes, we just provide all the YAML files.
    return [
        DefaultInfo(
            files = depset([combined_warnings_file], transitive = [depset(filtered_fixes)]),
        ),
    ]

# --- Rules ---

clang_tidy_aspect = aspect(
    implementation = _clang_tidy_aspect_impl,
    fragments = ["cpp"],
    attr_aspects = ["implementation_deps", "deps", "srcs", "data"],
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_run_tidy": attr.label(default = Label("//:run-clang-tidy")),
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

clang_tidy = rule(
    implementation = _clang_tidy_rule_impl,
    doc = "Runs clang-tidy on a set of targets and collects the warnings and suggested fixes.",
    attrs = {
        "targets": attr.label_list(
            aspects = [
                clang_tidy_aspect,
            ],
            doc = "The list of top-level targets to run clang-tidy on.",
        ),
        "allow_external_workspaces": attr.string_list(
            doc = "List of external workspace names (e.g., 'aemu') to include. The main workspace is always included.",
        ),
        "clang_tidy_config": attr.label(
            doc = "The .clang-tidy configuration file to use.",
            allow_single_file = True,
        ),
    },
)
