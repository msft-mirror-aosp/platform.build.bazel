load("//build/bazel/product_variables:constants.bzl", "constants")
load("@//build/bazel/platforms:product_variables/product_platform.bzl", "determine_target_arches_from_config", "product_variables_providing_rule")
load("@//build/bazel/platforms/arch/variants:constants.bzl", _variant_constants = "constants")
load(
    "//prebuilts/clang/host/linux-x86:cc_toolchain_constants.bzl",
    "arch_to_variants",
    "variant_constraints",
    "variant_name",
)

def product_variable_constraint_settings(variables):
    constraints = []

    local_vars = dict(variables)

    # Native_coverage is not set within soong.variables, but is hardcoded
    # within config.go NewConfig
    local_vars["Native_coverage"] = (
        local_vars.get("ClangCoverage", False) or
        local_vars.get("GcovCoverage", False)
    )

    # Some attributes on rules are able to access the values of product
    # variables via make-style expansion (like $(foo)). We collect the values
    # of the relevant product variables here so that it can be passed to
    # product_variables_providing_rule, which exports a
    # platform_common.TemplateVariableInfo provider to allow the substitution.
    attribute_vars = {}

    def add_attribute_var(typ, var, value):
        if typ == "bool":
            attribute_vars[var] = "1" if value else "0"
        elif typ == "list":
            attribute_vars[var] = ",".join(value)
        elif typ == "int":
            attribute_vars[var] = str(value)
        elif typ == "string":
            attribute_vars[var] = value

    # Generate constraints for Soong config variables (bool, value, string typed).
    vendor_vars = local_vars.pop("VendorVars", default = {})
    for (namespace, variables) in vendor_vars.items():
        for (var, value) in variables.items():
            # All vendor vars are Starlark string-typed, even though they may be
            # boxed bools/strings/arbitrary printf'd values, like numbers, so
            # we'll need to do some translation work here by referring to
            # soong_injection's generated data.

            if value == "":
                # Variable is not set so skip adding this as a constraint.
                continue

            # Create the identifier for the constraint var (or select key)
            config_var = namespace + "__" + var

            # List of all soong_config_module_type variables.
            if not config_var in constants.SoongConfigVariables:
                continue

            # Normalize all constraint vars (i.e. select keys) to be lowercased.
            constraint_var = config_var.lower()

            if config_var in constants.SoongConfigBoolVariables:
                constraints.append("@//build/bazel/product_variables:" + constraint_var)
            elif config_var in constants.SoongConfigStringVariables:
                # The string value is part of the the select key.
                constraints.append("@//build/bazel/product_variables:" + constraint_var + "__" + value.lower())
            elif config_var in constants.SoongConfigValueVariables:
                # For value variables, providing_vars add support for substituting
                # the value using TemplateVariableInfo.
                constraints.append("@//build/bazel/product_variables:" + constraint_var)
                add_attribute_var("string", constraint_var, value)

    for (var, value) in local_vars.items():
        # TODO(b/187323817): determine how to handle remaining product
        # variables not used in product_variables
        constraint_var = var.lower()
        if not constants.ProductVariables.get(constraint_var):
            continue

        # variable.go excludes nil values
        add_constraint = (value != None)
        add_attribute_var(type(value), var, value)
        if type(value) == "bool":
            # variable.go special cases bools
            add_constraint = value

        if add_constraint:
            constraints.append("@//build/bazel/product_variables:" + constraint_var)

    return constraints, attribute_vars

def android_product(name, soong_variables):
    product_var_constraints, attribute_vars = product_variable_constraint_settings(soong_variables)
    arch_configs = determine_target_arches_from_config(soong_variables)

    product_variables_providing_rule(
        name = name + "_product_vars",
        product_vars = attribute_vars,
    )

    native.constraint_value(
        name = name + "_constraint_value",
        constraint_setting = "@//build/bazel/product_config:current_product",
    )

    common_constraints = product_var_constraints + [name + "_constraint_value"]

    # TODO(b/258802089): figure out how to deal with multiple arches for target
    if len(arch_configs) > 0:
        arch = arch_configs[0]
        native.platform(
            name = name,
            constraint_values = common_constraints + [
                "@//build/bazel/platforms/arch:" + arch.arch,
                "@//build/bazel/platforms/os:android",
            ] + ["@" + v for v in variant_constraints(
                arch,
                _variant_constants.AndroidArchToVariantToFeatures[arch.arch],
            )],
        )
        if len(arch_configs) > 1:
            secondary_arch = arch_configs[1]
            native.platform(
                name = name + "_secondary",
                constraint_values = common_constraints + [
                    "@//build/bazel/platforms/arch:" + secondary_arch.arch,
                    "@//build/bazel/platforms/os:android",
                ] + ["@" + v for v in variant_constraints(
                    secondary_arch,
                    _variant_constants.AndroidArchToVariantToFeatures[secondary_arch.arch],
                )],
            )
        else:
            native.alias(
                name = name + "_secondary",
                actual = ":" + name,
            )

        if arch.arch == "arm64" or arch.arch == "x86_64":
            # Apexes need to transition their native_shared_libs to 32 bit.
            # Bazel currently cannot transition on arch directly, and instead
            # requires transitioning on a command line option like --platforms instead.
            # Create a 32 bit variant of the product so that apexes can transition on it.
            if arch == "arm64":
                newarch = struct(
                    arch = "arm",
                    arch_variant = "armv7-a-neon",
                    cpu_variant = "",
                )
            else:
                newarch = struct(
                    arch = "x86",
                    arch_variant = "",
                    cpu_variant = "",
                )
            native.platform(
                name = name + "__internal_32_bit",
                constraint_values = common_constraints + [
                    "@//build/bazel/platforms/arch:" + newarch.arch,
                    "@//build/bazel/platforms/os:android",
                ] + ["@" + v for v in variant_constraints(
                    newarch,
                    _variant_constants.AndroidArchToVariantToFeatures[newarch.arch],
                )],
            )
        else:
            native.alias(
                name = name + "__internal_32_bit",
                actual = ":" + name,
            )

        # These variants are mostly for mixed builds, which may request a
        # module with a certain arch
        for arch, variants in arch_to_variants.items():
            for variant in variants:
                native.platform(
                    name = name + "_android_" + arch + variant_name(variant),
                    constraint_values = common_constraints + [
                        "@//build/bazel/platforms/arch:" + arch,
                        "@//build/bazel/platforms/os:android",
                    ] + ["@" + v for v in variant_constraints(
                        variant,
                        _variant_constants.AndroidArchToVariantToFeatures[arch],
                    )],
                )

        arch_transitions = [
            struct(
                arch = "x86",
                arch_variant = "",
                cpu_variant = "",
            ),
            struct(
                arch = "x86_64",
                arch_variant = "",
                cpu_variant = "",
            ),
            struct(
                arch = "arm",
                arch_variant = "armv7-a-neon",
                cpu_variant = "",
            ),
            struct(
                arch = "arm64",
                arch_variant = "armv8-a",
                cpu_variant = "",
            ),
        ]

        # TODO(b/249685973): Remove this, this is currently just for aabs
        # to build each architecture
        for arch in arch_transitions:
            native.platform(
                name = name + "__internal_" + arch.arch,
                constraint_values = common_constraints + [
                    "@//build/bazel/platforms/arch:" + arch.arch,
                    "@//build/bazel/platforms/os:android",
                ] + ["@" + v for v in variant_constraints(
                    arch,
                    _variant_constants.AndroidArchToVariantToFeatures[arch.arch],
                )],
            )

    # Now define the host platforms. We need a host platform per product because
    # the host platforms still use the product variables.
    # TODO(b/262753134): Investigate making the host platforms product-independant
    native.platform(
        name = name + "_linux_x86",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:x86",
            "@//build/bazel/platforms/os:linux",
        ],
    )

    native.platform(
        name = name + "_linux_x86_64",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:x86_64",
            "@//build/bazel/platforms/os:linux",
        ],
    )

    # linux_bionic is the OS for the Linux kernel plus the Bionic libc runtime, but
    # without the rest of Android.
    native.platform(
        name = name + "_linux_bionic_arm64",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:arm64",
            "@//build/bazel/platforms/os:linux_bionic",
        ],
    )

    native.platform(
        name = name + "_linux_bionic_x86_64",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:x86_64",
            "@//build/bazel/platforms/os:linux_bionic",
        ],
    )

    native.platform(
        name = name + "_darwin_arm64",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:arm64",
            "@//build/bazel/platforms/os:darwin",
        ],
    )

    native.platform(
        name = name + "_darwin_x86_64",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:x86_64",
            "@//build/bazel/platforms/os:darwin",
        ],
    )

    native.platform(
        name = name + "_windows_x86",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:x86",
            "@//build/bazel/platforms/os:windows",
        ],
    )

    native.platform(
        name = name + "_windows_x86_64",
        constraint_values = common_constraints + [
            "@//build/bazel/platforms/arch:x86_64",
            "@//build/bazel/platforms/os:windows",
        ],
    )
