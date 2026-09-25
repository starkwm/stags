import AppKit
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

  private var state = TagState()
  private var journal: ParkingJournal
  private let spaces: any SpaceQuerying
  private var windows: [WindowKey: ManagedWindow] = [:]
  private var activeWindowKeys: Set<WindowKey> = []
  private var activeSpaceID: SpaceID?
  private var missingPolls: [WindowKey: Int] = [:]
  private var errors: [WindowKey: String] = [:]
  private var recoveryKeys: Set<WindowKey>
  private var isStopping = false
  private var timer: Timer?
  private var server: SocketServer<ControlRequest, ControlResponse>?
  private var lastPublished: JSONValue?
  private var signalSources: [any DispatchSourceSignal] = []

  public init(journalURL: URL = ParkingJournal.defaultURL()) throws {
    journal = try ParkingJournal(url: journalURL)
    spaces = try SpaceClient()
    recoveryKeys = Set(journal.entries.keys)
  }

  public func run(socketPath: String = TagDaemon.defaultSocketPath()) throws {
    guard WindowAccess.requestTrust() else {
      throw DaemonError.accessibilityPermission
    }

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
    poll()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in self?.poll() }
    }
    installSignalHandlers()
    CFRunLoopRun()
  }

  private func handle(_ request: ControlRequest) -> SocketReply<ControlResponse> {
    do {
      refreshActiveSpace()
      if ["view", "view-toggle", "window-set", "window-add", "window-remove", "restore"].contains(
        request.command
      ) {
        guard activeSpaceID != nil else { throw DaemonError.activeSpaceUnavailable }
      }
      switch request.command {
      case "query":
        return SocketReply(ControlResponse(value: snapshot()))
      case "subscribe":
        return SocketReply(ControlResponse(value: snapshot()), keepOpen: true)
      case "view":
        try state.setView(Set(request.arguments), primary: request.arguments.first)
        return SocketReply(reconcileResponse())
      case "view-toggle":
        guard let tag = request.arguments.first, request.arguments.count == 1 else {
          throw DaemonError.invalidArguments
        }
        try state.toggleView(tag)
        return SocketReply(reconcileResponse())
      case "window-set":
        let key = try selectedWindow(request)
        try state.setTags(Set(request.arguments), for: key)
        return SocketReply(reconcileResponse())
      case "window-add":
        guard let tag = request.arguments.first, request.arguments.count == 1 else {
          throw DaemonError.invalidArguments
        }
        let key = try selectedWindow(request)
        try state.addTag(tag, to: key)
        return SocketReply(reconcileResponse())
      case "window-remove":
        guard let tag = request.arguments.first, request.arguments.count == 1 else {
          throw DaemonError.invalidArguments
        }
        let key = try selectedWindow(request)
        try state.removeTag(tag, from: key)
        return SocketReply(reconcileResponse())
      case "restore":
        try state.setView(state.knownTags)
        let failures = restoreAll()
        publishIfChanged()
        return SocketReply(response(for: failures))
      case "stop":
        isStopping = true
        let failures = restoreAll()
        if !failures.isEmpty { isStopping = false }
        let response = response(for: failures)
        return SocketReply(
          response,
          onComplete: { [weak self] in
            guard response.ok else { return }
            Task { @MainActor [weak self] in self?.shutdown() }
          }
        )
      default:
        throw DaemonError.unknownCommand
      }
    } catch {
      return SocketReply(ControlResponse(ok: false, error: error.localizedDescription))
    }
  }

  private func selectedWindow(_ request: ControlRequest) throws -> WindowKey {
    let id: UInt32?
    if case .number(let value) = request.value {
      guard value.isFinite, value >= 1, value <= Double(UInt32.max),
        value.rounded() == value
      else { throw DaemonError.invalidArguments }
      id = UInt32(value)
    } else {
      id = WindowAccess.focusedWindowID()
    }
    guard let id else { throw DaemonError.noFocusedWindow }
    guard let activeSpaceID,
      let key = activeWindowKeys.first(where: { $0.id == id }),
      WindowAccess.belongsToActiveSpace(id, activeSpace: activeSpaceID, using: spaces)
    else {
      throw TagError.unknownWindow
    }
    return key
  }

  private func poll() {
    guard !isStopping else { return }
    activeSpaceID = try? spaces.activeSpace()
    guard let activeSpaceID else {
      activeWindowKeys = []
      publishIfChanged()
      return
    }
    let discovered = WindowAccess.discover(in: activeSpaceID, using: spaces)
    guard (try? spaces.activeSpace()) == activeSpaceID else {
      activeWindowKeys = []
      publishIfChanged()
      return
    }
    activeWindowKeys = Set(discovered.keys)
    windows.merge(discovered) { _, new in new }
    for key in discovered.keys {
      state.adopt(key)
      missingPolls.removeValue(forKey: key)
    }

    for key in recoveryKeys where activeWindowKeys.contains(key) {
      guard let window = windows[key], let entry = journal.entries[key] else { continue }
      guard WindowAccess.belongsToActiveSpace(key.id, activeSpace: activeSpaceID, using: spaces)
      else { continue }
      guard window.bundleID == entry.bundleID else {
        errors[key] = "Recovery identity no longer matches this window."
        continue
      }
      if restore(window, to: entry.originalFrame) {
        recoveryKeys.remove(key)
      }
    }

    let liveIDs = (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]])
      .map { Set($0.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }) }
    for key in Array(windows.keys) where discovered[key] == nil {
      missingPolls[key, default: 0] += 1
      guard missingPolls[key, default: 0] >= 3 else { continue }
      guard liveIDs?.contains(key.id) == false else { continue }
      windows.removeValue(forKey: key)
      missingPolls.removeValue(forKey: key)
      state.forget(key)
      errors.removeValue(forKey: key)
      recoveryKeys.remove(key)
      try? journal.remove(key)
    }
    for key in journal.entries.keys where NSRunningApplication(processIdentifier: key.pid) == nil {
      recoveryKeys.remove(key)
      try? journal.remove(key)
    }

    _ = reconcile()
    publishIfChanged()
  }

  private func refreshActiveSpace() {
    if (try? spaces.activeSpace()) != activeSpaceID { poll() }
  }

  private func reconcileResponse() -> ControlResponse {
    let failures = reconcile()
    if failures.isEmpty { focusVisibleWindow() }
    publishIfChanged()
    return response(for: failures)
  }

  private func reconcile() -> [String] {
    guard let activeSpaceID, (try? spaces.activeSpace()) == activeSpaceID else {
      return [DaemonError.activeSpaceUnavailable.localizedDescription]
    }
    var failures: [String] = []
    for key in activeWindowKeys.sorted(by: { ($0.pid, $0.id) < ($1.pid, $1.id) }) {
      guard let window = windows[key] else { continue }
      guard WindowAccess.belongsToActiveSpace(key.id, activeSpace: activeSpaceID, using: spaces)
      else { continue }
      let desiredVisible = state.isVisible(key)
      if desiredVisible, let entry = journal.entries[key] {
        if entry.bundleID != window.bundleID || !restore(window, to: entry.originalFrame) {
          failures.append("Could not restore window \(key.id).")
        }
      } else if !desiredVisible && window.isFullscreen {
        errors[key] = "Native fullscreen windows cannot be parked."
        failures.append("Native fullscreen window \(key.id) cannot be parked.")
      } else if !desiredVisible && !window.isMinimized
        && !isActuallyParked(window)
      {
        if !park(window) { failures.append("Could not park window \(key.id).") }
      }
    }
    return failures
  }

  private func park(_ window: ManagedWindow) -> Bool {
    let key = window.key
    guard let currentFrame = window.frame, currentFrame.width > 0, currentFrame.height > 0 else {
      errors[key] = "Cannot read window frame."
      return false
    }
    let frame = journal.entries[key]?.originalFrame.rect ?? currentFrame
    if let entry = journal.entries[key], entry.bundleID != window.bundleID {
      errors[key] = "Recovery identity no longer matches this window."
      return false
    }
    let screens = screenFrames()
    guard
      let display = screens.max(by: {
        ParkingGeometry.visibleArea(of: frame, on: [$0])
          < ParkingGeometry.visibleArea(of: frame, on: [$1])
      })
    else {
      errors[key] = "No display is available."
      return false
    }
    let position = ParkingGeometry.position(for: frame, on: display, among: screens)
    if journal.entries[key] == nil {
      do { try journal.record(WindowFrame(frame), for: key, bundleID: window.bundleID) } catch {
        errors[key] = "Could not record original frame: \(error.localizedDescription)"
        return false
      }
    }
    guard WindowAccess.move(window.element, to: position), let actual = window.frame else {
      errors[key] = "Accessibility refused the parking move."
      return false
    }
    let visibleArea = ParkingGeometry.visibleArea(of: actual, on: screens)
    guard visibleArea <= max(actual.width, actual.height) * 2 else {
      errors[key] = "The app kept the window on screen."
      return false
    }
    errors.removeValue(forKey: key)
    return true
  }

  private func restore(_ window: ManagedWindow, to frame: WindowFrame) -> Bool {
    let key = window.key
    guard WindowAccess.move(window.element, to: frame.rect.origin), let actual = window.frame,
      abs(actual.minX - frame.x) <= 4, abs(actual.minY - frame.y) <= 4
    else {
      errors[key] = "Could not restore the original window position."
      return false
    }
    do { try journal.remove(key) } catch {
      errors[key] = "Window moved back, but the recovery journal could not be updated."
      return false
    }
    errors.removeValue(forKey: key)
    return true
  }

  private func restoreAll() -> [String] {
    if journal.entries.isEmpty { return [] }
    guard let activeSpaceID, (try? spaces.activeSpace()) == activeSpaceID else {
      return [DaemonError.activeSpaceUnavailable.localizedDescription]
    }
    var failures: [String] = []
    for (key, entry) in journal.entries {
      guard activeWindowKeys.contains(key),
        WindowAccess.belongsToActiveSpace(key.id, activeSpace: activeSpaceID, using: spaces)
      else {
        failures.append("Window \(key.id) is outside the active macOS Space.")
        continue
      }
      guard let window = windows[key] else {
        failures.append("Window \(key.id) is not accessible.")
        continue
      }
      guard window.bundleID == entry.bundleID else {
        failures.append("Window \(key.id) no longer matches its recovery record.")
        continue
      }
      if !restore(window, to: entry.originalFrame) {
        failures.append("Could not restore window \(key.id).")
      }
    }
    return failures
  }

  private func isActuallyParked(_ window: ManagedWindow) -> Bool {
    guard journal.entries[window.key] != nil, let frame = window.frame else { return false }
    return ParkingGeometry.visibleArea(of: frame, on: screenFrames())
      <= max(frame.width, frame.height) * 2
  }

  private func focusVisibleWindow() {
    guard let activeSpaceID, (try? spaces.activeSpace()) == activeSpaceID else { return }
    if let focusedID = WindowAccess.focusedWindowID(),
      let focusedKey = activeWindowKeys.first(where: { $0.id == focusedID }),
      state.isVisible(focusedKey)
    {
      return
    }
    if let next = activeWindowKeys.compactMap({ windows[$0] }).first(where: {
      state.isVisible($0.key) && !$0.isMinimized
        && WindowAccess.belongsToActiveSpace($0.key.id, activeSpace: activeSpaceID, using: spaces)
    }) {
      WindowAccess.focus(next)
    }
  }

  private func screenFrames() -> [CGRect] {
    let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
    return NSScreen.screens.map {
      ParkingGeometry.axFrame(for: $0.frame, mainDisplayTop: mainTop)
    }
  }

  private func snapshot() -> JSONValue {
    let windowsValue: [JSONValue] = activeWindowKeys.compactMap { windows[$0] }
      .sorted(by: { $0.key.id < $1.key.id }).map {
        window in
        let key = window.key
        var fields: [String: JSONValue] = [
          "id": .number(Double(key.id)),
          "pid": .number(Double(key.pid)),
          "app": .string(window.appName),
          "bundleId": .string(window.bundleID),
          "tags": .array((state.tags(for: key) ?? []).sorted().map(JSONValue.string)),
          "desiredVisible": .bool(state.isVisible(key)),
          "minimized": .bool(window.isMinimized),
          "nativeFullscreen": .bool(window.isFullscreen),
          "parked": .bool(isActuallyParked(window)),
          "parkingRecorded": .bool(journal.entries[key] != nil),
        ]
        if let error = errors[key] { fields["error"] = .string(error) }
        if let frame = window.frame {
          fields["frame"] = .object([
            "x": .number(frame.minX), "y": .number(frame.minY),
            "width": .number(frame.width), "height": .number(frame.height),
          ])
        }
        return .object(fields)
      }
    return .object([
      "activeTags": .array(state.activeTags.sorted().map(JSONValue.string)),
      "primaryTag": .string(state.primaryTag),
      "tags": .array(state.knownTags.sorted().map(JSONValue.string)),
      "windows": .array(windowsValue),
    ])
  }

  private func response(for failures: [String]) -> ControlResponse {
    ControlResponse(
      ok: failures.isEmpty,
      value: snapshot(),
      error: failures.isEmpty ? nil : failures.joined(separator: " ")
    )
  }

  private func publishIfChanged() {
    let value = snapshot()
    guard value != lastPublished else { return }
    lastPublished = value
    server?.publish(ControlResponse(value: value))
  }

  private func shutdown() {
    timer?.invalidate()
    timer = nil
    for source in signalSources { source.cancel() }
    signalSources = []
    server?.stop()
    server = nil
    CFRunLoopStop(CFRunLoopGetMain())
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
    isStopping = true
    let failures = restoreAll()
    if failures.isEmpty {
      shutdown()
    } else {
      isStopping = false
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
