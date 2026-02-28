import ArgumentParser

@main
struct Mtpx: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "mtpx",
		abstract: "Transfer files to and from MTP devices.",
		version: "0.3.0"
	)
}
