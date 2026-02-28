import ArgumentParser

@main
struct Mtpx: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "mtpx",
		abstract: "Transfer files to and from MTP devices.",
		discussion: """
			Device aliases are stored in:
			  ~/.config/mtpx/config.toml

			Enable tab completion for remote paths:
			  mtpx --generate-completion-script zsh \
			    > ~/.zsh/completions/_mtpx
			""",
		version: "0.4.0",
		subcommands: [Transfer.self, Ls.self, DeviceCommand.self],
		defaultSubcommand: Transfer.self
	)
}
