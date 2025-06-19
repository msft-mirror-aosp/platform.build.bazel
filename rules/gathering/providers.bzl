"""Providers for the gathering rules."""

PrebuiltPackageInfo = provider(
    doc = "A provider for prebuilt packages that bundle other dependencies.",
    fields = {
        "third_party_dependencies": "A file containing details of the third party dependencies used.",
        "spdx_json": "A file containing the SPDX JSON for the package.",
    },
)

TransitivePrebuiltPackageInfo = provider(
    doc = "A provider for transitive prebuilt package info.",
    fields = {
        "deps": "depset(PrebuiltPackageInfo)",
    },
)
