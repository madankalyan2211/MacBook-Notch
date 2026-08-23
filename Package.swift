// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacBookNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacBookNotch",
            targets: ["MacBookNotch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacBookNotch",
            path: "Sources",
            resources: []
        )
    ]
)
