// swift-tools-version: 6.0
import PackageDescription

/// 命令行构建入口。日常开发仍以 `make build`（XcodeGen + xcodebuild）为主；
/// 这个 manifest 用于在没有 Xcode GUI / xcodebuild 环境时验证编译与跑测试。
let package = Package(
    name: "ShellCove",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "ShellCove", targets: ["ShellCove"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.99.0")
    ],
    targets: [
        .executableTarget(
            name: "ShellCove",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "ShellCove",
            exclude: ["Info.plist", "ShellCove.entitlements", "Resources"]
        ),
        .testTarget(
            name: "ShellCoveTests",
            dependencies: ["ShellCove"],
            path: "ShellCoveTests"
        )
    ]
)
