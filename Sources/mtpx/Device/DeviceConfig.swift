import Foundation
import TOMLKit

struct DeviceConfig: Equatable, Sendable {
	var defaultDevice: String?
	var aliases: [String: DeviceAlias]

	init() {
		self.defaultDevice = nil
		self.aliases = [:]
	}

	static var configURL: URL {
		let base: URL
		if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
			base = URL(filePath: xdg)
		} else {
			base = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config")
		}
		return base.appending(path: "mtpx/config.toml")
	}

	static func load(from url: URL) throws -> DeviceConfig {
		let data = try Data(contentsOf: url)
		let content = String(decoding: data, as: UTF8.self)
		let table = try TOMLTable(string: content)
		var config = DeviceConfig()
		config.defaultDevice = table["default"]?.string
		if let aliasesTable = table["aliases"]?.table {
			for (name, value) in aliasesTable {
				guard let entry = value.table else { continue }
				if let serial = entry["serial"]?.string {
					config.aliases[name] = .serial(serial)
				} else if let vendor = entry["vendor"]?.string,
					let product = entry["product"]?.string,
					let bus = entry["bus"]?.int
				{
					config.aliases[name] = .fallback(vendor: vendor, product: product, bus: UInt32(bus))
				}
			}
		}
		return config
	}

	func save(to url: URL) throws {
		let table = TOMLTable()
		if let defaultDevice {
			table["default"] = defaultDevice
		}
		if !aliases.isEmpty {
			let aliasesTable = TOMLTable()
			for (name, alias) in aliases.sorted(by: { $0.key < $1.key }) {
				let entry = TOMLTable()
				switch alias {
				case .serial(let serial):
					entry["serial"] = serial
				case .fallback(let vendor, let product, let bus):
					entry["vendor"] = vendor
					entry["product"] = product
					entry["bus"] = Int64(bus)
				}
				aliasesTable[name] = entry
			}
			table["aliases"] = aliasesTable
		}
		let content = table.convert()
		let dir = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		try content.write(to: url, atomically: true, encoding: .utf8)
	}
}
