// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "mtpx",
	platforms: [.macOS(.v26)],
	products: [
		.executable(name: "mtpx", targets: ["mtpx"])
	],
	dependencies: [
		.package(url: "https://codeberg.org/ctietze/swift-mtp.git", from: "0.11.0"),
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
		.package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0"),
	],
	targets: [
		.executableTarget(
			name: "mtpx",
			dependencies: [
				.product(name: "SwiftMTPAsync", package: "swift-mtp"),
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "TOMLKit", package: "TOMLKit"),
			]
		),
		.testTarget(
			name: "mtpxTests",
			dependencies: ["mtpx"]
		),
	]
)
