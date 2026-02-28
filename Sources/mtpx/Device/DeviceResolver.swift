import Foundation
import SwiftMTPAsync

struct ResolvedDevice: Sendable {
	var raw: RawDevice
	var alias: DeviceAlias

	static func alias(for raw: RawDevice, serialNumber: String?) -> DeviceAlias {
		if let serial = serialNumber, !serial.isEmpty {
			return .serial(serial)
		}
		return .fallback(vendor: raw.vendor, product: raw.product, bus: raw.busLocation.rawValue)
	}
}

struct DeviceResolver: Sendable {
	var detectDevices: @Sendable () throws -> [RawDevice]
	var environment: @Sendable (String) -> String?
	var loadConfig: @Sendable () throws -> DeviceConfig
	var isTTY: Bool
	var pickDevice: @Sendable ([RawDevice], DeviceConfig) throws -> ResolvedDevice?
	var getSerial: @Sendable (RawDevice) async throws -> String?

	static var live: DeviceResolver {
		DeviceResolver(
			detectDevices: { try MTP.detectDevices() },
			environment: { ProcessInfo.processInfo.environment[$0] },
			loadConfig: { (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig() },
			isTTY: isatty(STDIN_FILENO) == 1,
			pickDevice: { devices, config in
				try DevicePicker.pick(from: devices, config: config)
			},
			getSerial: { raw in
				var mutable = raw
				let session = try MTPSession(opening: &mutable)
				return await session.serialNumber
			}
		)
	}

	func resolve(alias requestedAlias: String? = nil) async throws -> ResolvedDevice {
		let config = (try? loadConfig()) ?? DeviceConfig()
		let devices = try detectDevices()

		let aliasName = requestedAlias ?? environment("MTPX_DEVICE")
		if let aliasName {
			if let deviceAlias = config.aliases[aliasName] {
				if let match = try await findMatch(in: devices, for: deviceAlias) {
					return ResolvedDevice(raw: match, alias: deviceAlias)
				}
				throw DeviceResolverError.aliasNotConnected(aliasName)
			}

			let lowered = aliasName.lowercased()
			let fuzzyMatches = devices.filter { $0.product.lowercased().contains(lowered) }
			if fuzzyMatches.count == 1 {
				let raw = fuzzyMatches[0]
				return ResolvedDevice(
					raw: raw,
					alias: .fallback(vendor: raw.vendor, product: raw.product, bus: raw.busLocation.rawValue)
				)
			}

			throw DeviceResolverError.aliasNotConnected(aliasName)
		}

		if devices.count == 1 {
			let raw = devices[0]
			return ResolvedDevice(
				raw: raw,
				alias: .fallback(vendor: raw.vendor, product: raw.product, bus: raw.busLocation.rawValue)
			)
		}

		if let defaultName = config.defaultDevice, let deviceAlias = config.aliases[defaultName] {
			if let match = try await findMatch(in: devices, for: deviceAlias) {
				return ResolvedDevice(raw: match, alias: deviceAlias)
			}
		}

		guard !devices.isEmpty else {
			throw DeviceResolverError.noDevices
		}
		guard isTTY else {
			throw DeviceResolverError.ambiguousDevice(devices.count)
		}
		guard let picked = try pickDevice(devices, config) else {
			throw DeviceResolverError.cancelled
		}
		return picked
	}

	private func findMatch(in devices: [RawDevice], for alias: DeviceAlias) async throws -> RawDevice? {
		switch alias {
		case .serial(let serial):
			for device in devices {
				if let deviceSerial = try await getSerial(device), deviceSerial == serial {
					return device
				}
			}
			return nil
		case .fallback(let vendor, let product, let bus):
			return devices.first {
				$0.vendor == vendor && $0.product == product && $0.busLocation.rawValue == bus
			}
		}
	}
}

enum DeviceResolverError: Error, Equatable {
	case noDevices
	case aliasNotConnected(String)
	case ambiguousDevice(Int)
	case cancelled
}
