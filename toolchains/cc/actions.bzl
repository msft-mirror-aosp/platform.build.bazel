"""Cc toolchain actions and configs."""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "tool",
    "with_feature_set",
)

C_COMPILE_ACTIONS = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.objc_compile,
]

# C++ actions that directly reads the source
CPP_SOURCE_ACTIONS = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.objcpp_compile,
]

# C++ actions that generate machine code
CPP_CODEGEN_ACTIONS = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_module_codegen,
    ACTION_NAMES.objcpp_compile,
]

CPP_COMPILE_ACTIONS = CPP_SOURCE_ACTIONS + [
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.cpp_module_codegen,
]

# Assembler actions for .s and .S files.
ASSEMBLE_ACTIONS = [
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
]

LINK_ACTIONS = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
    ACTION_NAMES.objc_executable,
    ACTION_NAMES.objc_fully_link,
]

ARCHIVER_ACTIONS = [
    ACTION_NAMES.cpp_link_static_library,
    ACTION_NAMES.objc_archive,
]

def create_action_configs(tool_configs):
    """Creates a list of action configs to specify cc tools to each action.

    Args:
        tool_configs: A list of CcToolInfo providers containing the tool
            configs. Order matters when multiple tool configs specify the same
            applied action - details:
            https://cs.opensource.google/bazel/bazel/+/master:tools/cpp/cc_toolchain_config_lib.bzl?q=symbol:action_config&ss=bazel%2Fbazel

    Returns:
        A list of action configs
    """
    tools_by_action = {}
    for tool_config in tool_configs:
        for action in tool_config.applied_actions:
            tools_by_action.setdefault(action, []).append(tool_config)

    action_configs = []
    for action, tool_configs in tools_by_action.items():
        tools = [tool(
            tool = t.tool,
            with_features = [
                with_feature_set(
                    features = t.with_features,
                    not_features = t.with_no_features,
                ),
            ],
        ) for t in tool_configs]
        action_configs.append(
            action_config(
                action_name = action,
                enabled = True,
                tools = tools,
            ),
        )

    return action_configs
