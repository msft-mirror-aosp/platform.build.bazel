# Copyright (C) 2022 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("//build/bazel/rules:sh_binary.bzl", "sh_binary")
load("//build/bazel/rules/android:android_app_certificate.bzl", "AndroidAppCertificateInfo", "android_app_certificate")
load("//build/bazel/rules/cc:cc_binary.bzl", "cc_binary")
load("//build/bazel/rules/cc:cc_library_shared.bzl", "cc_library_shared")
load("//build/bazel/rules/cc:cc_library_static.bzl", "cc_library_static")
load("//build/bazel/rules/cc:cc_stub_library.bzl", "cc_stub_suite")
load("//build/bazel/rules:prebuilt_file.bzl", "prebuilt_file")
load("//build/bazel/platforms:platform_utils.bzl", "platforms")
load(":apex.bzl", "ApexInfo", "apex")
load(":apex_key.bzl", "apex_key")
load(":apex_test_helpers.bzl", "test_apex")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load("@soong_injection//apex_toolchain:constants.bzl", "default_manifest_version")

ActionArgsInfo = provider(
    fields = {
        "argv": "The link action arguments.",
    },
)

def _canned_fs_config_test(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    found_canned_fs_config_action = False

    def pretty_print_list(l):
        if not l:
            return "[]"
        result = "[\n"
        for item in l:
            result += "  \"%s\",\n" % item
        return result + "]"

    for a in actions:
        if a.mnemonic != "FileWrite":
            # The canned_fs_config uses ctx.actions.write.
            continue

        outputs = a.outputs.to_list()
        if len(outputs) != 1:
            continue
        if not outputs[0].basename.endswith("_canned_fs_config.txt"):
            continue

        found_canned_fs_config_action = True

        # Don't sort -- the order is significant.
        actual_entries = a.content.split("\n")
        replacement = "64" if platforms.get_target_bitness(ctx.attr._platform_utils) == 64 else ""
        expected_entries = [x.replace("{64_OR_BLANK}", replacement) for x in ctx.attr.expected_entries]
        asserts.equals(env, pretty_print_list(expected_entries), pretty_print_list(actual_entries))

        break

    # Ensures that we actually found the canned_fs_config.txt generation action.
    asserts.true(env, found_canned_fs_config_action)

    return analysistest.end(env)

canned_fs_config_test = analysistest.make(
    _canned_fs_config_test,
    attrs = {
        "expected_entries": attr.string_list(
            doc = "Expected lines in the canned_fs_config.txt",
        ),
        "_platform_utils": attr.label(
            default = Label("//build/bazel/platforms:platform_utils"),
        ),
    },
)

def _test_canned_fs_config_basic():
    name = "apex_canned_fs_config_basic"
    test_name = name + "_test"

    test_apex(name = name)

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "",  # ends with a newline
        ],
    )

    return test_name

def _test_canned_fs_config_binaries():
    name = "apex_canned_fs_config_binaries"
    test_name = name + "_test"

    sh_binary(
        name = "bin_sh",
        srcs = ["bin.sh"],
        tags = ["manual"],
    )

    cc_binary(
        name = "bin_cc",
        srcs = ["bin.cc"],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        binaries = ["bin_sh", "bin_cc"],
    )

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "/lib{64_OR_BLANK}/libc++.so 1000 1000 0644",
            "/bin/bin_cc 0 2000 0755",
            "/bin/bin_sh 0 2000 0755",
            "/bin 0 2000 0755",
            "/lib{64_OR_BLANK} 0 2000 0755",
            "",  # ends with a newline
        ],
        target_compatible_with = ["//build/bazel/platforms/os:android"],
    )

    return test_name

def _test_canned_fs_config_native_shared_libs_arm():
    name = "apex_canned_fs_config_native_shared_libs_arm"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_lib2_cc",
        srcs = [name + "_lib2.cc"],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        native_shared_libs_64 = [name + "_lib2_cc"],
    )

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "/lib/apex_canned_fs_config_native_shared_libs_arm_lib_cc.so 1000 1000 0644",
            "/lib/libc++.so 1000 1000 0644",
            "/lib 0 2000 0755",
            "",  # ends with a newline
        ],
        target_compatible_with = ["//build/bazel/platforms/arch:arm"],
    )

    return test_name

def _test_canned_fs_config_native_shared_libs_arm64():
    name = "apex_canned_fs_config_native_shared_libs_arm64"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_lib2_cc",
        srcs = [name + "_lib2.cc"],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        native_shared_libs_64 = [name + "_lib2_cc"],
    )

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "/lib/apex_canned_fs_config_native_shared_libs_arm64_lib_cc.so 1000 1000 0644",
            "/lib/libc++.so 1000 1000 0644",
            "/lib64/apex_canned_fs_config_native_shared_libs_arm64_lib2_cc.so 1000 1000 0644",
            "/lib64/libc++.so 1000 1000 0644",
            "/lib 0 2000 0755",
            "/lib64 0 2000 0755",
            "",  # ends with a newline
        ],
        target_compatible_with = ["//build/bazel/platforms/arch:arm64"],
    )

    return test_name

def _test_canned_fs_config_prebuilts():
    name = "apex_canned_fs_config_prebuilts"
    test_name = name + "_test"

    prebuilt_file(
        name = "file",
        src = "file.txt",
        dir = "etc",
        tags = ["manual"],
    )

    prebuilt_file(
        name = "nested_file_in_dir",
        src = "file2.txt",
        dir = "etc/nested",
        tags = ["manual"],
    )

    prebuilt_file(
        name = "renamed_file_in_dir",
        src = "file3.txt",
        dir = "etc",
        filename = "renamed_file3.txt",
        tags = ["manual"],
    )

    test_apex(
        name = name,
        prebuilts = [
            ":file",
            ":nested_file_in_dir",
            ":renamed_file_in_dir",
        ],
    )

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "/etc/file 1000 1000 0644",
            "/etc/nested/nested_file_in_dir 1000 1000 0644",
            "/etc/renamed_file3.txt 1000 1000 0644",
            "/etc 0 2000 0755",
            "/etc/nested 0 2000 0755",
            "",  # ends with a newline
        ],
    )

    return test_name

def _test_canned_fs_config_prebuilts_sort_order():
    name = "apex_canned_fs_config_prebuilts_sort_order"
    test_name = name + "_test"

    prebuilt_file(
        name = "file_a",
        src = "file_a.txt",
        dir = "etc/a",
        tags = ["manual"],
    )

    prebuilt_file(
        name = "file_b",
        src = "file_b.txt",
        dir = "etc/b",
        tags = ["manual"],
    )

    prebuilt_file(
        name = "file_a_c",
        src = "file_a_c.txt",
        dir = "etc/a/c",
        tags = ["manual"],
    )

    test_apex(
        name = name,
        prebuilts = [
            ":file_a",
            ":file_b",
            ":file_a_c",
        ],
    )

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "/etc/a/c/file_a_c 1000 1000 0644",
            "/etc/a/file_a 1000 1000 0644",
            "/etc/b/file_b 1000 1000 0644",
            "/etc 0 2000 0755",
            "/etc/a 0 2000 0755",
            "/etc/a/c 0 2000 0755",
            "/etc/b 0 2000 0755",
            "",  # ends with a newline
        ],
    )

    return test_name

def _test_canned_fs_config_runtime_deps():
    name = "apex_canned_fs_config_runtime_deps"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_runtime_dep_3",
        srcs = ["lib2.cc"],
        tags = ["manual"],
    )

    cc_library_static(
        name = name + "_static_lib",
        srcs = ["lib3.cc"],
        runtime_deps = [name + "_runtime_dep_3"],
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_runtime_dep_2",
        srcs = ["lib2.cc"],
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_runtime_dep_1",
        srcs = ["lib.cc"],
        runtime_deps = [name + "_runtime_dep_2"],
        tags = ["manual"],
    )

    cc_binary(
        name = name + "_bin_cc",
        srcs = ["bin.cc"],
        runtime_deps = [name + "_runtime_dep_1"],
        deps = [name + "_static_lib"],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        binaries = [name + "_bin_cc"],
    )

    canned_fs_config_test(
        name = test_name,
        target_under_test = name,
        expected_entries = [
            "/ 1000 1000 0755",
            "/apex_manifest.json 1000 1000 0644",
            "/apex_manifest.pb 1000 1000 0644",
            "/lib{64_OR_BLANK}/%s_runtime_dep_1.so 1000 1000 0644" % name,
            "/lib{64_OR_BLANK}/%s_runtime_dep_2.so 1000 1000 0644" % name,
            "/lib{64_OR_BLANK}/%s_runtime_dep_3.so 1000 1000 0644" % name,
            "/lib{64_OR_BLANK}/libc++.so 1000 1000 0644",
            "/bin/%s_bin_cc 0 2000 0755" % name,
            "/bin 0 2000 0755",
            "/lib{64_OR_BLANK} 0 2000 0755",
            "",  # ends with a newline
        ],
        target_compatible_with = ["//build/bazel/platforms/os:android"],
    )

    return test_name

def _apex_manifest_test(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    conv_apex_manifest_action = [a for a in actions if a.mnemonic == "ConvApexManifest"][0]

    apexer_action = [a for a in actions if a.mnemonic == "Apexer"][0]
    manifest_index = apexer_action.argv.index("--manifest")
    manifest_path = apexer_action.argv[manifest_index + 1]

    asserts.equals(
        env,
        conv_apex_manifest_action.outputs.to_list()[0].path,
        manifest_path,
        "the generated apex manifest protobuf is used as input to apexer",
    )
    asserts.true(
        env,
        manifest_path.endswith(".pb"),
        "the generated apex manifest should be a .pb file",
    )

    if ctx.attr.expected_min_sdk_version != "":
        flag_index = apexer_action.argv.index("--min_sdk_version")
        min_sdk_version_argv = apexer_action.argv[flag_index + 1]
        asserts.equals(
            env,
            ctx.attr.expected_min_sdk_version,
            min_sdk_version_argv,
        )

    return analysistest.end(env)

apex_manifest_test = analysistest.make(
    _apex_manifest_test,
    attrs = {
        "expected_min_sdk_version": attr.string(),
    },
)

def _test_apex_manifest():
    name = "apex_manifest"
    test_name = name + "_test"

    test_apex(name = name)

    apex_manifest_test(
        name = test_name,
        target_under_test = name,
    )

    return test_name

def _test_apex_manifest_min_sdk_version():
    name = "apex_manifest_min_sdk_version"
    test_name = name + "_test"

    test_apex(
        name = name,
        min_sdk_version = "30",
    )

    apex_manifest_test(
        name = test_name,
        target_under_test = name,
        expected_min_sdk_version = "30",
    )

    return test_name

def _test_apex_manifest_min_sdk_version_current():
    name = "apex_manifest_min_sdk_version_current"
    test_name = name + "_test"

    test_apex(
        name = name,
        min_sdk_version = "current",
    )

    apex_manifest_test(
        name = test_name,
        target_under_test = name,
        expected_min_sdk_version = "10000",
    )

    return test_name

def _apex_native_libs_requires_provides_test(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    asserts.equals(
        env,
        sorted([t.label for t in ctx.attr.requires_native_libs]),  # expected
        sorted(target_under_test[ApexInfo].requires_native_libs),  # actual
    )
    asserts.equals(
        env,
        sorted([t.label for t in ctx.attr.provides_native_libs]),
        sorted(target_under_test[ApexInfo].provides_native_libs),
    )

    # Compare the argv of the jsonmodify action that updates the apex
    # manifest with information about provided and required libs.
    actions = analysistest.target_actions(env)
    action = [a for a in actions if a.mnemonic == "ApexManifestModify"][0]
    requires_argv_index = action.argv.index("requireNativeLibs") + 1
    provides_argv_index = action.argv.index("provideNativeLibs") + 1

    for idx, requires in enumerate(ctx.attr.requires_native_libs):
        asserts.equals(
            env,
            requires.label.name + ".so",  # expected
            action.argv[requires_argv_index + idx],  # actual
        )

    for idx, provides in enumerate(ctx.attr.provides_native_libs):
        asserts.equals(
            env,
            provides.label.name + ".so",
            action.argv[provides_argv_index + idx],
        )

    return analysistest.end(env)

apex_native_libs_requires_provides_test = analysistest.make(
    _apex_native_libs_requires_provides_test,
    attrs = {
        "requires_native_libs": attr.label_list(),
        "provides_native_libs": attr.label_list(),
        "requires_argv": attr.string_list(),
        "provides_argv": attr.string_list(),
    },
)

def _test_apex_manifest_dependencies_nodep():
    name = "apex_manifest_dependencies_nodep"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_nodep",
        stl = "none",
        system_dynamic_deps = [],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_nodep"],
        native_shared_libs_64 = [name + "_lib_nodep"],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [],
        provides_native_libs = [],
    )

    return test_name

def _test_apex_manifest_dependencies_cc_library_shared_bionic_deps():
    name = "apex_manifest_dependencies_cc_library_shared_bionic_deps"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib",
        # implicit bionic system_dynamic_deps
        tags = ["manual"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib"],
        native_shared_libs_64 = [name + "_lib"],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [
            "//bionic/libc",
            "//bionic/libdl",
            "//bionic/libm",
        ],
        provides_native_libs = [],
    )

    return test_name

def _test_apex_manifest_dependencies_cc_binary_bionic_deps():
    name = "apex_manifest_dependencies_cc_binary_bionic_deps"
    test_name = name + "_test"

    cc_binary(
        name = name + "_bin",
        # implicit bionic system_deps
        tags = ["manual"],
    )

    test_apex(
        name = name,
        binaries = [name + "_bin"],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [
            "//bionic/libc",
            "//bionic/libdl",
            "//bionic/libm",
        ],
        provides_native_libs = [],
    )

    return test_name

def _test_apex_manifest_dependencies_requires():
    name = "apex_manifest_dependencies_requires"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_with_dep",
        system_dynamic_deps = [],
        stl = "none",
        implementation_dynamic_deps = select({
            "//build/bazel/rules/apex:android-in_apex": [name + "_libfoo_stub_libs_current"],
            "//build/bazel/rules/apex:android-non_apex": [name + "_libfoo"],
        }),
        tags = ["manual"],
        has_stubs = True,
    )

    native.genrule(
        name = name + "_genrule_lib_with_dep_map_txt",
        outs = [name + "_lib_with_dep.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_lib_with_dep_stub_libs",
        soname = name + "_lib_with_dep.so",
        source_library = ":" + name + "_lib_with_dep",
        symbol_file = name + "_lib_with_dep.map.txt",
        versions = ["30"],
    )

    cc_library_shared(
        name = name + "_libfoo",
        system_dynamic_deps = [],
        stl = "none",
        tags = ["manual"],
        has_stubs = False,
    )

    native.genrule(
        name = name + "_genrule_libfoo_map_txt",
        outs = [name + "_libfoo.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_libfoo_stub_libs",
        soname = name + "_libfoo.so",
        source_library = ":" + name + "_libfoo",
        symbol_file = name + "_libfoo.map.txt",
        versions = ["30"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_with_dep"],
        native_shared_libs_64 = [name + "_lib_with_dep"],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [name + "_libfoo"],
        provides_native_libs = [name + "_lib_with_dep"],
        target_compatible_with = ["//build/bazel/platforms/os:android"],
    )

    return test_name

def _test_apex_manifest_dependencies_provides():
    name = "apex_manifest_dependencies_provides"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_libfoo",
        system_dynamic_deps = [],
        stl = "none",
        tags = ["manual"],
        has_stubs = True,
    )

    native.genrule(
        name = name + "_genrule_libfoo_map_txt",
        outs = [name + "_libfoo.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_libfoo_stub_libs",
        soname = name + "_libfoo.so",
        source_library = ":" + name + "_libfoo",
        symbol_file = name + "_libfoo.map.txt",
        versions = ["30"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_libfoo"],
        native_shared_libs_64 = [name + "_libfoo"],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [],
        provides_native_libs = [name + "_libfoo"],
    )

    return test_name

def _test_apex_manifest_dependencies_selfcontained():
    name = "apex_manifest_dependencies_selfcontained"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_with_dep",
        system_dynamic_deps = [],
        stl = "none",
        implementation_dynamic_deps = select({
            "//build/bazel/rules/apex:android-in_apex": [name + "_libfoo_stub_libs_current"],
            "//build/bazel/rules/apex:android-non_apex": [name + "_libfoo"],
        }),
        tags = ["manual"],
        has_stubs = True,
    )

    native.genrule(
        name = name + "_genrule_lib-with_dep_map_txt",
        outs = [name + "_lib_with_dep.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_lib_with_dep_stub_libs",
        soname = name + "_lib_with_dep.so",
        source_library = ":" + name + "_lib_with_dep",
        symbol_file = name + "_lib_with_dep.map.txt",
        versions = ["30"],
    )

    cc_library_shared(
        name = name + "_libfoo",
        system_dynamic_deps = [],
        stl = "none",
        tags = ["manual"],
        has_stubs = True,
    )

    native.genrule(
        name = name + "_genrule_libfoo_map_txt",
        outs = [name + "_libfoo.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_libfoo_stub_libs",
        soname = name + "_libfoo.so",
        source_library = ":" + name + "_libfoo",
        symbol_file = name + "_libfoo.map.txt",
        versions = ["30"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [
            name + "_lib_with_dep",
            name + "_libfoo",
        ],
        native_shared_libs_64 = [
            name + "_lib_with_dep",
            name + "_libfoo",
        ],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [],
        provides_native_libs = [
            name + "_lib_with_dep",
            name + "_libfoo",
        ],
        target_compatible_with = ["//build/bazel/platforms/os:android"],
    )

    return test_name

def _test_apex_manifest_dependencies_cc_binary():
    name = "apex_manifest_dependencies_cc_binary"
    test_name = name + "_test"

    cc_binary(
        name = name + "_bin",
        stl = "none",
        system_deps = [],
        dynamic_deps = [
            name + "_lib_with_dep",
        ] + select({
            "//build/bazel/rules/apex:android-in_apex": [name + "_librequires2_stub_libs_current"],
            "//build/bazel/rules/apex:android-non_apex": [name + "_librequires2"],
        }),
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_lib_with_dep",
        system_dynamic_deps = [],
        stl = "none",
        implementation_dynamic_deps = select({
            "//build/bazel/rules/apex:android-in_apex": [name + "_librequires_stub_libs_current"],
            "//build/bazel/rules/apex:android-non_apex": [name + "_librequires"],
        }),
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_librequires",
        system_dynamic_deps = [],
        stl = "none",
        tags = ["manual"],
        has_stubs = True,
    )

    native.genrule(
        name = name + "_genrule_librequires_map_txt",
        outs = [name + "_librequires.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_librequires_stub_libs",
        soname = name + "_librequires.so",
        source_library = ":" + name + "_librequires",
        symbol_file = name + "_librequires.map.txt",
        versions = ["30"],
    )

    cc_library_shared(
        name = name + "_librequires2",
        system_dynamic_deps = [],
        stl = "none",
        tags = ["manual"],
        has_stubs = True,
    )

    native.genrule(
        name = name + "_genrule_librequires2_map_txt",
        outs = [name + "_librequires2.map.txt"],
        cmd = "touch $@",
        tags = ["manual"],
    )

    cc_stub_suite(
        name = name + "_librequires2_stub_libs",
        soname = name + "_librequires2.so",
        source_library = ":" + name + "_librequires2",
        symbol_file = name + "_librequires2.map.txt",
        versions = ["30"],
    )

    test_apex(
        name = name,
        binaries = [name + "_bin"],
    )

    apex_native_libs_requires_provides_test(
        name = test_name,
        target_under_test = name,
        requires_native_libs = [
            name + "_librequires",
            name + "_librequires2",
        ],
        target_compatible_with = ["//build/bazel/platforms/os:android"],
    )

    return test_name

def _action_args_test(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    action = [a for a in actions if a.mnemonic == ctx.attr.action_mnemonic][0]
    flag_idx = action.argv.index(ctx.attr.expected_args[0])

    for i, expected_arg in enumerate(ctx.attr.expected_args):
        asserts.equals(
            env,
            expected_arg,
            action.argv[flag_idx + i],
        )

    return analysistest.end(env)

action_args_test = analysistest.make(
    _action_args_test,
    attrs = {
        "action_mnemonic": attr.string(mandatory = True),
        "expected_args": attr.string_list(mandatory = True),
    },
)

def _test_logging_parent_flag():
    name = "logging_parent"
    test_name = name + "_test"

    test_apex(
        name = name,
        logging_parent = "logging.parent",
    )

    action_args_test(
        name = test_name,
        target_under_test = name,
        action_mnemonic = "Apexer",
        expected_args = [
            "--logging_parent",
            "logging.parent",
        ],
    )

    return test_name

def _test_default_apex_manifest_version():
    name = "default_apex_manifest_version"
    test_name = name + "_test"

    test_apex(
        name = name,
    )

    action_args_test(
        name = test_name,
        target_under_test = name,
        action_mnemonic = "ApexManifestModify",
        expected_args = [
            "-se",
            "version",
            "0",
            str(default_manifest_version),
        ],
    )

    return test_name

def _file_contexts_args_test(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    file_contexts_action = [a for a in actions if a.mnemonic == "GenerateApexFileContexts"][0]

    # GenerateApexFileContexts is a run_shell action.
    # ["/bin/bash", "c", "<args>"]
    cmd = file_contexts_action.argv[2]

    for i, expected_arg in enumerate(ctx.attr.expected_args):
        asserts.true(
            env,
            expected_arg in cmd,
            "failed to find '%s' in '%s'" % (expected_arg, cmd),
        )

    return analysistest.end(env)

file_contexts_args_test = analysistest.make(
    _file_contexts_args_test,
    attrs = {
        "expected_args": attr.string_list(mandatory = True),
    },
)

def _test_generate_file_contexts():
    name = "apex_manifest_pb_file_contexts"
    test_name = name + "_test"

    test_apex(
        name = name,
    )

    file_contexts_args_test(
        name = test_name,
        target_under_test = name,
        expected_args = [
            "/apex_manifest\\\\.pb u:object_r:system_file:s0",
            "/ u:object_r:system_file:s0",
        ],
    )

    return test_name

def _min_sdk_version_failure_test_impl(ctx):
    env = analysistest.begin(ctx)

    asserts.expect_failure(
        env,
        "min_sdk_version %s cannot be lower than the dep's min_sdk_version %s" %
        (ctx.attr.apex_min, ctx.attr.dep_min),
    )

    return analysistest.end(env)

min_sdk_version_failure_test = analysistest.make(
    _min_sdk_version_failure_test_impl,
    expect_failure = True,
    attrs = {
        "apex_min": attr.string(),
        "dep_min": attr.string(),
    },
)

def _test_min_sdk_version_failure():
    name = "min_sdk_version_failure"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
        min_sdk_version = "32",
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        min_sdk_version = "30",
    )

    min_sdk_version_failure_test(
        name = test_name,
        target_under_test = name,
        apex_min = "30",
        dep_min = "32",
    )

    return test_name

def _test_min_sdk_version_failure_transitive():
    name = "min_sdk_version_failure_transitive"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        dynamic_deps = [name + "_lib2_cc"],
        tags = ["manual"],
    )

    cc_library_shared(
        name = name + "_lib2_cc",
        srcs = [name + "_lib2.cc"],
        tags = ["manual"],
        min_sdk_version = "32",
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        min_sdk_version = "30",
    )

    min_sdk_version_failure_test(
        name = test_name,
        target_under_test = name,
        apex_min = "30",
        dep_min = "32",
    )

    return test_name

def _apex_certificate_test(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    container_key_info = target_under_test[ApexInfo].container_key_info

    asserts.equals(env, ctx.attr.expected_pem_path, container_key_info.pem.path)
    asserts.equals(env, ctx.attr.expected_pk8_path, container_key_info.pk8.path)

    return analysistest.end(env)

apex_certificate_test = analysistest.make(
    _apex_certificate_test,
    attrs = {
        "expected_pem_path": attr.string(),
        "expected_pk8_path": attr.string(),
    },
)

def _test_apex_certificate_none():
    name = "apex_certificate_none"
    test_name = name + "_test"

    test_apex(
        name = name,
        certificate = None,
    )

    apex_certificate_test(
        name = test_name,
        target_under_test = name,
        expected_pem_path = "build/make/target/product/security/testkey.x509.pem",
        expected_pk8_path = "build/make/target/product/security/testkey.pk8",
    )

    return test_name

def _test_apex_certificate_name():
    name = "apex_certificate_name"
    test_name = name + "_test"

    test_apex(
        name = name,
        certificate = None,
        certificate_name = "shared",  # use something other than testkey
    )

    apex_certificate_test(
        name = test_name,
        target_under_test = name,
        expected_pem_path = "build/make/target/product/security/shared.x509.pem",
        expected_pk8_path = "build/make/target/product/security/shared.pk8",
    )

    return test_name

def _test_apex_certificate_label():
    name = "apex_certificate_label"
    test_name = name + "_test"

    android_app_certificate(
        name = name + "_cert",
        certificate = name,
        tags = ["manual"],
    )

    test_apex(
        name = name,
        certificate = name + "_cert",
    )

    apex_certificate_test(
        name = test_name,
        target_under_test = name,
        expected_pem_path = "build/bazel/rules/apex/apex_certificate_label.x509.pem",
        expected_pk8_path = "build/bazel/rules/apex/apex_certificate_label.pk8",
    )

    return test_name

def _min_sdk_version_apex_inherit_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    argv = target_under_test[ActionArgsInfo].argv

    found = False
    for arg in argv:
        if arg.startswith("--target="):
            found = True
            asserts.true(
                env,
                arg.endswith(ctx.attr.apex_min),
                "Incorrect --target flag: %s %s" % (arg, ctx.attr.apex_min),
            )

    asserts.true(
        env,
        found,
        "No --target flag found: %s" % argv,
    )

    return analysistest.end(env)

def _feature_check_aspect_impl(target, ctx):
    rules_propagate_src = [
        "_bssl_hash_injection",
        "stripped_shared_library",
        "versioned_shared_library",
    ]

    argv = []
    if ctx.rule.kind == "cc_shared_library" and target.label.name == ctx.attr.cc_target:
        link_actions = [a for a in target.actions if a.mnemonic == "CppLink"]
        argv = link_actions[0].argv
    elif ctx.rule.kind in rules_propagate_src and hasattr(ctx.rule.attr, "src"):
        argv = ctx.rule.attr.src[ActionArgsInfo].argv
    elif ctx.rule.kind == "_cc_library_shared_proxy" and hasattr(ctx.rule.attr, "shared"):
        argv = ctx.rule.attr.shared[ActionArgsInfo].argv
    elif ctx.rule.kind == "_apex" and hasattr(ctx.rule.attr, "native_shared_libs_32"):
        argv = ctx.rule.attr.native_shared_libs_32[0][ActionArgsInfo].argv

    return [
        ActionArgsInfo(
            argv = argv,
        ),
    ]

feature_check_aspect = aspect(
    implementation = _feature_check_aspect_impl,
    attrs = {
        "cc_target": attr.string(values = ["min_sdk_version_apex_inherit_lib_cc_unstripped"]),
    },
    attr_aspects = ["native_shared_libs_32", "shared", "src"],
)

min_sdk_version_apex_inherit_test = analysistest.make(
    _min_sdk_version_apex_inherit_test_impl,
    attrs = {
        "apex_min": attr.string(),
        "cc_target": attr.string(),
    },
    # We need to use aspect to examine the dependencies' actions of the apex
    # target as the result of the transition, checking the dependencies directly
    # using names will give you the info before the transition takes effect.
    extra_target_under_test_aspects = [feature_check_aspect],
)

def _test_min_sdk_version_apex_inherit():
    name = "min_sdk_version_apex_inherit"
    test_name = name + "_test"
    cc_name = name + "_lib_cc"
    apex_min = "28"

    cc_library_shared(
        name = cc_name,
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
        min_sdk_version = "apex_inherit",
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [cc_name],
        min_sdk_version = apex_min,
    )

    min_sdk_version_apex_inherit_test(
        name = test_name,
        target_under_test = name,
        apex_min = apex_min,
        cc_target = cc_name + "_unstripped",
    )

    return test_name

def _apex_provides_base_zip_files_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # The particular name of the file isn't important as it just gets zipped with the other apex files for other architectures
    asserts.true(
        env,
        target_under_test[ApexInfo].base_file != None,
        "Expected base_file to exist, but found None %s" % target_under_test[ApexInfo].base_file,
    )

    asserts.equals(
        env,
        target_under_test[ApexInfo].base_with_config_zip.basename,
        # name is important here because the file gets disted and then referenced by name
        ctx.attr.apex_name + ".apex-base.zip",
        "Expected base file with config zip to have name ending with , but found %s" % target_under_test[ApexInfo].base_with_config_zip.basename,
    )

    return analysistest.end(env)

apex_provides_base_zip_files_test = analysistest.make(
    _apex_provides_base_zip_files_test_impl,
    attrs = {
        "apex_name": attr.string(),
    },
)

def _test_apex_provides_base_zip_files():
    name = "apex_provides_base_zip_files"
    test_name = name + "_test"

    test_apex(name = name)

    apex_provides_base_zip_files_test(
        name = test_name,
        target_under_test = name,
        apex_name = name,
    )

    return test_name

def _apex_testonly_with_manifest_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "Apexer"]
    asserts.true(
        env,
        len(actions) == 1,
        "No apexer action found: %s" % actions,
    )
    argv = actions[0].argv

    asserts.false(
        env,
        "--test_only" in argv,
        "Calling apexer with --test_only when manifest file is specified: %s" % argv,
    )

    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "MarkAndroidManifestTestOnly"]
    asserts.true(
        env,
        len(actions) == 1,
        "No MarkAndroidManifestTestOnly action found: %s" % actions,
    )
    argv = actions[0].argv

    asserts.true(
        env,
        "--test-only" in argv,
        "Calling manifest_fixer without --test-only: %s" % argv,
    )

    return analysistest.end(env)

apex_testonly_with_manifest_test = analysistest.make(
    _apex_testonly_with_manifest_test_impl,
)

def _test_apex_testonly_with_manifest():
    name = "apex_testonly_with_manifest"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
        min_sdk_version = "32",
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        # This will not cause the validation failure because it is testonly.
        min_sdk_version = "30",
        testonly = True,
        tests = [name + "_cc_test"],
        android_manifest = "AndroidManifest.xml",
    )

    # It shouldn't complain about the min_sdk_version of the dep is too low.
    apex_testonly_with_manifest_test(
        name = test_name,
        target_under_test = name,
    )

    return test_name

def _apex_testonly_without_manifest_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "Apexer"]
    asserts.true(
        env,
        len(actions) == 1,
        "No apexer action found: %s" % actions,
    )
    argv = actions[0].argv

    asserts.true(
        env,
        "--test_only" in argv,
        "Calling apexer without --test_only when manifest file is not specified: %s" % argv,
    )

    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "MarkAndroidManifestTestOnly"]
    asserts.true(
        env,
        len(actions) == 0,
        "MarkAndroidManifestTestOnly shouldn't be called when manifest file is not specified: %s" % actions,
    )

    return analysistest.end(env)

apex_testonly_without_manifest_test = analysistest.make(
    _apex_testonly_without_manifest_test_impl,
)

def _test_apex_testonly_without_manifest():
    name = "apex_testonly_without_manifest"
    test_name = name + "_test"

    test_apex(
        name = name,
        testonly = True,
    )

    apex_testonly_without_manifest_test(
        name = test_name,
        target_under_test = name,
    )

    return test_name

def _apex_backing_file_test(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "FileWrite" and a.outputs.to_list()[0].basename.endswith("_backing.txt")]
    asserts.true(
        env,
        len(actions) == 1,
        "No FileWrite action found for creating <apex>_backing.txt file: %s" % actions,
    )

    asserts.equals(env, ctx.attr.expected_content, actions[0].content)
    return analysistest.end(env)

apex_backing_file_test = analysistest.make(
    _apex_backing_file_test,
    attrs = {
        "expected_content": attr.string(),
    },
)

def _test_apex_backing_file():
    name = "apex_backing_file"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        android_manifest = "AndroidManifest.xml",
    )

    apex_backing_file_test(
        name = test_name,
        target_under_test = name,
        expected_content = "apex_backing_file_lib_cc.so libc++.so\n",
    )

    return test_name

def _apex_installed_files_test(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "GenerateApexInstalledFileList"]
    asserts.true(
        env,
        len(actions) == 1,
        "No GenerateApexInstalledFileList action found for creating <apex>-installed-files.txt file: %s" % actions,
    )

    asserts.equals(
        env,
        len(ctx.attr.expected_inputs),
        len(actions[0].inputs.to_list()),
        "Expected inputs length: %d, actual inputs length: %d" % (len(ctx.attr.expected_inputs), len(actions[0].inputs.to_list())),
    )
    for file in actions[0].inputs.to_list():
        asserts.true(
            env,
            file.basename in ctx.attr.expected_inputs,
            "Unexpected input: %s" % file.basename,
        )
    asserts.equals(env, ctx.attr.expected_output, actions[0].outputs.to_list()[0].basename)
    return analysistest.end(env)

apex_installed_files_test = analysistest.make(
    _apex_installed_files_test,
    attrs = {
        "expected_inputs": attr.string_list(),
        "expected_output": attr.string(),
    },
)

def _test_apex_installed_files():
    name = "apex_installed_files"
    test_name = name + "_test"

    cc_library_shared(
        name = name + "_lib_cc",
        srcs = [name + "_lib.cc"],
        tags = ["manual"],
    )

    test_apex(
        name = name,
        native_shared_libs_32 = [name + "_lib_cc"],
        android_manifest = "AndroidManifest.xml",
    )

    apex_installed_files_test(
        name = test_name,
        target_under_test = name,
        expected_inputs = ["libc++.so", "apex_installed_files_lib_cc.so"],
        expected_output = "apex_installed_files-installed-files.txt",
    )

    return test_name

def _apex_symbols_used_by_apex_test(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actual = target_under_test[ApexInfo].symbols_used_by_apex

    asserts.equals(env, ctx.attr.expected_path, actual.short_path)

    return analysistest.end(env)

apex_symbols_used_by_apex_test = analysistest.make(
    _apex_symbols_used_by_apex_test,
    attrs = {
        "expected_path": attr.string(),
    },
)

def _test_apex_symbols_used_by_apex():
    name = "apex_with_symbols_used_by_apex"
    test_name = name + "_test"

    test_apex(
        name = name,
    )

    apex_symbols_used_by_apex_test(
        name = test_name,
        target_under_test = name,
        expected_path = "build/bazel/rules/apex/apex_with_symbols_used_by_apex_using.txt",
    )

    return test_name

def _apex_java_symbols_used_by_apex_test(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actual = target_under_test[ApexInfo].java_symbols_used_by_apex

    asserts.equals(env, ctx.attr.expected_path, actual.short_path)

    return analysistest.end(env)

apex_java_symbols_used_by_apex_test = analysistest.make(
    _apex_java_symbols_used_by_apex_test,
    attrs = {
        "expected_path": attr.string(),
    },
)

def _test_apex_java_symbols_used_by_apex():
    name = "apex_with_java_symbols_used_by_apex"
    test_name = name + "_test"

    test_apex(
        name = name,
    )

    apex_java_symbols_used_by_apex_test(
        name = test_name,
        target_under_test = name,
        expected_path = "build/bazel/rules/apex/apex_with_java_symbols_used_by_apex_using.xml",
    )

    return test_name

def _generate_notice_file_test(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "GenerateNoticeFile"]
    asserts.true(
        env,
        len(actions) == 1,
        "apex target should have a single GenerateNoticeFile action, found %s" % actions,
    )
    input_json = [f for f in actions[0].inputs.to_list() if f.basename.endswith("_licenses.json")]
    asserts.true(
        env,
        len(input_json) == 1,
        "apex GenerateNoticeFile should have a single input *_license.json file, got %s" % input_json,
    )
    outs = actions[0].outputs.to_list()
    asserts.true(
        env,
        len(outs) == 1 and outs[0].basename == "NOTICE.html.gz",
        "apex GenerateNoticeFile should generate a single NOTICE.html.gz file, got %s" % [o.short_path for o in outs],
    )
    return analysistest.end(env)

apex_generate_notice_file_test = analysistest.make(_generate_notice_file_test)

def _test_apex_generate_notice_file():
    name = "apex_notice_file"
    test_name = name + "_test"
    test_apex(name = name)
    apex_generate_notice_file_test(name = test_name, target_under_test = name)
    return test_name

def apex_test_suite(name):
    native.test_suite(
        name = name,
        tests = [
            _test_canned_fs_config_basic(),
            _test_canned_fs_config_binaries(),
            _test_canned_fs_config_native_shared_libs_arm(),
            _test_canned_fs_config_native_shared_libs_arm64(),
            _test_canned_fs_config_prebuilts(),
            _test_canned_fs_config_prebuilts_sort_order(),
            _test_canned_fs_config_runtime_deps(),
            _test_apex_manifest(),
            _test_apex_manifest_min_sdk_version(),
            _test_apex_manifest_min_sdk_version_current(),
            _test_apex_manifest_dependencies_nodep(),
            _test_apex_manifest_dependencies_cc_binary_bionic_deps(),
            _test_apex_manifest_dependencies_cc_library_shared_bionic_deps(),
            _test_apex_manifest_dependencies_requires(),
            _test_apex_manifest_dependencies_provides(),
            _test_apex_manifest_dependencies_selfcontained(),
            _test_apex_manifest_dependencies_cc_binary(),
            _test_logging_parent_flag(),
            _test_generate_file_contexts(),
            _test_default_apex_manifest_version(),
            _test_min_sdk_version_failure(),
            _test_min_sdk_version_failure_transitive(),
            _test_apex_certificate_none(),
            _test_apex_certificate_name(),
            _test_apex_certificate_label(),
            _test_min_sdk_version_apex_inherit(),
            _test_apex_testonly_with_manifest(),
            _test_apex_provides_base_zip_files(),
            _test_apex_testonly_without_manifest(),
            _test_apex_backing_file(),
            _test_apex_symbols_used_by_apex(),
            _test_apex_installed_files(),
            _test_apex_java_symbols_used_by_apex(),
            _test_apex_generate_notice_file(),
        ],
    )
