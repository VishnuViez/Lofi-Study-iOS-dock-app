import Foundation
import Testing
@testable import LofiDock

struct ChecklistTests {
    @Test func addsTrimmedTasksAndIgnoresBlankOnes() {
        var list = Checklist()
        let blank = list.add("   \n ")
        let real = list.add("  Read chapter 4 \n")
        #expect(!blank && real)
        #expect(list.items.map(\.title) == ["Read chapter 4"])
        #expect(list.items[0].isDone == false)
    }

    @Test func capsVeryLongTitles() {
        var list = Checklist()
        list.add(String(repeating: "a", count: 500))
        #expect(list.items[0].title.count == Checklist.maxTitleLength)
    }

    @Test func togglesRemovesAndClearsDone() {
        var list = Checklist()
        let a = UUID(), b = UUID(), c = UUID()
        list.add("A", id: a)
        list.add("B", id: b)
        list.add("C", id: c)
        list.toggle(a)
        list.toggle(c)
        #expect(list.doneCount == 2)
        #expect(abs(list.progress - 2.0 / 3.0) < 1e-9)
        list.toggle(c)  // untick
        list.remove(b)
        #expect(list.items.map(\.title) == ["A", "C"])
        list.clearDone()
        #expect(list.items.map(\.title) == ["C"])
        list.toggle(UUID())  // unknown id is ignored
        #expect(list.items.count == 1)
    }

    @Test func emptyListHasNoProgress() {
        #expect(Checklist().progress == 0)
    }

    @Test func survivesEncoding() throws {
        var list = Checklist()
        list.add("Flashcards")
        list.toggle(list.items[0].id)
        let decoded = try JSONDecoder().decode(Checklist.self, from: JSONEncoder().encode(list))
        #expect(decoded == list)
    }

    /// The store is what keeps tasks across relaunches.
    @MainActor
    @Test func storeReloadsWhatItSaved() throws {
        let suite = "LofiDockTests.checklist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ChecklistStore(defaults: defaults)
        store.add("Past paper")
        store.add("Summarise notes")
        store.toggle(store.checklist.items[0].id)

        let reopened = ChecklistStore(defaults: defaults)
        #expect(reopened.checklist == store.checklist)
        #expect(reopened.checklist.doneCount == 1)
    }
} 
