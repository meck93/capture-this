import ArgumentParser

@main
struct CaptureThisCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "capture-this-cli",
    abstract: "Screen recording from the command line",
    subcommands: [RecordCommand.self, ListCommand.self, PermissionsCommand.self],
    defaultSubcommand: RecordCommand.self
  )
}
