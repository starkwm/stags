import CoreGraphics
import Testing

@testable import StagsCore

@Suite("ParkingGeometry")
struct ParkingGeometryTests {
  @Test("position: chooses a free edge")
  func choosesFreeEdge() {
    let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
    let window = CGRect(x: 100, y: 100, width: 400, height: 300)
    let point = ParkingGeometry.position(for: window, on: left, among: [left, right])
    #expect(point.x == -399)
  }

  @Test("axFrame: converts screen vertical coordinates")
  func convertsCoordinates() {
    let screen = CGRect(x: -1200, y: 200, width: 1200, height: 800)
    let frame = ParkingGeometry.axFrame(for: screen, mainDisplayTop: 900)
    #expect(frame == CGRect(x: -1200, y: -100, width: 1200, height: 800))
  }
}
