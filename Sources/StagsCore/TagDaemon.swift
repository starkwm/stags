import CoreFoundation
import Darwin
import Foundation
import StarkIPC
import StarkSkyLight

@MainActor
public final class TagDaemon {
  nonisolated public static func defaultSocketPath() -> String {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: ".config/stags/control.sock").path
  }

  private let dispatcher: TagCommandDispatcher
  private var server: SocketServer<ControlRequest, ControlResponse>?
  private var isStopping = false
  private var runLoop: CFRunLoop?
  private var timer: Timer?
  private var signalSources: [any DispatchSourceSignal] = []

  public convenience init(journalURL: URL = ParkingJournal.defaultURL()) throws {
    try self.init(
      dispatcher: TagCommandDispatcher(
        journal: ParkingJournal(url: journalURL),
        spaces: SpaceClient(),
        desktop: WindowAccess()
      )
    )
  }

  init(dispatcher: TagCommandDispatcher) {
    self.dispatcher = dispatcher
  }

  public func run(socketPath: String = TagDaemon.defaultSocketPath()) throws {
    guard WindowAccess.requestTrust() else { throw DaemonError.accessibilityPermission }
    try start(socketPath: socketPath)
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self, !self.isStopping else { return }
        self.dispatcher.poll()
      }
    }
    installSignalHandlers()
    runLoop = CFRunLoopGetCurrent()
    CFRunLoopRun()
    runLoop = nil
  }

  func start(socketPath: String) throws {
    let server = SocketServer<ControlRequest, ControlResponse>(
      path: socketPath,
      serviceName: "stags",
      errorResponse: { ControlResponse(ok: false, error: $0.localizedDescription) },
      handler: { [weak self] request in
        guard let self else {
          return SocketReply(ControlResponse(ok: false, error: "Daemon is stopping."))
        }
        return await self.handle(request)
      }
    )
    try server.start()
    self.server = server
    isStopping = false
    dispatcher.onChange = { [weak server] in server?.publish($0) }
    dispatcher.poll()
  }

  private func handle(_ request: ControlRequest) -> SocketReply<ControlResponse> {
    guard !isStopping else {
      return SocketReply(ControlResponse(ok: false, error: "Daemon is stopping."))
    }
    switch dispatcher.dispatch(request) {
    case .reply(let response):
      return SocketReply(response)
    case .subscribe(let response):
      return SocketReply(response, keepOpen: true)
    case .shutdown(let response):
      isStopping = true
      return SocketReply(response) { [weak self] in
        Task { @MainActor [weak self] in self?.shutdown() }
      }
    }
  }

  private func shutdown() {
    timer?.invalidate()
    timer = nil
    for source in signalSources { source.cancel() }
    signalSources = []
    server?.stop()
    server = nil
    if let runLoop { CFRunLoopStop(runLoop) }
  }

  private func installSignalHandlers() {
    for number in [SIGINT, SIGTERM] {
      Darwin.signal(number, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
      source.setEventHandler { [weak self] in
        Task { @MainActor [weak self] in self?.stopForSignal() }
      }
      signalSources.append(source)
      source.resume()
    }
  }

  private func stopForSignal() {
    guard !isStopping else { return }
    let failures = dispatcher.restoreAll()
    if failures.isEmpty {
      isStopping = true
      shutdown()
    } else {
      fputs("stags: \(failures.joined(separator: " "))\n", stderr)
    }
  }
}

public enum DaemonError: Error, LocalizedError {
  case accessibilityPermission
  case activeSpaceUnavailable
  case invalidArguments
  case noFocusedWindow
  case unknownCommand

  public var errorDescription: String? {
    switch self {
    case .accessibilityPermission: "Grant Accessibility permission to stags before starting."
    case .activeSpaceUnavailable: "The active macOS Space is unavailable. Retry the command."
    case .invalidArguments: "Invalid command arguments."
    case .noFocusedWindow: "No focused window was found. Use --window <id>."
    case .unknownCommand: "Unknown command."
    }
  }
}
