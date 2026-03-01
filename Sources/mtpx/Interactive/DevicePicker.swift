import SwiftMTPAsync

enum DevicePicker {
	static func pick(from devices: [DetectedDevice], config: DeviceConfig) throws -> ResolvedDevice? {
		guard !devices.isEmpty else { return nil }

		print("Multiple MTP devices found:\n")
		for (index, device) in devices.enumerated() {
			print("  \(index + 1). \(device.vendor) \(device.product)")
		}
		print("\nSelect device (1-\(devices.count)): ", terminator: "")

		guard let line = readLine(), let choice = Int(line), (1...devices.count).contains(choice) else {
			return nil
		}

		let selected = devices[choice - 1]
		let alias = DeviceAlias.fallback(
			vendor: selected.vendor,
			product: selected.product,
			bus: selected.busLocation.rawValue
		)
		return ResolvedDevice(raw: selected, alias: alias)
	}
}
