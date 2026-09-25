import AppKit
import ApplicationServices
import CoreGraphics

@_silgen_name("_AXUIElementGetWindow")
private func axWindowID(_ element: AXUIElement, _ identifier: inout UInt32) -> AXError

@MainActor
struct ManagedWindow {
  let key: WindowKey
  let bundleID: String
  let appName: String
  let element: AXUIElement

  var frame: CGRect? { WindowAccess.frame(of: element) }
  var isMinimized: Bool { WindowAccess.bool(kAXMinimizedAttribute, of: element) ?? false }
  var isFullscreen: Bool { WindowAccess.bool("AXFullScreen", of: element) ?? false }
}

@MainActor
enum WindowAccess {
  static func requestTrust() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  static func discover() -> [WindowKey: ManagedWindow] {
    var result: [WindowKey: ManagedWindow] = [:]
    let currentPID = ProcessInfo.processInfo.processIdentifier

    for app in NSWorkspace.shared.runningApplications where app.processIdentifier != currentPID {
      guard app.activationPolicy == .regular else { continue }
      let application = AXUIElementCreateApplication(app.processIdentifier)
      AXUIElementSetMessagingTimeout(application, 0.25)
      var value: CFTypeRef?
      guard
        AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
          == .success,
        let windows = value as? [AXUIElement]
      else { continue }

      for window in windows {
        AXUIElementSetMessagingTimeout(window, 0.25)
        var id: UInt32 = 0
        guard axWindowID(window, &id) == .success, id != 0 else { continue }
        guard string(kAXRoleAttribute, of: window) == kAXWindowRole as String else { continue }
        var movable = DarwinBoolean(false)
        guard
          AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &movable)
            == .success, movable.boolValue
        else { continue }
        let key = WindowKey(pid: app.processIdentifier, id: id)
        result[key] = ManagedWindow(
          key: key,
          bundleID: app.bundleIdentifier ?? "",
          appName: app.localizedName ?? "",
          element: window
        )
      }
    }

    return result
  }

  static func focusedWindowID() -> UInt32? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.25)
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value)
        == .success,
      let value, CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    let element = value as! AXUIElement
    var id: UInt32 = 0
    return axWindowID(element, &id) == .success && id != 0 ? id : nil
  }

  static func frame(of element: AXUIElement) -> CGRect? {
    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        == .success,
      AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
      let positionValue, let sizeValue,
      CFGetTypeID(positionValue) == AXValueGetTypeID(),
      CFGetTypeID(sizeValue) == AXValueGetTypeID()
    else { return nil }
    let position = positionValue as! AXValue
    let size = sizeValue as! AXValue
    var point = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize,
      AXValueGetValue(position, .cgPoint, &point),
      AXValueGetValue(size, .cgSize, &dimensions)
    else { return nil }
    return CGRect(origin: point, size: dimensions)
  }

  static func move(_ element: AXUIElement, to point: CGPoint) -> Bool {
    var point = point
    guard let value = AXValueCreate(.cgPoint, &point) else { return false }
    return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
      == .success
  }

  static func focus(_ window: ManagedWindow) {
    NSRunningApplication(processIdentifier: window.key.pid)?.activate()
    AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
  }

  static func bool(_ attribute: String, of element: AXUIElement) -> Bool? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
    else { return nil }
    return (value as? NSNumber)?.boolValue
  }

  private static func string(_ attribute: String, of element: AXUIElement) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
    else { return nil }
    return value as? String
  }
}
