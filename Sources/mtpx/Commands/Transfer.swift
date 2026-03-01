import ArgumentParser
import Foundation
import SwiftMTPAsync

struct Transfer: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "transfer",
		abstract: "Transfer files between local filesystem and MTP device."
	)

	@Argument(
		help: "Source path (local or @alias:/remote)",
		completion: .custom(Completions.transferPath)
	)
	var source: String

	@Argument(
		help: "Destination path (local or @alias:/remote)",
		completion: .custom(Completions.transferPath)
	)
	var destination: String

	@Flag(name: .shortAndLong, help: "Transfer directories recursively.")
	var recursive = false

	func run() async throws {
		let srcRemote = RemotePath(parsing: source)
		let dstRemote = RemotePath(parsing: destination)

		switch (srcRemote, dstRemote) {
		case (.some, .some):
			throw MtpxError.bothRemote
		case (nil, nil):
			throw MtpxError.bothLocal
		case (.some(let remote), nil):
			try await download(remote: remote, localPath: destination)
		case (nil, .some(let remote)):
			try await upload(localPath: source, remote: remote)
		}
	}

	private func download(remote: RemotePath, localPath: String) async throws {
		try MTP.initialize()
		let resolver = DeviceResolver.live
		let resolved = try await resolver.resolve(alias: remote.alias)
		var raw = resolved.raw
		let session = try MTPSession(opening: &raw)

		let path = remote.path.isEmpty ? "/" : remote.path
		guard let fileInfo = try await session.resolvePath(path, storage: .all) else {
			throw MtpxError.fileNotFound(path)
		}

		let destURL = URL(filePath: localPath)

		if fileInfo.isDirectory {
			guard recursive else {
				print("Use -r to transfer directories.")
				throw ExitCode.failure
			}
			try await downloadDirectory(
				session: session,
				folder: fileInfo.folder!,
				storageId: fileInfo.storageId,
				to: destURL
			)
		} else {
			try await session.download(
				fileInfo.id,
				to: destURL,
				progress: Self.makeProgressHandler(for: fileInfo.name)
			)
			print("\nDownloaded: \(fileInfo.name)")
		}
	}

	private func upload(localPath: String, remote: RemotePath) async throws {
		try MTP.initialize()
		let resolver = DeviceResolver.live
		let resolved = try await resolver.resolve(alias: remote.alias)
		var raw = resolved.raw
		let session = try MTPSession(opening: &raw)

		let sourceURL = URL(filePath: localPath)
		let isDir = (try? sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

		let remotePath = remote.path.isEmpty ? "/" : remote.path
		let storageId = StorageID.all

		let parentFolder: Folder
		let fileName: String

		if remotePath == "/" {
			parentFolder = .root
			fileName = sourceURL.lastPathComponent
		} else {
			let components = remotePath.split(separator: "/", omittingEmptySubsequences: true)
			if components.count > 1 {
				let parentPath = "/" + components.dropLast().joined(separator: "/")
				if let parent = try await session.resolvePath(parentPath, storage: storageId) {
					parentFolder = parent.folder ?? .root
				} else {
					parentFolder = try await createIntermediateDirectories(
						session: session,
						path: parentPath,
						storageId: storageId
					)
				}
				fileName = String(components.last!)
			} else {
				parentFolder = .root
				fileName = String(components.first ?? Substring(sourceURL.lastPathComponent))
			}
		}

		if isDir {
			guard recursive else {
				print("Use -r to transfer directories.")
				throw ExitCode.failure
			}
			try await uploadDirectory(
				session: session,
				localURL: sourceURL,
				parentFolder: parentFolder,
				storageId: storageId
			)
		} else {
			let result = try await session.upload(
				from: sourceURL,
				to: parentFolder,
				storage: storageId,
				as: fileName,
				progress: Self.makeProgressHandler(for: fileName)
			)
			print("\nUploaded: \(result.name)")
		}
	}

	private func downloadDirectory(
		session: MTPSession,
		folder: Folder,
		storageId: StorageID,
		to localURL: URL
	) async throws {
		try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
		let contents = try await session.contents(of: folder, storage: storageId)
		for item in contents {
			let itemURL = localURL.appending(path: item.name)
			if item.isDirectory, let subfolder = item.folder {
				try await downloadDirectory(
					session: session,
					folder: subfolder,
					storageId: storageId,
					to: itemURL
				)
			} else {
				try await session.download(
					item.id,
					to: itemURL,
					progress: Self.makeProgressHandler(for: item.name)
				)
				print("\nDownloaded: \(item.name)")
			}
		}
	}

	private func uploadDirectory(
		session: MTPSession,
		localURL: URL,
		parentFolder: Folder,
		storageId: StorageID
	) async throws {
		let dirName = localURL.lastPathComponent
		let dirInfo = try await session.makeDirectory(named: dirName, in: parentFolder, storage: storageId)
		guard let newFolder = dirInfo.folder else { return }

		let items = try FileManager.default.contentsOfDirectory(
			at: localURL,
			includingPropertiesForKeys: [.isDirectoryKey]
		)
		for item in items {
			let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
			if isDir {
				try await uploadDirectory(
					session: session,
					localURL: item,
					parentFolder: newFolder,
					storageId: storageId
				)
			} else {
				let result = try await session.upload(
					from: item,
					to: newFolder,
					storage: storageId,
					progress: Self.makeProgressHandler(for: item.lastPathComponent)
				)
				print("\nUploaded: \(result.name)")
			}
		}
	}

	private func createIntermediateDirectories(
		session: MTPSession,
		path: String,
		storageId: StorageID
	) async throws -> Folder {
		let components = path.split(separator: "/", omittingEmptySubsequences: true)
		var current = Folder.root
		var currentPath = ""

		for component in components {
			currentPath += "/\(component)"
			if let existing = try await session.resolvePath(currentPath, storage: storageId) {
				guard let folder = existing.folder else {
					throw MtpxError.directoryCreationFailed(currentPath)
				}
				current = folder
			} else {
				let created = try await session.makeDirectory(
					named: String(component),
					in: current,
					storage: storageId
				)
				guard let folder = created.folder else {
					throw MtpxError.directoryCreationFailed(currentPath)
				}
				current = folder
			}
		}
		return current
	}

	static func makeProgressHandler(for name: String) -> @Sendable (UInt64, UInt64) -> ProgressAction {
		nonisolated(unsafe) var lastPct = -1
		return { sent, total in
			guard total > 0 else { return .continue }
			let pct = Int(Double(sent) / Double(total) * 100)
			if pct != lastPct {
				lastPct = pct
				print("\r\(name): \(pct)%", terminator: "    ")
				flushStdout()
			}
			return .continue
		}
	}
}
