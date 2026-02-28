import Foundation
import Testing

@testable import mtpx

struct DeviceConfigTests {
	@Test func `load config with serial alias`() throws {
		let toml = """
			default = "phone"

			[aliases.phone]
			serial = "ABC123"
			"""
		let url = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID()).toml")
		try toml.write(to: url, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: url) }

		let config = try DeviceConfig.load(from: url)
		#expect(config.defaultDevice == "phone")
		#expect(config.aliases["phone"] == .serial("ABC123"))
	}

	@Test func `load config with fallback alias`() throws {
		let toml = """
			[aliases.camera]
			vendor = "Nikon"
			product = "D850"
			bus = 2
			"""
		let url = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID()).toml")
		try toml.write(to: url, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: url) }

		let config = try DeviceConfig.load(from: url)
		#expect(config.defaultDevice == nil)
		#expect(config.aliases["camera"] == .fallback(vendor: "Nikon", product: "D850", bus: 2))
	}

	@Test func `round-trip save and load`() throws {
		var config = DeviceConfig()
		config.defaultDevice = "tablet"
		config.aliases["tablet"] = .serial("XYZ789")
		config.aliases["cam"] = .fallback(vendor: "Canon", product: "EOS", bus: 3)

		let url = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID()).toml")
		defer { try? FileManager.default.removeItem(at: url) }

		try config.save(to: url)
		let loaded = try DeviceConfig.load(from: url)
		#expect(loaded.defaultDevice == "tablet")
		#expect(loaded.aliases["tablet"] == .serial("XYZ789"))
		#expect(loaded.aliases["cam"] == .fallback(vendor: "Canon", product: "EOS", bus: 3))
	}

	@Test func `configURL uses XDG_CONFIG_HOME`() {
		let url = DeviceConfig.configURL
		#expect(url.path().hasSuffix("mtpx/config.toml"))
	}

	@Test func `save creates directories`() throws {
		let dir = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID())/nested/deep")
		let url = dir.appending(path: "config.toml")
		defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent().deletingLastPathComponent()) }

		var config = DeviceConfig()
		config.aliases["x"] = .serial("S")
		try config.save(to: url)
		#expect(FileManager.default.fileExists(atPath: url.path()))
	}
}
