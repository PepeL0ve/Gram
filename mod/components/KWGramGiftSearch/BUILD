load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "KWGramGiftSearch",
    module_name = "KWGramGiftSearch",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/Display",
        "//submodules/TelegramUI/Components/KWGram/KWGramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
