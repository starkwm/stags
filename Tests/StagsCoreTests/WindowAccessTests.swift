import CoreGraphics
import StarkSkyLight
import Testing

@testable import StagsCore

@MainActor
@Suite("WindowAccess")
struct WindowAccessTests {
  @Test("belongsToActiveSpace: accepts a window on the active Space")
  func acceptsActiveSpaceMembership() {
    let spaces = FakeSpaceQuery(memberships: [20: [SpaceID(rawValue: 1), SpaceID(rawValue: 2)]])
    #expect(
      WindowAccess.belongsToActiveSpace(20, activeSpace: SpaceID(rawValue: 2), using: spaces)
    )
  }

  @Test("belongsToActiveSpace: rejects another Space or missing membership")
  func rejectsOtherSpaces() {
    let spaces = FakeSpaceQuery(memberships: [20: [SpaceID(rawValue: 1)]])
    #expect(
      !WindowAccess.belongsToActiveSpace(20, activeSpace: SpaceID(rawValue: 2), using: spaces)
    )
    #expect(
      !WindowAccess.belongsToActiveSpace(21, activeSpace: SpaceID(rawValue: 2), using: spaces)
    )
  }

  @Test("belongsToActiveSpace: rejects a failed Space query")
  func rejectsFailedQuery() {
    let spaces = FakeSpaceQuery(memberships: [:], fails: true)
    #expect(
      !WindowAccess.belongsToActiveSpace(20, activeSpace: SpaceID(rawValue: 2), using: spaces)
    )
  }
}

@MainActor
private final class FakeSpaceQuery: SpaceQuerying {
  let memberships: [CGWindowID: [SpaceID]]
  let fails: Bool

  init(memberships: [CGWindowID: [SpaceID]], fails: Bool = false) {
    self.memberships = memberships
    self.fails = fails
  }

  func snapshot() throws -> SpaceSnapshot { SpaceSnapshot(displays: [], activeSpaceID: nil) }
  func activeSpace() throws -> SpaceID? { nil }
  func currentSpace(for displayID: DisplayID) throws -> SpaceID? { nil }
  func spaceType(for spaceID: SpaceID) throws -> SpaceType { .desktop }

  func spaceIDs(containing windowID: CGWindowID) throws -> [SpaceID] {
    if fails { throw QueryFailure.failed }
    return memberships[windowID] ?? []
  }
}

private enum QueryFailure: Error {
  case failed
}
