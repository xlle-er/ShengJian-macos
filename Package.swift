// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ShengJian", platforms: [.macOS(.v13)],
    dependencies: [.package(path: "Vendor/SharedKit")],
    targets: [.executableTarget(name: "ShengJian", dependencies: [.product(name: "ShengKit", package: "SharedKit")])])
