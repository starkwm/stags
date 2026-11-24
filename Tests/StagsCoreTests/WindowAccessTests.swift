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
