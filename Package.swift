// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetSpeedBar",
    platforms: [
        .macOS(.v13) // MenuBarExtra requires macOS 13 Ventura+
    ],
    targets: [
        .executableTarget(
            name: "NetSpeedBar",
            path: "Sources/NetSpeedBar"
        )
    ]
)
