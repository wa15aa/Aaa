// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "StreakEngine",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "StreakEngine", targets: ["StreakEngine"]),
        .library(name: "SteadyCore", targets: ["SteadyCore"])
    ],
    targets: [
        .target(name: "StreakEngine"),
        .target(name: "SteadyCore", dependencies: ["StreakEngine"]),
        .executableTarget(name: "streakcheck", dependencies: ["StreakEngine"]),
        .executableTarget(name: "repocheck", dependencies: ["SteadyCore"]),
        .executableTarget(name: "backupcheck", dependencies: ["SteadyCore"]),
        .testTarget(name: "StreakEngineTests", dependencies: ["StreakEngine"])
    ]
)
