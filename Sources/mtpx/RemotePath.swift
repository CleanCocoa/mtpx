struct RemotePath: Equatable, Sendable {
	var alias: String?
	var path: String

	init(alias: String?, path: String) {
		self.alias = alias
		self.path = path
	}

	init?(parsing input: String) {
		if input.hasPrefix("@") {
			guard let colonIndex = input.firstIndex(of: ":") else { return nil }
			let aliasStart = input.index(after: input.startIndex)
			let alias = String(input[aliasStart..<colonIndex])
			guard !alias.isEmpty else { return nil }
			self.alias = alias
			self.path = String(input[input.index(after: colonIndex)...])
		} else if input.hasPrefix(":") {
			self.alias = nil
			self.path = String(input.dropFirst())
		} else {
			return nil
		}
	}
}
