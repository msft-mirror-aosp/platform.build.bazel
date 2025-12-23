load("@bazel_skylib//rules:common_settings.bzl", "bool_flag", "string_flag")

string_flag(
    name = "generate_debug_package",
    build_setting_default = "none",
    values = [
        "none",
        "gnu",
        "dsym",
        "pdb",
    ],
)

bool_flag(
    name = "allow_strip",
    build_setting_default = False,
)
