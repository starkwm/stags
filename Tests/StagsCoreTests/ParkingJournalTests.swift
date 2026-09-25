import Foundation
import Testing

@testable import StagsCore

@Suite("ParkingJournal")
struct ParkingJournalTests {
  @Test("record: survives reload and remove")
  func roundTrip() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "parking.json")
    let key = WindowKey(pid: 10, id: 20)
    let frame = WindowFrame(CGRect(x: 100, y: 50, width: 500, height: 400))
    var journal = try ParkingJournal(url: url)
    try journal.record(frame, for: key, bundleID: "org.example.App")
    journal = try ParkingJournal(url: url)
    #expect(journal.entries[key]?.originalFrame == frame)
    #expect(journal.entries[key]?.bundleID == "org.example.App")
    try journal.remove(key)
    #expect(try ParkingJournal(url: url).entries.isEmpty)
  }
}
