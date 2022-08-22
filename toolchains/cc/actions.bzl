"""Cc toolchain actions and configs."""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "tool",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

C_COMPILE_ACTIONS = [
    ACTION_NAMES.c_compile,
]

# C++ actions that directly reads the source
CPP_SOURCE_ACTIONS = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
]

# C++ actions that generate machine code
CPP_CODEGEN_ACTIONS = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_module_codegen,
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
]

ARCHIVER_ACTIONS = [
    ACTION_NAMES.cpp_link_static_library,
]

def create_action_tool_configs(cc_tools):
    """Creates a list of action configs to specify cc tools to each action.

    Args:
        cc_tools: A CcToolsInfo provider containing the tool configs.

    Returns:
        A list of action configs
    """
    action_configs = []

    for action_name in C_COMPILE_ACTIONS + ASSEMBLE_ACTIONS:
        action_configs.append(
            action_config(
                action_name = action_name,
                tools = [tool(tool = cc_tools.gcc)],
                enabled = True,
                implies = cc_tools.gcc_features,
            ),
        )
    for action_name in CPP_COMPILE_ACTIONS:
        action_configs.append(
            action_config(
                action_name = action_name,
                tools = [tool(tool = cc_tools.cxx)],
                enabled = True,
                implies = cc_tools.cxx_features,
            ),
        )
    for action_name in LINK_ACTIONS:
        action_configs.append(
            action_config(
                action_name = action_name,
                tools = [tool(tool = cc_tools.ld)],
                enabled = True,
                implies = cc_tools.ld_features,
            ),
        )
    for action_name in ARCHIVER_ACTIONS:
        action_configs.append(
            action_config(
                action_name = action_name,
                tools = [tool(tool = cc_tools.ar)],
                enabled = True,
                implies = cc_tools.ar_features,
            ),
        )
    action_configs.append(
        action_config(
            action_name = ACTION_NAMES.strip,
            tools = [tool(tool = cc_tools.strip)],
            enabled = True,
            implies = cc_tools.strip_features,
        ),
    )

    return action_configs
