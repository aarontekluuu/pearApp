// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PearProtocolApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PearProtocolApp",
            targets: ["PearProtocolApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2", from: "1.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
        .package(url: "https://github.com/argentlabs/web3.swift", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "PearProtocolApp",
            dependencies: [
                .product(name: "WalletConnect", package: "WalletConnectSwiftV2"),
                .product(name: "WalletConnectSign", package: "WalletConnectSwiftV2"),
                "Alamofire",
                "Starscream",
                "KeychainAccess",
                .product(name: "web3.swift", package: "web3.swift")
            ]
        )
    ]
)
