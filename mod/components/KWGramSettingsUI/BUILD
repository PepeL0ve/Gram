load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "KWGramAppleFrameworks",
    sdk_frameworks = [
        "MapKit",
    ],
)

swift_library(
    name = "KWGramSettingsUI",
    module_name = "KWGramSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":KWGramAppleFrameworks",
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/MergeLists",
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/ItemListUI",
        "//submodules/PresentationDataUtils",
        "//submodules/AccountContext",
        "//submodules/PromptUI",
        "//submodules/UndoUI",
        "//submodules/OverlayStatusController",
        "//submodules/TelegramUI/Components/KWGram/KWGramCore",
        "//submodules/TelegramUI/Components/KWGram/PhantomGiftKit",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
