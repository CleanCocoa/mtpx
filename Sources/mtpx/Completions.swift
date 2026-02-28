import ArgumentParser
import Foundation
import SwiftMTPAsync

enum Completions {
	static func remotePath(
		_ words: [String],
		_ index: Int,
		_ prefix: String
	) async -> [String] {
		await complete(words: words, index: index, prefix: prefix, localFallback: false)
	}

	static func transferPath(
		_ words: [String],
		_ index: Int,
		_ prefix: String
	) async -> [String] {
		await complete(words: words, index: index, prefix: prefix, localFallback: true)
	}

	static func deviceAlias(
		_ words: [String],
		_ index: Int,
		_ prefix: String
	) -> [String] {
		let config = (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig()
		let lowered = prefix.lowercased()
		return config.aliases.keys
			.filter { lowered.isEmpty || $0.lowercased().hasPrefix(lowered) }
			.sorted()
	}

	private static func complete(
		words: [String],
		index: Int,
		prefix: String,
		localFallback: Bool
	) async -> [String] {
		let isBash =
			CompletionShell.requesting == .bash
		let input =
			isBash
			? bashReconstructInput(words: words, index: index, prefix: prefix)
			: prefix
		let wasSplit = input != prefix

		if input.hasPrefix("@") && !input.contains(":") {
			let completions = aliasCompletions(matching: String(input.dropFirst()))
			if isBash && !wasSplit {
				return completions
			}
			return zshEscape(completions)
		}

		if input.hasPrefix("@") || input.hasPrefix(":") {
			let completions = await pathCompletions(for: input)
			if isBash {
				return completions.map { bashPathPortion($0) }
			}
			return zshEscape(completions)
		}

		if localFallback {
			return localPathCompletions(prefix: input)
		}

		return []
	}

	private static func bashReconstructInput(
		words: [String],
		index: Int,
		prefix: String
	) -> String {
		var result = prefix
		var i = index - 1

		guard i >= 0, words[i] == ":" else { return result }
		result = ":" + result
		i -= 1

		if i >= 0, words[i].hasPrefix("@") {
			result = words[i] + result
		}

		return result
	}

	private static func bashPathPortion(_ completion: String) -> String {
		guard let colonIndex = completion.lastIndex(of: ":") else {
			return completion
		}
		return String(completion[completion.index(after: colonIndex)...])
	}

	private static func zshEscape(_ completions: [String]) -> [String] {
		guard CompletionShell.requesting == .zsh else { return completions }
		return completions.map { $0.replacingOccurrences(of: ":", with: "\\:") }
	}

	private static func aliasCompletions(matching prefix: String) -> [String] {
		let config = (try? DeviceConfig.load(from: DeviceConfig.configURL)) ?? DeviceConfig()
		let lowered = prefix.lowercased()
		return config.aliases.keys
			.filter { lowered.isEmpty || $0.lowercased().hasPrefix(lowered) }
			.sorted()
			.map { "@\($0):" }
	}

	private static let cacheTTL: TimeInterval = 30
	private static let cacheDir =
		FileManager.default.temporaryDirectory.appending(path: "mtpx-completions")

	private static func cachedCompletions(
		alias: String?,
		parentPath: String
	) -> [String]? {
		let key = "\(alias ?? "_")_\(parentPath)"
			.replacingOccurrences(of: "/", with: "_")
		let file = cacheDir.appending(path: key)
		guard
			let attrs = try? FileManager.default.attributesOfItem(atPath: file.path()),
			let modified = attrs[.modificationDate] as? Date,
			Date().timeIntervalSince(modified) < cacheTTL,
			let data = try? Data(contentsOf: file)
		else { return nil }
		return try? JSONDecoder().decode([String].self, from: data)
	}

	private static func cacheCompletions(
		_ completions: [String],
		alias: String?,
		parentPath: String
	) {
		let key = "\(alias ?? "_")_\(parentPath)"
			.replacingOccurrences(of: "/", with: "_")
		try? FileManager.default.createDirectory(
			at: cacheDir,
			withIntermediateDirectories: true
		)
		let file = cacheDir.appending(path: key)
		if let data = try? JSONEncoder().encode(completions) {
			try? data.write(to: file)
		}
	}

	private static func muteStderr() -> Int32 {
		fflush(stderr)
		let saved = dup(STDERR_FILENO)
		let devNull = open("/dev/null", O_WRONLY)
		if devNull >= 0 {
			dup2(devNull, STDERR_FILENO)
			close(devNull)
		}
		return saved
	}

	private static func restoreStderr(_ saved: Int32) {
		guard saved >= 0 else { return }
		fflush(stderr)
		dup2(saved, STDERR_FILENO)
		close(saved)
	}

	private static func pathCompletions(for input: String) async -> [String] {
		guard let remote = RemotePath(parsing: input) else { return [] }

		let aliasPrefix: String
		if let alias = remote.alias {
			aliasPrefix = "@\(alias):"
		} else {
			aliasPrefix = ":"
		}

		let path = remote.path.isEmpty ? "/" : remote.path
		let parentPath: String
		let namePrefix: String

		if path.hasSuffix("/") {
			parentPath = path
			namePrefix = ""
		} else {
			let components = path.split(separator: "/", omittingEmptySubsequences: true)
			if components.count <= 1 {
				parentPath = "/"
				namePrefix = String(components.first ?? "")
			} else {
				parentPath = "/" + components.dropLast().joined(separator: "/") + "/"
				namePrefix = String(components.last!)
			}
		}

		if let cached = cachedCompletions(alias: remote.alias, parentPath: parentPath) {
			let loweredPrefix = namePrefix.lowercased()
			return cached.filter {
				loweredPrefix.isEmpty || $0.lowercased().contains(loweredPrefix)
			}
		}

		let saved = muteStderr()
		defer { restoreStderr(saved) }

		do {
			try MTP.initialize()
			var resolver = DeviceResolver.live
			resolver.isTTY = false
			let resolved = try await resolver.resolve(alias: remote.alias)
			var raw = resolved.raw
			let session = try MTPSession(opening: &raw)

			let entries: [FileInfo]
			if parentPath == "/" {
				entries = try await session.contents(of: .root, storage: .all)
			} else {
				guard let target = try await session.resolvePath(parentPath, storage: .all),
					target.isDirectory, let folder = target.folder
				else {
					return []
				}
				entries = try await session.contents(of: folder, storage: .all)
			}

			let allCompletions =
				entries
				.sorted {
					$0.name.localizedStandardCompare($1.name) == .orderedAscending
				}
				.map { entry in
					let suffix = entry.isDirectory ? "/" : ""
					let entryPath =
						parentPath == "/"
						? "/\(entry.name)\(suffix)"
						: "\(parentPath)\(entry.name)\(suffix)"
					return "\(aliasPrefix)\(entryPath)"
				}

			cacheCompletions(allCompletions, alias: remote.alias, parentPath: parentPath)

			let loweredPrefix = namePrefix.lowercased()
			return allCompletions.filter {
				loweredPrefix.isEmpty || $0.lowercased().contains(loweredPrefix)
			}
		} catch {
			return []
		}
	}

	private static func localPathCompletions(prefix: String) -> [String] {
		let expanded =
			prefix.hasPrefix("~")
			? NSString(string: prefix).expandingTildeInPath
			: prefix

		let dir: URL
		let namePrefix: String

		if expanded.isEmpty {
			dir = URL(filePath: FileManager.default.currentDirectoryPath)
			namePrefix = ""
		} else if expanded.hasSuffix("/") {
			dir = URL(filePath: expanded)
			namePrefix = ""
		} else {
			dir = URL(filePath: expanded).deletingLastPathComponent()
			namePrefix = URL(filePath: expanded).lastPathComponent
		}

		guard
			let contents = try? FileManager.default.contentsOfDirectory(
				at: dir,
				includingPropertiesForKeys: [.isDirectoryKey]
			)
		else {
			return []
		}

		let showHidden = namePrefix.hasPrefix(".")
		return
			contents
			.filter { item in
				let name = item.lastPathComponent
				if !showHidden && name.hasPrefix(".") { return false }
				return namePrefix.isEmpty || name.hasPrefix(namePrefix)
			}
			.sorted {
				$0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
					== .orderedAscending
			}
			.compactMap { item in
				let isDir =
					(try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
				let name = item.lastPathComponent
				let result: String
				if prefix.isEmpty {
					result = name
				} else if prefix.hasSuffix("/") {
					result = prefix + name
				} else {
					let parent = NSString(string: prefix).deletingLastPathComponent as String
					result = parent.isEmpty ? name : parent + "/" + name
				}
				return isDir ? result + "/" : result
			}
	}
}
