import SwiftUI

/// A study checklist beside the clock: add tasks at the top, tap one to tick
/// it off, long-press to delete. The add field sits at the top because the
/// landscape keyboard covers the bottom half of the screen.
struct ChecklistFace: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let size: CGSize
    @Environment(ChecklistStore.self) private var store
    /// Set only by the macOS preview renderer, whose ImageRenderer can't draw
    /// platform-backed views (text fields, scroll views); see `rows`.
    @Environment(\.frozenMoment) private var frozen
    @State private var draft = ""
    @FocusState private var typing: Bool

    var body: some View {
        let scale = DockMetrics.scale(for: size)
        let list = store.checklist
        ZStack {
            LofiBackdrop()
            HStack(alignment: .top, spacing: 36 * scale) {
                VStack(alignment: .leading, spacing: 10 * scale) {
                    header(list, scale: scale)
                    addField(scale: scale)
                    if frozen == nil {
                        ScrollView { rows(list, scale: scale) }
                        #if os(iOS)
                            .scrollDismissesKeyboard(.interactively)
                        #endif
                    } else {
                        rows(list, scale: scale)
                    }
                }
                .frame(width: size.width * 0.52)
                summary(list, scale: scale)
                    .frame(maxWidth: .infinity)
            }
            .padding(.leading, 72 * scale)   // clear of the Dynamic Island
            .padding(.trailing, 64 * scale)
            .padding(.vertical, 26 * scale)
        }
    }

    private func rows(_ list: Checklist, scale: CGFloat) -> some View {
        LazyVStack(alignment: .leading, spacing: 2 * scale) {
            if list.items.isEmpty {
                Text("Nothing here yet. Add what you're working on.")
                    .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.45))
                    .padding(.top, 10 * scale)
                    .padding(.leading, 6 * scale)
            }
            ForEach(list.items) { item in
                ChecklistRow(item: item, scale: scale) {
                    withAnimation(.easeOut(duration: 0.2)) { store.toggle(item.id) }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation { store.remove(item.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func header(_ list: Checklist, scale: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("CHECKLIST")
                .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                .tracking(2.5 * scale)
                .foregroundStyle(Palette.cream.opacity(0.6))
            Spacer()
            if list.doneCount > 0 {
                Button("Clear done") {
                    withAnimation { store.clearDone() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.lamp.opacity(0.9))
            }
        }
    }

    private func addField(scale: CGFloat) -> some View {
        HStack(spacing: 10 * scale) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20 * scale, weight: .medium))
                .foregroundStyle(Palette.lamp)
            if frozen == nil {
                TextField("Add a task", text: $draft,
                          prompt: Text("Add a task").foregroundStyle(Palette.cream.opacity(0.4)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 17 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit(addDraft)
            } else {
                Text("Add a task")
                    .font(.system(size: 17 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14 * scale)
        .frame(height: 44 * scale)
        .background(RoundedRectangle(cornerRadius: 12 * scale).fill(Palette.cream.opacity(typing ? 0.12 : 0.07)))
        .contentShape(Rectangle())
        .onTapGesture { typing = true }
    }

    /// Adds the typed task and keeps the keyboard up for the next one;
    /// submitting an empty field puts the keyboard away.
    private func addDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            typing = false
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { store.add(draft) }
        draft = ""
        typing = true
    }

    private func summary(_ list: Checklist, scale: CGFloat) -> some View {
        let clock = TimeFormatting.clock(date)
        let total = list.items.count
        return VStack(spacing: 12 * scale) {
            HStack(alignment: .firstTextBaseline, spacing: 5 * scale) {
                Text(clock.time)
                    .font(.system(size: 46 * scale, weight: .light, design: .rounded))
                    .monospacedDigit()
                if let period = clock.period {
                    Text(period).font(.system(size: 16 * scale, weight: .medium, design: .rounded)).opacity(0.6)
                }
            }
            Text(TimeFormatting.dateLine(date))
                .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                .opacity(0.6)
            ZStack {
                Circle().stroke(Palette.cream.opacity(0.1), lineWidth: 7 * scale)
                Circle()
                    .trim(from: 0, to: list.progress)
                    .stroke(Palette.lamp, style: StrokeStyle(lineWidth: 7 * scale, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: list.progress)
                VStack(spacing: 0) {
                    Text("\(list.doneCount)/\(total)")
                        .font(.system(size: 22 * scale, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text(total > 0 && list.doneCount == total ? "all done" : "done")
                        .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                        .opacity(0.55)
                }
            }
            .frame(width: 92 * scale, height: 92 * scale)
            .padding(.vertical, 6 * scale)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(list.doneCount) of \(total) tasks done")
            HStack(alignment: .firstTextBaseline, spacing: 8 * scale) {
                Text("SESSION")
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .tracking(2.5 * scale)
                    .opacity(0.55)
                Text(TimeFormatting.session(sessionElapsed))
                    .font(.system(size: 18 * scale, weight: .regular, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Palette.cream)
        .shadow(color: Palette.lamp.opacity(0.2), radius: 12 * scale)
        .padding(.top, 14 * scale)
    }
}

struct ChecklistRow: View {
    let item: ChecklistItem
    let scale: CGFloat
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12 * scale) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21 * scale, weight: .medium))
                    .foregroundStyle(item.isDone ? Palette.lamp : Palette.cream.opacity(0.55))
                Text(item.title)
                    .font(.system(size: 17 * scale, weight: .medium, design: .rounded))
                    .strikethrough(item.isDone, color: Palette.cream.opacity(0.5))
                    .foregroundStyle(Palette.cream.opacity(item.isDone ? 0.45 : 0.95))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8 * scale)
            .padding(.horizontal, 6 * scale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isDone ? "Done" : "Not done")
        .accessibilityHint("Double-tap to tick off. Touch and hold to delete.")
    }
} 
