"""
This file contains the implementation of the write_package_metadata rule.
"""

load(
    "@rules_license//rules_gathering:gather_metadata.bzl",
    "gather_metadata_info",
    "write_metadata_info",
)

def _write_package_metadata_impl(ctx):
    licenses_file = ctx.actions.declare_file("_%s_licenses_info.json" % ctx.label.name)
    write_metadata_info(ctx, ctx.attr.deps, licenses_file)

    outputs = [ctx.outputs.out, licenses_file]

    # TODO: b/337111620 - Merge rules_license metadata and write a combined
    # output format.
    ctx.actions.write(
        output = ctx.outputs.out,
        content = "Hello World",
    )

    return [
        DefaultInfo(files = depset(outputs)),
        OutputGroupInfo(licenses_file = depset([licenses_file])),
    ]

write_package_metadata = rule(
    implementation = _write_package_metadata_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [gather_metadata_info],
        ),
        "out": attr.output(mandatory = True),
    },
)
