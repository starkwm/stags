import CoreGraphics
import StarkSkyLight

@MainActor
final class FakeSpaceQuery: SpaceQuerying {
  var activeSpaceID: SpaceID?
  var onMembershipQuery: (() -> Void)?
  let memberships: [CGWindowID: [SpaceID]]
  let fails: Bool

  init(memberships: [CGWindowID: [SpaceID]], fails: Bool = false) {
    self.memberships = memberships
    self.fails = fails
  }

  func snapshot() throws -> SpaceSnapshot { SpaceSnapshot(displays: [], activeSpaceID: nil) }
  func activeSpace() throws -> SpaceID? { activeSpaceID }
  func currentSpace(for displayID: DisplayID) throws -> SpaceID? { nil }
  func spaceType(for spaceID: SpaceID) throws -> SpaceType { .desktop }

  func spaceIDs(containing windowID: CGWindowID) throws -> [SpaceID] {
    onMembershipQuery?()
    if fails { throw QueryFailure.failed }
    return memberships[windowID] ?? []
  }
}

private enum QueryFailure: Error {
  case failed
}
