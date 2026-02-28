enum DeviceAlias: Equatable, Sendable, Hashable {
	case serial(String)
	case fallback(vendor: String, product: String, bus: UInt32)
}
