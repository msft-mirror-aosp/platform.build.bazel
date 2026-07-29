"""Utils for libffi."""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def define(key, value):
    if value == None:
        return "/* #undef %s */" % key
    else:
        return "#define %s %s" % (key, value)

def substitutions(input):
    return {"@%s@" % k: define(k, v) for k, v in input.items()}

def _cc_asm_object_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    c_compiler = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = "c-compile",
    )

    is_windows = c_compiler.endswith(".exe") or "clang-cl" in c_compiler

    # Symlink all provided headers into the action's bin directory to ensure clean, flat inclusion discovery without shell escapes
    symlinked_hdrs = []
    for hdr in ctx.files.hdrs:
        symlink_hdr = ctx.actions.declare_file(hdr.basename)
        ctx.actions.symlink(output = symlink_hdr, target_file = hdr)
        symlinked_hdrs.append(symlink_hdr)

    # Dynamically extract absolute dirnames of all source and symlinked headers to guarantee complete header visibility
    hdr_dirs = {}
    for hdr in ctx.files.hdrs + symlinked_hdrs:
        hdr_dirs[hdr.dirname] = True

    include_flags = []
    for d in hdr_dirs.keys():
        include_flags.append("-I" + d)
    for inc in ctx.attr.includes:
        include_flags.append("-I" + inc)

    compilation_contexts = [dep[CcInfo].compilation_context for dep in ctx.attr.deps if CcInfo in dep]

    outputs = []
    for src in ctx.files.srcs:
        ext = ".obj" if is_windows else ".o"
        obj_file = ctx.actions.declare_file(src.basename.replace(".S", ext).replace(".asm", ext))
        outputs.append(obj_file)

        args = ctx.actions.args()
        args.add_all(ctx.attr.copts)
        args.add_all(include_flags)

        for cc_context in compilation_contexts:
            args.add_all(cc_context.includes, before_each = "-I")
            args.add_all(cc_context.quote_includes, before_each = "-I")
            args.add_all(cc_context.system_includes, before_each = "-I")

        if is_windows:
            args.add("/c", src.path)
            args.add("/Fo" + obj_file.path)
        else:
            args.add("-c", src.path)
            args.add("-o", obj_file.path)

        ctx.actions.run(
            outputs = [obj_file],
            inputs = depset(
                direct = [src] + ctx.files.hdrs + symlinked_hdrs,
                transitive = [cc_context.headers for cc_context in compilation_contexts],
            ),
            tools = cc_toolchain.all_files,
            executable = c_compiler,
            arguments = [args],
            mnemonic = "CcAsmCompile",
            progress_message = "Assembling %s" % src.short_path,
        )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([
            cc_common.create_linker_input(
                owner = ctx.label,
                libraries = depset([
                    cc_common.create_library_to_link(
                        actions = ctx.actions,
                        feature_configuration = feature_configuration,
                        cc_toolchain = cc_toolchain,
                        objects = outputs,
                    ),
                ]),
            ),
        ]),
    )

    return [
        DefaultInfo(files = depset(outputs)),
        CcInfo(linking_context = linking_context),
    ]

cc_asm_library = rule(
    implementation = _cc_asm_object_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".S", ".asm"], doc = "The AT&T syntax assembly source files (.S or .asm). Note: Intel/MASM syntax is not supported."),
        "hdrs": attr.label_list(allow_files = True, doc = "Headers required during assembly preprocessor execution."),
        "includes": attr.string_list(doc = "Explicit include paths to pass to the compiler."),
        "copts": attr.string_list(doc = "Additional compiler flags (e.g., /clang:-x /clang:assembler-with-cpp)."),
        "deps": attr.label_list(providers = [CcInfo], doc = "Upstream C++ library dependencies."),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
            doc = "The active C++ toolchain used to execute the assembly action.",
        ),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    fragments = ["cpp"],
    doc = """Compiles AT&T style assembly files with C preprocessor support into object files (.obj or .o).

This rule specifically invokes the C compiler/assembler (e.g., clang/gcc or clang-cl) rather than
Intel/MASM syntax assemblers like ml64.exe or nasm. It exposes the resulting object files via both
`DefaultInfo` (for direct inclusion in `srcs`) and `CcInfo` (for upstream inclusion in `deps`).""",
)
