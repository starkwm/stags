import Foundation
import StagsCore
import StarkIPC

enum CLICommand {
  case help
  case version
  case daemon(socketPath: String)
  case client(ControlRequest, socketPath: String)

  static func parse(_ arguments: [String]) throws -> Self {
    guard let command = arguments.first else {
      return .help
    }
    if command == "--help" || command == "help" {
      return .help
    }
    if command == "--version" {
      guard arguments.count == 1 else { throw CLIError.invalidArguments }
      return .version
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
      return .daemon(socketPath: socketPath)
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

    return .client(request, socketPath: socketPath)
  }
}

enum CLIError: Error, LocalizedError {
  case invalidArguments
  case daemon(String)

  var errorDescription: String? {
    switch self {
    case .invalidArguments: "Invalid arguments. Run stags help for usage."
    case .daemon(let message): message
    }
  }
}
