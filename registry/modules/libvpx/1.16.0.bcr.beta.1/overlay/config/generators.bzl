"""Helper macros for generating family/variant configuration files for libvpx.

This module provides helper utilities to define configuration targets for
different CPU families (e.g., x86, arm) and compilation variants, outputting
their respective config headers, assembly configs, and CPU feature flags.
"""

load(":vpx_config.bzl", "vpx_config_asm", "vpx_config_c", "vpx_config_header", "vpx_config_rtcd")

_KIND_TO_FILENAME = {
    "asm": "vpx_config.asm",
    "h": "vpx_config.h",
    "rtcd": "vpx_config.rtcd",
    "c": "vpx_config.c",
}

def config_output_dir(family, variant = "default"):
    """Returns the generated subdirectory path for a specific family and variant configuration.

    Args:
        family: The CPU family/architecture directory name (e.g., arm64, x86_64).
        variant: The variation name (e.g., default, highbitdepth).
    """
    return "generated/{}/{}".format(family, variant)

def config_output_file(family, variant, kind):
    """Returns the output file path for a configuration kind (h, asm, or rtcd).

    Args:
        family: The CPU family name.
        variant: The configuration variant name.
        kind: The output type ('h', 'asm', or 'rtcd').
    """
    return "{}/{}".format(config_output_dir(family, variant), _KIND_TO_FILENAME[kind])

def select_config_outputs(family, kind, variants_by_condition):
    """Builds a Bazel select() mapping to resolve config output files based on target constraints.

    Args:
        family: The target CPU family.
        kind: The configuration file type ('h', 'asm', or 'rtcd').
        variants_by_condition: Dict mapping select conditions to variant names.
    """
    return select({
        condition: [config_output_file(family, variant, kind)]
        for condition, variant in variants_by_condition.items()
    })

def select_config_dirs(family, variants_by_condition):
    """Builds a Bazel select() mapping to resolve the config output directories based on constraints.

    Args:
        family: The target CPU family.
        variants_by_condition: Dict mapping select conditions to variant names.
    """
    return select({
        condition: [config_output_dir(family, variant)]
        for condition, variant in variants_by_condition.items()
    })

def _emit_variant_config_targets(family, arch, variant, features = {}, windows = False, emit_asm = True):
    """Declares target generators (vpx_config_header, vpx_config_asm, vpx_config_rtcd) for a single variant.

    Args:
        family: The target CPU family directory.
        arch: The architecture value.
        variant: The variant configuration name.
        features: Dictionary of enabled config settings and CPU feature options.
        windows: Bool specifying if compilation targets Windows.
        emit_asm: Bool specifying whether to emit assembly-level vpx_config.asm files.
    """
    name_prefix = "gen_{}_{}".format(family, variant)

    vpx_config_header(
        name = "{}_h".format(name_prefix),
        arch = arch,
        out = config_output_file(family, variant, "h"),
        features = features,
        windows = windows,
    )

    if emit_asm:
        vpx_config_asm(
            name = "{}_asm".format(name_prefix),
            arch = arch,
            out = config_output_file(family, variant, "asm"),
            features = features,
            windows = windows,
        )

    vpx_config_rtcd(
        name = "{}_rtcd".format(name_prefix),
        arch = arch,
        out = config_output_file(family, variant, "rtcd"),
        features = features,
        windows = windows,
    )

    vpx_config_c(
        name = "{}_c".format(name_prefix),
        arch = arch,
        out = config_output_file(family, variant, "c"),
        features = features,
        windows = windows,
    )

def emit_config_family_targets(family, arch, variants):
    """Iterates and emits the build targets for all variants under a given family.

    Args:
        family: The CPU family name.
        arch: The architecture target configuration.
        variants: A list of dict configurations specifying variant properties.
    """
    for variant in variants:
        _emit_variant_config_targets(
            family = family,
            arch = arch,
            variant = variant["name"],
            features = variant.get("features", {}),
            windows = variant.get("windows", False),
            emit_asm = variant.get("emit_asm", True),
        )
