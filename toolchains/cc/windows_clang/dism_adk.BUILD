load("@rules_cc//cc:defs.bzl", "cc_import", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_import(
    name = "dism_libs",
    hdrs = ["Include/dismapi.h"],
    includes = ["Include"],
    interface_library = "Lib/amd64/dismapi.lib",
    system_provided = True,
)

cc_library(
    name = "dism_adk",
    deps = [":dism_libs"],
)
