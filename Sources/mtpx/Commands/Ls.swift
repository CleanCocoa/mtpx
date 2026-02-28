import ArgumentParser
import Foundation
import SwiftMTPAsync

struct Ls: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ls",
		abstract: "List contents of a remote directory."
	)

	@Argument(
		help: "Remote path, e.g. @phone:/DCIM or :/Music",
		completion: .custom(Completions.remotePath)
	)
	var remotePath: String

	func run() async throws {
		guard let remote = RemotePath(parsing: remotePath) else {
			print("Invalid remote path: \(remotePath)")
			throw ExitCode.failure
		}

		try MTP.initialize()
		let resolver = DeviceResolver.live
		let resolved = try await resolver.resolve(alias: remote.alias)
		var raw = resolved.raw
		let session = try MTPSession(opening: &raw)

		let path = remote.path.isEmpty ? "/" : remote.path
		let storageId = StorageID.all

		let entries: [FileInfo]
		if path == "/" {
			entries = try await session.contents(of: .root, storage: storageId)
		} else if let target = try await session.resolvePath(path, storage: storageId) {
			guard target.isDirectory, let folder = target.folder else {
				printFileInfo(target)
				return
			}
			entries = try await session.contents(of: folder, storage: storageId)
		} else {
			print("Path not found: \(path)")
			throw ExitCode.failure
		}

		let sorted = entries.sorted(.directoriesFirst)
		for entry in sorted {
			printFileInfo(entry)
		}
	}

	private func printFileInfo(_ info: FileInfo) {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
		let date = dateFormatter.string(from: info.modificationDate)
		let typeIndicator = info.isDirectory ? "d" : "-"
		let size = info.isDirectory ? "<DIR>" : formatSize(info.size)
		print("\(typeIndicator) \(size.padding(toLength: 10, withPad: " ", startingAt: 0)) \(date) \(info.name)")
	}

	private func formatSize(_ bytes: UInt64) -> String {
		if bytes < 1024 { return "\(bytes) B" }
		let kb = Double(bytes) / 1024
		if kb < 1024 { return String(format: "%.1f KB", kb) }
		let mb = kb / 1024
		if mb < 1024 { return String(format: "%.1f MB", mb) }
		let gb = mb / 1024
		return String(format: "%.1f GB", gb)
	}
}
