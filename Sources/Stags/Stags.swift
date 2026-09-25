import Foundation
import StagsCore
import StarkIPC

@main
struct Stags {
  static func main() {
    do {
      try run(Array(CommandLine.arguments.dropFirst()))
    } catch {
      fputs("stags: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }

  private static func run(_ arguments: [String]) throws {
    guard let command = arguments.first else {
      print(usage)
      return
    }
    if command == "--help" || command == "help" {
      print(usage)
      return
    }

    var words = Array(arguments.dropFirst())
    var socketPath = TagDaemon.defaultSocketPath()
    if let index = words.firstIndex(of: "--socket") {
      guard index + 1 < words.count else { throw CLIError.invalidArguments }
      socketPath = (words[index + 1] as NSString).expandingTildeInPath
      words.removeSubrange(index...index + 1)
    }

    if command == "daemon" {
      guard words.isEmpty else { throw CLIError.invalidArguments }
      let daemon = try MainActor.assumeIsolated { try TagDaemon() }
      try MainActor.assumeIsolated { try daemon.run(socketPath: socketPath) }
      return
    }

    var windowID: UInt32?
    if let index = words.firstIndex(of: "--window") {
      guard index + 1 < words.count, let parsed = UInt32(words[index + 1]), parsed != 0 else {
        throw CLIError.invalidArguments
      }
      windowID = parsed
      words.removeSubrange(index...index + 1)
    }

    let request: ControlRequest
    let streaming = command == "subscribe"
    switch command {
    case "query", "subscribe", "restore", "stop":
      guard words.isEmpty, windowID == nil else { throw CLIError.invalidArguments }
      request = ControlRequest(command: command)
    case "view":
      guard !words.isEmpty, windowID == nil else { throw CLIError.invalidArguments }
      request = ControlRequest(command: "view", arguments: words)
    case "view-toggle":
      guard words.count == 1, windowID == nil else { throw CLIError.invalidArguments }
      request = ControlRequest(command: "view-toggle", arguments: words)
    case "window":
      guard let action = words.first, ["set", "add", "remove"].contains(action) else {
        throw CLIError.invalidArguments
      }
      let tags = Array(words.dropFirst())
      guard !tags.isEmpty, action == "set" || tags.count == 1 else {
        throw CLIError.invalidArguments
      }
      request = ControlRequest(
        command: "window-\(action)",
        arguments: tags,
        value: windowID.map { .number(Double($0)) }
      )
    default:
      throw CLIError.invalidArguments
    }

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
    """
}

private enum CLIError: Error, LocalizedError {
  case invalidArguments
  case daemon(String)

  var errorDescription: String? {
    switch self {
    case .invalidArguments: "Invalid arguments. Run stags help for usage."
    case .daemon(let message): message
    }
  }
}
