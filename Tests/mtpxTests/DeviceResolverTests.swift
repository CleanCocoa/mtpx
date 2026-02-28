import SwiftMTPAsync
import Testing

@testable import mtpx

private func makeRawDevice(
	vendor: String = "TestVendor",
	product: String = "TestProduct",
	bus: UInt32 = 1,
	devnum: UInt8 = 1,
	vendorId: UInt16 = 0,
	productId: UInt16 = 0
) -> RawDevice {
	RawDevice(
		busLocation: BusLocation(rawValue: bus),
		devnum: DeviceNumber(rawValue: devnum),
		vendor: vendor,
		vendorId: VendorID(rawValue: vendorId),
		product: product,
		productId: ProductID(rawValue: productId)
	)
}

private func makeResolver(
	devices: [RawDevice] = [],
	env: @escaping @Sendable (String) -> String? = { _ in nil },
	config: DeviceConfig = DeviceConfig(),
	isTTY: Bool = false,
	pickDevice: @escaping @Sendable ([RawDevice], DeviceConfig) throws -> ResolvedDevice? = { _, _ in nil },
	getSerial: @escaping @Sendable (RawDevice) async throws -> String? = { _ in nil }
) -> DeviceResolver {
	DeviceResolver(
		detectDevices: { devices },
		environment: env,
		loadConfig: { config },
		isTTY: isTTY,
		pickDevice: pickDevice,
		getSerial: getSerial
	)
}

struct DeviceResolverTests {
	@Test func `resolve throws noDevices when none connected`() async {
		let resolver = makeResolver()
		await #expect(throws: DeviceResolverError.noDevices) {
			try await resolver.resolve()
		}
	}

	@Test func `resolve returns single device when exactly one connected`() async throws {
		let device = makeRawDevice()
		let resolver = makeResolver(devices: [device])
		let result = try await resolver.resolve()
		#expect(result.raw.vendor == "TestVendor")
		#expect(result.raw.product == "TestProduct")
		#expect(result.alias == .fallback(vendor: "TestVendor", product: "TestProduct", bus: 1))
	}

	@Test func `resolve uses MTPX_DEVICE env var with fallback alias`() async throws {
		let device = makeRawDevice(vendor: "Samsung", product: "Galaxy", bus: 5)
		var config = DeviceConfig()
		config.aliases["phone"] = .fallback(vendor: "Samsung", product: "Galaxy", bus: 5)
		let resolver = makeResolver(
			devices: [device],
			env: { $0 == "MTPX_DEVICE" ? "phone" : nil },
			config: config
		)
		let result = try await resolver.resolve()
		#expect(result.raw.vendor == "Samsung")
		#expect(result.alias == .fallback(vendor: "Samsung", product: "Galaxy", bus: 5))
	}

	@Test func `resolve throws aliasNotConnected when env var alias not found`() async {
		var config = DeviceConfig()
		config.aliases["phone"] = .fallback(vendor: "Samsung", product: "Galaxy", bus: 5)
		let resolver = makeResolver(
			devices: [],
			env: { $0 == "MTPX_DEVICE" ? "phone" : nil },
			config: config
		)
		await #expect(throws: DeviceResolverError.aliasNotConnected("phone")) {
			try await resolver.resolve()
		}
	}

	@Test func `resolve uses serial alias with getSerial closure`() async throws {
		let device = makeRawDevice(vendor: "Sony", product: "Walkman", bus: 3)
		var config = DeviceConfig()
		config.aliases["walkman"] = .serial("SN12345")
		let resolver = makeResolver(
			devices: [device],
			env: { $0 == "MTPX_DEVICE" ? "walkman" : nil },
			config: config,
			getSerial: { _ in "SN12345" }
		)
		let result = try await resolver.resolve()
		#expect(result.raw.product == "Walkman")
		#expect(result.alias == .serial("SN12345"))
	}

	@Test func `resolve uses config default when multiple devices`() async throws {
		let devices = [
			makeRawDevice(vendor: "A", product: "DevA", bus: 1),
			makeRawDevice(vendor: "B", product: "DevB", bus: 2, devnum: 2),
		]
		var config = DeviceConfig()
		config.defaultDevice = "main"
		config.aliases["main"] = .fallback(vendor: "B", product: "DevB", bus: 2)
		let resolver = makeResolver(devices: devices, config: config)
		let result = try await resolver.resolve()
		#expect(result.raw.vendor == "B")
	}

	@Test func `resolve throws ambiguousDevice when not TTY and multiple devices`() async {
		let devices = [
			makeRawDevice(vendor: "A", product: "DevA", bus: 1),
			makeRawDevice(vendor: "B", product: "DevB", bus: 2, devnum: 2),
		]
		let resolver = makeResolver(devices: devices, isTTY: false)
		await #expect(throws: DeviceResolverError.ambiguousDevice(2)) {
			try await resolver.resolve()
		}
	}

	@Test func `resolve calls pickDevice when TTY and multiple devices`() async throws {
		let devices = [
			makeRawDevice(vendor: "A", product: "DevA", bus: 1),
			makeRawDevice(vendor: "B", product: "DevB", bus: 2, devnum: 2),
		]
		let resolver = makeResolver(
			devices: devices,
			isTTY: true,
			pickDevice: { devs, _ in
				let raw = devs[1]
				return ResolvedDevice(
					raw: raw,
					alias: .fallback(vendor: raw.vendor, product: raw.product, bus: raw.busLocation.rawValue)
				)
			}
		)
		let result = try await resolver.resolve()
		#expect(result.raw.vendor == "B")
	}

	@Test func `resolve throws cancelled when picker returns nil`() async {
		let devices = [
			makeRawDevice(vendor: "A", product: "DevA", bus: 1),
			makeRawDevice(vendor: "B", product: "DevB", bus: 2, devnum: 2),
		]
		let resolver = makeResolver(devices: devices, isTTY: true)
		await #expect(throws: DeviceResolverError.cancelled) {
			try await resolver.resolve()
		}
	}

	@Test func `resolve fuzzy matches product name`() async throws {
		let devices = [
			makeRawDevice(vendor: "Samsung", product: "Galaxy S24", bus: 1),
			makeRawDevice(vendor: "Google", product: "Pixel 8", bus: 2, devnum: 2),
		]
		let resolver = makeResolver(devices: devices)
		let result = try await resolver.resolve(alias: "pixel")
		#expect(result.raw.product == "Pixel 8")
	}

	@Test func `resolve throws when fuzzy match is ambiguous`() async {
		let devices = [
			makeRawDevice(vendor: "Samsung", product: "Galaxy S24", bus: 1),
			makeRawDevice(vendor: "Samsung", product: "Galaxy Tab", bus: 2, devnum: 2),
		]
		let resolver = makeResolver(devices: devices)
		await #expect(throws: DeviceResolverError.aliasNotConnected("galaxy")) {
			try await resolver.resolve(alias: "galaxy")
		}
	}

	@Test func `resolve prefers explicit alias over env var`() async throws {
		let device = makeRawDevice(vendor: "A", product: "DevA", bus: 1)
		var config = DeviceConfig()
		config.aliases["explicit"] = .fallback(vendor: "A", product: "DevA", bus: 1)
		config.aliases["fromenv"] = .fallback(vendor: "A", product: "DevA", bus: 1)
		let resolver = makeResolver(
			devices: [device],
			env: { $0 == "MTPX_DEVICE" ? "fromenv" : nil },
			config: config
		)
		let result = try await resolver.resolve(alias: "explicit")
		#expect(result.alias == .fallback(vendor: "A", product: "DevA", bus: 1))
	}
}
