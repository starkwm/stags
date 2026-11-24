import Foundation
import Testing

@testable import Stags

@Suite("CLI commands")
struct CLICommandTests {
  @Test("Local commands can run without opening a socket")
  func localCommands() throws {
    for words in [[], ["--help"], ["help"]] {
      guard case .help = try CLICommand.parse(words) else {
        Issue.record("Expected help for \(words)")
        continue
      }
    }
    guard case .version = try CLICommand.parse(["--version"]),
      case .daemon(let path) = try CLICommand.parse(["daemon", "--socket", "/tmp/stags.sock"])
    else {
      Issue.record("Expected local version and daemon commands")
      return
    }
    #expect(path == "/tmp/stags.sock")
  }

  @Test("Client commands preserve tag order, window selection and socket path")
  func clientCommands() throws {
    let cases: [([String], String, [String], UInt32?)] = [
      (["query"], "query", [], nil),
      (["subscribe"], "subscribe", [], nil),
      (["restore"], "restore", [], nil),
      (["stop"], "stop", [], nil),
      (["view", "work", "chat"], "view", ["work", "chat"], nil),
      (["view-toggle", "chat"], "view-toggle", ["chat"], nil),
      (["window", "set", "work", "chat"], "window-set", ["work", "chat"], nil),
      (["window", "--window", "4294967295", "add", "chat"], "window-add", ["chat"], .max),
      (["window", "remove", "work", "--window", "7"], "window-remove", ["work"], 7),
    ]
    for (words, command, tags, id) in cases {
      guard case .client(let request, let path) = try CLICommand.parse(words) else {
        Issue.record("Expected client request for \(words)")
        continue
      }
      #expect(request.command == command)
      #expect(request.arguments == tags)
      #expect(request.value == id.map { .number(Double($0)) })
      #expect(path == NSHomeDirectory() + "/.config/stags/control.sock")
    }
    guard case .client(_, let path) = try CLICommand.parse(["view", "--socket", "~/test", "1"])
    else {
      Issue.record("Expected client request")
      return
    }
    #expect(path == NSHomeDirectory() + "/test")
  }

  @Test(
    "Invalid commands fail before connecting",
    arguments: [
      ["--version", "extra"], ["daemon", "1"], ["query", "--socket"], ["query", "--window", "7"],
      ["view"], ["view-toggle", "1", "2"], ["window", "set"], ["window", "add", "1", "2"],
      ["window", "remove", "1", "--window", "0"], ["window", "set", "1", "--window", "4294967296"],
      ["window", "unknown", "1"], ["unknown"],
    ]
  )
  func invalidCommands(words: [String]) {
    #expect(throws: CLIError.self) { try CLICommand.parse(words) }
  }
}
