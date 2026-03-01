#if canImport(Darwin)
	import Darwin
#elseif canImport(Glibc)
	@preconcurrency import Glibc
#elseif canImport(Musl)
	@preconcurrency import Musl
#endif

func flushStdout() {
	fflush(stdout)
}

func muteStderr() -> Int32 {
	fflush(stderr)
	let saved = dup(STDERR_FILENO)
	let devNull = open("/dev/null", O_WRONLY)
	if devNull >= 0 {
		dup2(devNull, STDERR_FILENO)
		close(devNull)
	}
	return saved
}

func restoreStderr(_ saved: Int32) {
	guard saved >= 0 else { return }
	fflush(stderr)
	dup2(saved, STDERR_FILENO)
	close(saved)
}
