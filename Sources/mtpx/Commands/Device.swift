import ArgumentParser
import Foundation
import SwiftMTPAsync

struct DeviceCommand: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "device",
		abstract: "Manage device aliases.",
		subcommands: [List.self, Add.self, Remove.self, Default.self]
	)

	struct List: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "List saved device aliases and connected devices.")

		func run() async throws {
			let config = (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig()
			if config.aliases.isEmpty {
				print("No device aliases configured.")
			} else {
				for (name, alias) in config.aliases.sorted(by: { $0.key < $1.key }) {
					let isDefault = config.defaultDevice == name ? " (default)" : ""
					switch alias {
					case .serial(let serial):
						print("\(name): serial:\(serial)\(isDefault)")
					case .fallback(let vendor, let product, let bus):
						print("\(name): \(vendor) \(product)@\(bus)\(isDefault)")
					}
				}
			}

			if let devices = try? {
				try MTP.initialize()
				return try MTP.detectDevices()
			}(), !devices.isEmpty {
				if !config.aliases.isEmpty { print() }
				print("Connected devices:")
				for (i, d) in devices.enumerated() {
					print("  \(i + 1). \(d.vendor) \(d.product)")
				}
				print("\nRun 'mtpx device add' to save a device alias.")
			} else if config.aliases.isEmpty {
				print("\nConnect a device and run 'mtpx device add' to get started.")
			}
		}
	}

	struct Add: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Add a device alias.")

		@Argument(help: "Name for the alias (prompted if omitted).")
		var name: String?

		func run() async throws {
			try MTP.initialize()
			let devices = try MTP.detectDevices()
			guard !devices.isEmpty else {
				throw DeviceResolverError.noDevices
			}

			let selected: DetectedDevice
			if devices.count == 1 {
				selected = devices[0]
				print("Found \(selected.vendor) \(selected.product)")
			} else {
				print("Connected devices:\n")
				for (i, d) in devices.enumerated() {
					print("  \(i + 1). \(d.vendor) \(d.product)")
				}
				print("\nSelect device (1-\(devices.count)): ", terminator: "")
				guard let line = readLine(), let choice = Int(line), (1...devices.count).contains(choice) else {
					print("Cancelled.")
					return
				}
				selected = devices[choice - 1]
			}

			let name: String
			if let given = self.name {
				name = given
			} else {
				print("Alias: ", terminator: "")
				guard let line = readLine(), !line.isEmpty else {
					print("Cancelled.")
					return
				}
				name = line
			}

			var raw = selected
			let session = try MTPSession(opening: &raw)
			let serialNumber = await session.serialNumber

			let alias: DeviceAlias
			if let serial = serialNumber, !serial.isEmpty {
				alias = .serial(serial)
			} else {
				alias = .fallback(
					vendor: selected.vendor,
					product: selected.product,
					bus: selected.busLocation.rawValue
				)
			}

			var config = (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig()
			config.aliases[name] = alias
			try config.save(to: DeviceConfig.configURL)
			print("Saved alias '\(name)'.")
		}
	}

	struct Remove: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Remove a device alias.")

		@Argument(help: "Alias to remove.", completion: .custom(Completions.deviceAlias))
		var name: String

		func run() throws {
			var config = (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig()
			guard config.aliases.removeValue(forKey: name) != nil else {
				print("Alias '\(name)' not found.")
				throw ExitCode.failure
			}
			if config.defaultDevice == name {
				config.defaultDevice = nil
			}
			try config.save(to: DeviceConfig.configURL)
			print("Removed alias '\(name)'.")
		}
	}

	struct Default: AsyncParsableCommand {
		static let configuration = CommandConfiguration(abstract: "Get or set the default device.")

		@Argument(help: "Alias to set as default.", completion: .custom(Completions.deviceAlias))
		var name: String?

		@Flag(help: "Clear the default device.")
		var clear = false

		func run() throws {
			var config = (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig()

			if clear {
				config.defaultDevice = nil
				try config.save(to: DeviceConfig.configURL)
				print("Default device cleared.")
				return
			}

			guard let name else {
				if let defaultDevice = config.defaultDevice {
					print(defaultDevice)
				} else {
					print("No default device set.")
				}
				return
			}

			guard config.aliases[name] != nil else {
				print("Alias '\(name)' not found. Add it first with 'mtpx device add \(name)'.")
				throw ExitCode.failure
			}

			config.defaultDevice = name
			try config.save(to: DeviceConfig.configURL)
			print("Default device set to '\(name)'.")
		}
	}
}
