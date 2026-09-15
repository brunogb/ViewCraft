// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ViewCraft",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "ViewCraft", targets: ["ViewCraft"])
    ],
    targets: [
        .target(name: "ViewCraft")
    ]
)
