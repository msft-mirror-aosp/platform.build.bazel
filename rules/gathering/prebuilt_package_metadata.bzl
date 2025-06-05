"""
This file contains the implementation of the prebuilt_package_metadata rule.
"""

load(
    "//build/bazel/rules/gathering:providers.bzl",
    "PrebuiltPackageInfo",
)

def _prebuilt_package_metadata_impl(ctx):
    # TODO b/337111620: Add validation action to check the third_party_dependencies file
    # uses a consistent format.
    return [
        PrebuiltPackageInfo(
            third_party_dependencies = getattr(ctx.file, "third_party_dependencies", None),
            spdx_json = getattr(ctx.file, "spdx_json", None),
        ),
    ]

prebuilt_package_metadata = rule(
    implementation = _prebuilt_package_metadata_impl,
    doc = """
    A rule that bundles third party dependency metadata for a prebuilt package.
    """,
    attrs = {
        "third_party_dependencies": attr.label(
            allow_single_file = True,
            doc = "A JSON file containing details of the third party dependencies used.",
        ),
        "spdx_json": attr.label(
            allow_single_file = True,
            doc = "A JSON file containing the SPDX JSON for the package.",
        ),
    },
    provides = [PrebuiltPackageInfo],
)
