import Testing

@testable import mtpx

struct RemotePathTests {
	@Test func `parse @alias:/path`() {
		let r = RemotePath(parsing: "@phone:/DCIM")
		#expect(r == RemotePath(alias: "phone", path: "/DCIM"))
	}

	@Test func `parse :/path without alias`() {
		let r = RemotePath(parsing: ":/Music")
		#expect(r == RemotePath(alias: nil, path: "/Music"))
	}

	@Test func `local path returns nil`() {
		#expect(RemotePath(parsing: "./local/file.txt") == nil)
		#expect(RemotePath(parsing: "/absolute/path") == nil)
		#expect(RemotePath(parsing: "relative") == nil)
	}

	@Test func `empty alias returns nil`() {
		#expect(RemotePath(parsing: "@:/path") == nil)
	}

	@Test func `empty path is valid`() {
		let r = RemotePath(parsing: "@phone:")
		#expect(r == RemotePath(alias: "phone", path: ""))
	}

	@Test func `alias with nested path`() {
		let r = RemotePath(parsing: "@cam:/DCIM/100CANON/IMG_001.jpg")
		#expect(r == RemotePath(alias: "cam", path: "/DCIM/100CANON/IMG_001.jpg"))
	}
}
