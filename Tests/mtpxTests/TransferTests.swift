import Foundation
import Testing

@testable import mtpx

struct TransferTests {
	@Test func `detect upload direction`() {
		let src = RemotePath(parsing: "./local.txt")
		let dst = RemotePath(parsing: "@phone:/remote.txt")
		#expect(src == nil)
		#expect(dst != nil)
	}

	@Test func `detect download direction`() {
		let src = RemotePath(parsing: "@phone:/remote.txt")
		let dst = RemotePath(parsing: "./local.txt")
		#expect(src != nil)
		#expect(dst == nil)
	}

	@Test func `both local is error`() {
		let src = RemotePath(parsing: "./a.txt")
		let dst = RemotePath(parsing: "./b.txt")
		#expect(src == nil)
		#expect(dst == nil)
	}

	@Test func `both remote is error`() {
		let src = RemotePath(parsing: "@a:/x")
		let dst = RemotePath(parsing: "@b:/y")
		#expect(src != nil)
		#expect(dst != nil)
	}

	@Test func `MtpxError descriptions`() {
		#expect(MtpxError.bothLocal.description.contains("local"))
		#expect(MtpxError.bothRemote.description.contains("not supported"))
		#expect(MtpxError.fileNotFound("/x").description.contains("/x"))
	}

	@Test func `MtpxError exit codes`() {
		#expect(MtpxError.bothLocal.exitCode == 2)
		#expect(MtpxError.fileNotFound("/x").exitCode == 3)
		#expect(MtpxError.transferFailed("err").exitCode == 4)
	}
}
