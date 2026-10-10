load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "KWGramCore",
    module_name = "KWGramCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
