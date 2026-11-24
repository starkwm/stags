import Foundation
import StagsCore
import StarkIPC

@main
struct Stags {
  private static let usage = """
    Usage: stags daemon [--socket PATH]
           stags query [--socket PATH]
           stags subscribe [--socket PATH]
           stags view TAG... [--socket PATH]
           stags view-toggle TAG [--socket PATH]
           stags window set TAG... [--window ID] [--socket PATH]
           stags window add TAG [--window ID] [--socket PATH]
           stags window remove TAG [--window ID] [--socket PATH]
           stags restore [--socket PATH]
           stags stop [--socket PATH]
           stags --version
    """

  static func main() {
    do {
      try run(Array(CommandLine.arguments.dropFirst()))
    } catch {
      fputs("stags: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }

  private static func run(_ arguments: [String]) throws {
    switch try CLICommand.parse(arguments) {
    case .help:
      print(usage)
    case .version:
      print("stags version \(Version.current.value)")
    case .daemon(let socketPath):
      try MainActor.assumeIsolated { try TagDaemon().run(socketPath: socketPath) }
    case .client(let request, let socketPath):
      try send(request, socketPath: socketPath)
    }
  }

  private static func send(_ request: ControlRequest, socketPath: String) throws {
    let streaming = request.command == "subscribe"
    let client = try SocketClient(path: socketPath, serviceName: "stags", streaming: streaming)
    try client.send(request)
    repeat {
      let response = try client.receive(ControlResponse.self)
      if let value = response.value {
        let encoder = JSONEncoder()
        encoder.outputFormatting = streaming ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
      }
      if let error = response.error { throw CLIError.daemon(error) }
      if !response.ok { throw CLIError.daemon("Command failed.") }
    } while streaming
  }
}
