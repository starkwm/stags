import Foundation
import StarkIPC
import StarkSkyLight
import Testing

@testable import StagsCore

@MainActor
@Suite("Tag daemon")
struct TagDaemonTests {
  @Test("A failed restore or stop retains the original frame and allows a retry over the socket")
  func retryRestoration() async throws {
    let desktop = TestDesktop()
    let window = desktop.window
    let original = try #require(window.frame)
    let journalURL = temporaryJournal()
    defer { try? FileManager.default.removeItem(at: journalURL.deletingLastPathComponent()) }
    let daemon = try TagDaemon(dispatcher: desktop.dispatcher(journalURL))
    defer { withExtendedLifetime(daemon) {} }
    let path = journalURL.deletingLastPathComponent().appending(path: "control.sock").path
    try daemon.start(socketPath: path)

    let parked = try await exchange(
      ControlRequest(command: "view", arguments: ["work"]),
      path: path
    )
    try #require(parked.ok)
    #expect(window.frame?.origin != original.origin)
    window.allowsMove = false

    for command in ["stop", "restore"] {
      let failed = try await exchange(ControlRequest(command: command), path: path)
      #expect(!failed.ok)
      #expect(failed.error == "Could not restore window \(window.key.id).")
      let record = try ParkingJournal(url: journalURL).entries[window.key]
      #expect(record?.originalFrame == WindowFrame(original))
      let query = try await exchange(ControlRequest(command: "query"), path: path)
      #expect(query.ok)
      #expect(query.value == failed.value)
    }

    window.allowsMove = true
    let stopped = try await exchange(ControlRequest(command: "stop"), path: path)
    #expect(stopped.ok)
    #expect(window.frame == original)
    #expect(try ParkingJournal(url: journalURL).entries.isEmpty)

    let deadline = ContinuousClock.now + .seconds(2)
    while FileManager.default.fileExists(atPath: path), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(!FileManager.default.fileExists(atPath: path))
  }

  @Test("Subscribers receive the initial snapshot and only changed snapshots")
  func subscribe() async throws {
    let journalURL = temporaryJournal()
    defer { try? FileManager.default.removeItem(at: journalURL.deletingLastPathComponent()) }
    let desktop = TestDesktop()
    let daemon = try TagDaemon(dispatcher: desktop.dispatcher(journalURL))
    defer { withExtendedLifetime(daemon) {} }
    let path = journalURL.deletingLastPathComponent().appending(path: "control.sock").path
    try daemon.start(socketPath: path)
    try await checkSubscription(path: path)
  }

  @Test(
    "Switching Spaces during discovery or recovery prevents a stale restore",
    arguments: [false, true]
  )
  func spaceChangesDuringPoll(duringDiscovery: Bool) throws {
    let desktop = TestDesktop()
    let window = desktop.window
    let journalURL = temporaryJournal()
    defer { try? FileManager.default.removeItem(at: journalURL.deletingLastPathComponent()) }
    var journal = try ParkingJournal(url: journalURL)
    let original = WindowFrame(CGRect(x: 1, y: 2, width: 150, height: 90))
    try journal.record(original, for: window.key, bundleID: window.bundleID)
    let dispatcher = try desktop.dispatcher(journalURL)
    // The window still belongs to its original Space after the desktop switches away.
    let switchSpace = { desktop.spaces.activeSpaceID = SpaceID(rawValue: 2) }
    if duringDiscovery {
      desktop.onDiscover = switchSpace
    } else {
      desktop.spaces.onMembershipQuery = switchSpace
    }

    dispatcher.poll()
    #expect(window.moves.isEmpty)
    #expect(try ParkingJournal(url: journalURL).entries[window.key]?.originalFrame == original)

    desktop.onDiscover = nil
    desktop.spaces.onMembershipQuery = nil
    guard case .reply(let query) = dispatcher.dispatch(ControlRequest(command: "query")),
      case .object(let fields) = query.value
    else {
      Issue.record("Expected a query snapshot")
      return
    }
    #expect(fields["windows"] == .array([]))
    desktop.spaces.activeSpaceID = desktop.windowSpace
    dispatcher.poll()
    #expect(window.moves == [original.rect.origin])
    #expect(try ParkingJournal(url: journalURL).entries.isEmpty)
  }

  private func temporaryJournal() -> URL {
    URL(filePath: "/tmp").appending(path: "stags-\(UUID())/parking.json")
  }
}

@concurrent
private func exchange(_ request: ControlRequest, path: String) async throws -> ControlResponse {
  try send(request, path: path)
}

private func send(_ request: ControlRequest, path: String) throws -> ControlResponse {
  let client = try SocketClient(path: path)
  try client.send(request)
  return try client.receive(ControlResponse.self)
}

@concurrent
private func checkSubscription(path: String) async throws {
  // Keep the normal client's read timeout so a missing publication fails the test.
  let subscriber = try SocketClient(path: path)
  try subscriber.send(ControlRequest(command: "subscribe"))
  let initial = try subscriber.receive(ControlResponse.self)
  try #require(initial.ok)
  #expect(try send(ControlRequest(command: "query"), path: path).value == initial.value)
  let same = try send(ControlRequest(command: "view", arguments: ["1"]), path: path)
  #expect(same.value == initial.value)
  let changed = try send(ControlRequest(command: "window-add", arguments: ["chat"]), path: path)
  try #require(changed.ok && changed.value != initial.value)
  #expect(try subscriber.receive(ControlResponse.self).value == changed.value)
}

@MainActor
private final class TestDesktop: WindowEnvironment {
  let window = TestWindow()
  let windowSpace = SpaceID(rawValue: 1)
  let spaces: FakeSpaceQuery
  var onDiscover: (() -> Void)?

  init() {
    spaces = FakeSpaceQuery(memberships: [window.key.id: [windowSpace]])
    spaces.activeSpaceID = windowSpace
  }

  func dispatcher(_ journalURL: URL) throws -> TagCommandDispatcher {
    try TagCommandDispatcher(
      journal: ParkingJournal(url: journalURL),
      spaces: spaces,
      desktop: self
    )
  }

  func discover(in activeSpace: SpaceID, using spaces: any SpaceQuerying)
    -> [WindowKey: any ManagedWindow]
  {
    onDiscover?()
    return activeSpace == windowSpace ? [window.key: window] : [:]
  }

  func liveWindowIDs() -> Set<UInt32>? { [window.key.id] }
  func isRunning(pid: Int32) -> Bool { pid == window.key.pid }
  func focusedWindowID() -> UInt32? { window.key.id }
  func screenFrames() -> [CGRect] { [CGRect(x: 0, y: 0, width: 800, height: 600)] }
}

@MainActor
private final class TestWindow: ManagedWindow {
  let key = WindowKey(pid: 100, id: 20)
  let bundleID = "test.app"
  let appName = "Test"
  let isMinimized = false
  let isFullscreen = false
  var frame: CGRect? = CGRect(x: 100, y: 80, width: 150, height: 90)
  var moves: [CGPoint] = []
  var allowsMove = true

  func move(to point: CGPoint) -> Bool {
    moves.append(point)
    guard allowsMove else { return false }
    frame?.origin = point
    return true
  }

  func focus() {}
}
