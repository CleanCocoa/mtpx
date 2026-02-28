import ArgumentParser
import Foundation
import SwiftMTPAsync

struct Sync: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "sync",
		abstract: "Download changed files from an MTP device directory."
	)

	@Argument(
		help: "Remote source directory, e.g. @sn:/Note/",
		completion: .custom(Completions.remotePath)
	)
	var source: String

	@Argument(help: "Local destination directory")
	var destination: String

	@Flag(
		name: [.customShort("n"), .long],
		help: "Show what would be downloaded without transferring."
	)
	var dryRun = false

	func run() async throws {
		guard let remote = RemotePath(parsing: source) else {
			throw MtpxError.noRemotePath
		}

		try MTP.initialize()
		let resolver = DeviceResolver.live
		let resolved = try await resolver.resolve(alias: remote.alias)
		var raw = resolved.raw
		let session = try MTPSession(opening: &raw)

		let path = remote.path.isEmpty ? "/" : remote.path
		guard let fileInfo = try await session.resolvePath(path, storage: .all) else {
			throw MtpxError.fileNotFound(path)
		}
		guard fileInfo.isDirectory, let folder = fileInfo.folder else {
			print("Sync source must be a directory.")
			throw ExitCode.failure
		}

		let destURL = URL(filePath: destination)
		let stats = try await syncDirectory(
			session: session,
			folder: folder,
			storageId: fileInfo.storageId,
			to: destURL
		)

		if dryRun {
			print("\(stats.downloaded) to download, \(stats.unchanged) unchanged")
		} else {
			print("Synced: \(stats.downloaded) downloaded, \(stats.unchanged) unchanged")
		}
	}

	private func syncDirectory(
		session: MTPSession,
		folder: Folder,
		storageId: StorageID,
		to localURL: URL
	) async throws -> SyncStats {
		if !dryRun {
			try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
		}

		var stats = SyncStats()
		let contents = try await session.contents(of: folder, storage: storageId)
		for item in contents {
			let itemURL = localURL.appending(path: item.name)
			if item.isDirectory, let subfolder = item.folder {
				let sub = try await syncDirectory(
					session: session,
					folder: subfolder,
					storageId: storageId,
					to: itemURL
				)
				stats += sub
			} else if needsDownload(remote: item, localURL: itemURL) {
				if dryRun {
					print(item.name)
				} else {
					try await session.download(
						item.id,
						to: itemURL,
						progress: Transfer.makeProgressHandler(for: item.name)
					)
					print("\nDownloaded: \(item.name)")
				}
				stats.downloaded += 1
			} else {
				stats.unchanged += 1
			}
		}
		return stats
	}

	private func needsDownload(remote: FileInfo, localURL: URL) -> Bool {
		let path = localURL.path
		guard FileManager.default.fileExists(atPath: path) else { return true }

		guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
			let localSize = attrs[.size] as? UInt64,
			let localDate = attrs[.modificationDate] as? Date
		else { return true }

		if localSize != remote.size { return true }
		if remote.modificationDate > localDate { return true }

		return false
	}
}

private struct SyncStats {
	var downloaded = 0
	var unchanged = 0

	static func += (lhs: inout SyncStats, rhs: SyncStats) {
		lhs.downloaded += rhs.downloaded
		lhs.unchanged += rhs.unchanged
	}
}
