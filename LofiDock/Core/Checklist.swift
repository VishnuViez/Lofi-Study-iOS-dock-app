import Foundation
import Observation

struct ChecklistItem: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
}

/// The study checklist as a plain value: ordered items, each done or not.
struct Checklist: Codable, Equatable {
    private(set) var items: [ChecklistItem] = []

    /// Long enough for any real task; keeps a pasted essay from swamping the face.
    static let maxTitleLength = 120

    /// Adds a task to the end. Blank titles are ignored. Returns whether one was added.
    @discardableResult
    mutating func add(_ title: String, now: Date = .now, id: UUID = UUID()) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        items.append(ChecklistItem(id: id, title: String(trimmed.prefix(Self.maxTitleLength)),
                                   isDone: false, createdAt: now))
        return true
    }

    mutating func toggle(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
    }

    mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    mutating func clearDone() {
        items.removeAll(where: \.isDone)
    }

    var doneCount: Int { items.filter(\.isDone).count }

    /// Share of tasks done, 0 for an empty list.
    var progress: Double {
        items.isEmpty ? 0 : Double(doneCount) / Double(items.count)
    }
}

/// Keeps the checklist in UserDefaults (as JSON) so it survives relaunches;
/// unlike the session timer, a to-do list shouldn't vanish when you leave.
@MainActor
@Observable
final class ChecklistStore {
    private(set) var checklist: Checklist
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Pref.checklist),
           let saved = try? JSONDecoder().decode(Checklist.self, from: data) {
            checklist = saved
        } else {
            checklist = Checklist()
        }
    }

    func add(_ title: String) {
        if checklist.add(title) { save() }
    }

    func toggle(_ id: UUID) {
        checklist.toggle(id)
        save()
    }

    func remove(_ id: UUID) {
        checklist.remove(id)
        save()
    }

    func clearDone() {
        checklist.clearDone()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(checklist) else { return }
        defaults.set(data, forKey: Pref.checklist)
    }
}
