import Testing

@testable import StagsCore

@Suite("TagState")
struct TagStateTests {
  @Test("adopt: assigns the primary tag")
  func adoptAssignsPrimaryTag() throws {
    var state = TagState()
    try state.setView(["work", "chat"], primary: "work")
    let window = WindowKey(pid: 10, id: 20)
    state.adopt(window)
    #expect(state.tags(for: window) == ["work"])
  }

  @Test("isVisible: matches any active tag")
  func visibilityUsesUnion() throws {
    var state = TagState()
    let window = WindowKey(pid: 10, id: 20)
    state.adopt(window)
    try state.setTags(["work", "chat"], for: window)
    try state.setView(["chat", "other"])
    #expect(state.isVisible(window))
    try state.setView(["other"])
    #expect(!state.isVisible(window))
  }

  @Test("toggleView: keeps one visible tag")
  func toggleViewRejectsLastTag() throws {
    var state = TagState()
    #expect(throws: TagError.lastVisibleTag) { try state.toggleView("1") }
    try state.toggleView("chat")
    #expect(state.activeTags == ["1", "chat"])
  }

  @Test("removeTag: keeps one window tag")
  func removeRejectsLastTag() throws {
    var state = TagState()
    let window = WindowKey(pid: 10, id: 20)
    state.adopt(window)
    #expect(throws: TagError.lastWindowTag) { try state.removeTag("1", from: window) }
    try state.addTag("chat", to: window)
    try state.removeTag("1", from: window)
    #expect(state.tags(for: window) == ["chat"])
  }
}
