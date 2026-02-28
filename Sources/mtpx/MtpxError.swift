import Foundation

enum MtpxError: Error, CustomStringConvertible {
	case noRemotePath
	case bothLocal
	case bothRemote
	case fileNotFound(String)
	case transferFailed(String)
	case directoryCreationFailed(String)

	var description: String {
		switch self {
		case .noRemotePath:
			"At least one path must be remote (prefixed with @alias: or :)"
		case .bothLocal:
			"Both paths are local. Use cp for local-to-local copies."
		case .bothRemote:
			"Device-to-device transfer is not supported."
		case .fileNotFound(let path):
			"File not found: \(path)"
		case .transferFailed(let msg):
			"Transfer failed: \(msg)"
		case .directoryCreationFailed(let msg):
			"Could not create directory: \(msg)"
		}
	}

	var exitCode: Int32 {
		switch self {
		case .noRemotePath, .bothLocal, .bothRemote: 2
		case .fileNotFound: 3
		case .transferFailed: 4
		case .directoryCreationFailed: 5
		}
	}
}
