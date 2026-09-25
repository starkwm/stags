import CoreGraphics
import Foundation

public struct WindowFrame: Codable, Equatable, Sendable {
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double

  public init(_ rect: CGRect) {
    x = rect.origin.x
    y = rect.origin.y
    width = rect.width
    height = rect.height
  }

  public var rect: CGRect {
    CGRect(x: x, y: y, width: width, height: height)
  }
}

public enum ParkingGeometry {
  /// AX coordinates have their origin at the top left of the main display.
  public static func axFrame(for screen: CGRect, mainDisplayTop: CGFloat) -> CGRect {
    CGRect(
      x: screen.minX,
      y: mainDisplayTop - screen.maxY,
      width: screen.width,
      height: screen.height
    )
  }

  /// Put a window at a bottom corner, preferring the side with less overlap on other displays.
  public static func position(
    for window: CGRect,
    on display: CGRect,
    among displays: [CGRect]
  ) -> CGPoint {
    let y = display.maxY - 1
    let left = CGPoint(x: display.minX - window.width + 1, y: y)
    let right = CGPoint(x: display.maxX - 1, y: y)
    let leftOverlap = overlap(of: CGRect(origin: left, size: window.size), with: displays)
    let rightOverlap = overlap(of: CGRect(origin: right, size: window.size), with: displays)
    return rightOverlap <= leftOverlap ? right : left
  }

  public static func visibleArea(of window: CGRect, on displays: [CGRect]) -> CGFloat {
    overlap(of: window, with: displays)
  }

  private static func overlap(of window: CGRect, with displays: [CGRect]) -> CGFloat {
    displays.reduce(0) { area, display in
      let intersection = window.intersection(display)
      return area + (intersection.isNull ? 0 : intersection.width * intersection.height)
    }
  }
}
