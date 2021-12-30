// swift-tools-version:5.5

import PackageDescription

let package = Package(
	name: "Plains",
	platforms: [.iOS(.v12), .macOS(.v11)],
	products: [
		.library(name: "Plains", targets: ["Plains"])
	],
	targets: [
		.target(
			name: "Vendor",
			publicHeadersPath: "."
		),
		.target(
			name: "Plains",
			dependencies: ["Vendor"]
			//linkerSettings: [
				//.linkedLibrary("/Users/amy/Library/Developer/Xcode/DerivedData/Zebra-aolcehphmwdyovczlpdagygtienb/SourcePackages/checkouts/Plains/libapt-pkg.6.0.0-iOS.tbd", .when(platforms: [.iOS])),
				//.linkedLibrary("libapt-pkg.6.0.0-macOS.tbd", .when(platforms: [.macOS]))
			//]
		)
	],
	cxxLanguageStandard: .gnucxx20
)
