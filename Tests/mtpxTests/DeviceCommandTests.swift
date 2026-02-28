import Foundation
import Testing

@testable import mtpx

struct DeviceCommandTests {
	@Test func `list shows empty message`() {
		let config = DeviceConfig()
		#expect(config.aliases.isEmpty)
	}

	@Test func `remove clears default when removing default device`() throws {
		let url = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID()).toml")
		defer { try? FileManager.default.removeItem(at: url) }

		var config = DeviceConfig()
		config.aliases["phone"] = .serial("ABC")
		config.defaultDevice = "phone"
		try config.save(to: url)

		var loaded = try DeviceConfig.load(from: url)
		loaded.aliases.removeValue(forKey: "phone")
		if loaded.defaultDevice == "phone" {
			loaded.defaultDevice = nil
		}
		try loaded.save(to: url)

		let final = try DeviceConfig.load(from: url)
		#expect(final.aliases["phone"] == nil)
		#expect(final.defaultDevice == nil)
	}

	@Test func `default requires existing alias`() throws {
		let config = DeviceConfig()
		#expect(config.aliases["nonexistent"] == nil)
	}

	@Test func `add alias and set default`() throws {
		let url = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID()).toml")
		defer { try? FileManager.default.removeItem(at: url) }

		var config = DeviceConfig()
		config.aliases["tablet"] = .serial("XYZ")
		config.defaultDevice = "tablet"
		try config.save(to: url)

		let loaded = try DeviceConfig.load(from: url)
		#expect(loaded.aliases["tablet"] == .serial("XYZ"))
		#expect(loaded.defaultDevice == "tablet")
	}
}
