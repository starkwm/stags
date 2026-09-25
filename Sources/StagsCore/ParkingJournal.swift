import Foundation

public struct ParkingEntry: Codable, Equatable, Sendable {
  public let window: WindowKey
  public let bundleID: String
  public let originalFrame: WindowFrame

  public init(window: WindowKey, bundleID: String, originalFrame: WindowFrame) {
    self.window = window
    self.bundleID = bundleID
    self.originalFrame = originalFrame
  }
}

public struct ParkingJournal {
  public let url: URL
  public private(set) var entries: [WindowKey: ParkingEntry]

  public init(url: URL) throws {
    self.url = url
    if FileManager.default.fileExists(atPath: url.path) {
      let records = try JSONDecoder().decode([ParkingEntry].self, from: Data(contentsOf: url))
      entries = Dictionary(uniqueKeysWithValues: records.map { ($0.window, $0) })
    } else {
      entries = [:]
    }
  }

  public static func defaultURL() -> URL {
    let base =
      ProcessInfo.processInfo.environment["XDG_STATE_HOME"]
      .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
      ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/state")
    return base.appending(path: "stags/parking.json")
  }

  public mutating func record(_ frame: WindowFrame, for window: WindowKey, bundleID: String) throws
  {
    let previous = entries
    entries[window] = ParkingEntry(window: window, bundleID: bundleID, originalFrame: frame)
    do { try save() } catch {
      entries = previous
      throw error
    }
  }

  public mutating func remove(_ window: WindowKey) throws {
    let previous = entries
    entries.removeValue(forKey: window)
    do { try save() } catch {
      entries = previous
      throw error
    }
  }

  private func save() throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let records = Array(entries.values)
      .sorted { ($0.window.pid, $0.window.id) < ($1.window.pid, $1.window.id) }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(records).write(to: url, options: .atomic)
  }
}
