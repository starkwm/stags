import Foundation

public struct WindowKey: Codable, Hashable, Sendable {
  public let pid: Int32
  public let id: UInt32

  public init(pid: Int32, id: UInt32) {
    self.pid = pid
    self.id = id
  }
}

public enum TagError: Error, Equatable, LocalizedError {
  case emptyTags
  case emptyTagName
  case unknownWindow
  case lastWindowTag
  case lastVisibleTag

  public var errorDescription: String? {
    switch self {
    case .emptyTags: "At least one tag is required."
    case .emptyTagName: "Tag names must not be empty."
    case .unknownWindow: "Window is not managed."
    case .lastWindowTag: "A window must keep at least one tag."
    case .lastVisibleTag: "At least one tag must remain visible."
    }
  }
}

public struct TagState: Sendable {
  public private(set) var activeTags: Set<String> = ["1"]
  public private(set) var primaryTag = "1"
  public private(set) var knownTags: Set<String> = ["1"]
  public private(set) var tagsByWindow: [WindowKey: Set<String>] = [:]

  public init() {}

  public func tags(for window: WindowKey) -> Set<String>? {
    tagsByWindow[window]
  }

  public func isVisible(_ window: WindowKey) -> Bool {
    guard let tags = tagsByWindow[window] else { return false }
    return !tags.isDisjoint(with: activeTags)
  }

  public mutating func adopt(_ window: WindowKey) {
    if tagsByWindow[window] == nil { tagsByWindow[window] = [primaryTag] }
  }

  public mutating func forget(_ window: WindowKey) {
    tagsByWindow.removeValue(forKey: window)
  }

  public mutating func setView(_ tags: Set<String>, primary: String? = nil) throws {
    try Self.validate(tags)
    if let primary, !tags.contains(primary) { throw TagError.emptyTagName }
    activeTags = tags
    primaryTag = primary ?? tags.sorted().first!
    knownTags.formUnion(tags)
  }

  public mutating func toggleView(_ tag: String) throws {
    try Self.validate([tag])
    if activeTags.contains(tag) {
      guard activeTags.count > 1 else { throw TagError.lastVisibleTag }
      activeTags.remove(tag)
      if primaryTag == tag { primaryTag = activeTags.sorted().first! }
    } else {
      activeTags.insert(tag)
      knownTags.insert(tag)
    }
  }

  public mutating func setTags(_ tags: Set<String>, for window: WindowKey) throws {
    try Self.validate(tags)
    guard tagsByWindow[window] != nil else { throw TagError.unknownWindow }
    tagsByWindow[window] = tags
    knownTags.formUnion(tags)
  }

  public mutating func addTag(_ tag: String, to window: WindowKey) throws {
    try Self.validate([tag])
    guard tagsByWindow[window] != nil else { throw TagError.unknownWindow }
    tagsByWindow[window]?.insert(tag)
    knownTags.insert(tag)
  }

  public mutating func removeTag(_ tag: String, from window: WindowKey) throws {
    guard let tags = tagsByWindow[window] else { throw TagError.unknownWindow }
    guard tags.contains(tag) else { return }
    guard tags.count > 1 else { throw TagError.lastWindowTag }
    tagsByWindow[window]?.remove(tag)
  }

  private static func validate(_ tags: Set<String>) throws {
    guard !tags.isEmpty else { throw TagError.emptyTags }
    guard tags.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
      throw TagError.emptyTagName
    }
  }
}
