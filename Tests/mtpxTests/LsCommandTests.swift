import Foundation
import Testing

@testable import mtpx

struct LsCommandTests {
	@Test func `parse remote path for ls`() {
		let r = RemotePath(parsing: "@phone:/DCIM")
		#expect(r?.alias == "phone")
		#expect(r?.path == "/DCIM")
	}

	@Test func `parse root path`() {
		let r = RemotePath(parsing: ":/")
		#expect(r?.alias == nil)
		#expect(r?.path == "/")
	}

	@Test func `reject local path`() {
		#expect(RemotePath(parsing: "/local/path") == nil)
	}

	@Test func `parse nested remote path`() {
		let r = RemotePath(parsing: "@cam:/DCIM/100CANON")
		#expect(r?.alias == "cam")
		#expect(r?.path == "/DCIM/100CANON")
	}
}
