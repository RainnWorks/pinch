import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: BindingStore

    var body: some View {
        Form {
            ForEach(Press.allCases) { press in
                PressRow(press: press, action: Binding(
                    get: { store.action(for: press) },
                    set: { store.actions[press] = $0 }
                ))
            }
            Text("\"Music\" passes the press on to Spotify or Music as normal.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }
}

private enum ActionKind: String, CaseIterable {
    case music = "Music"
    case shortcut = "Shortcut"
    case nothing = "Nothing"
}

private struct PressRow: View {
    let press: Press
    @Binding var action: PressAction

    private var kind: Binding<ActionKind> {
        Binding(
            get: {
                switch action {
                case .music: .music
                case .shortcut: .shortcut
                case .nothing: .nothing
                }
            },
            set: { newKind in
                switch newKind {
                case .music: action = .music
                case .nothing: action = .nothing
                case .shortcut:
                    if case .shortcut = action { return }
                    action = .shortcut(.optionSpace)
                }
            }
        )
    }

    var body: some View {
        HStack {
            Picker(press.label, selection: kind) {
                ForEach(ActionKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            if case .shortcut(let shortcut) = action {
                ShortcutRecorder(shortcut: shortcut) { action = .shortcut($0) }
            }
        }
    }
}

private struct ShortcutRecorder: View {
    let shortcut: Shortcut
    let onRecord: (Shortcut) -> Void
    @State private var monitor: Any?

    private let escapeKeyCode: UInt16 = 53
    private let recordableModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    var body: some View {
        Button(monitor == nil ? shortcut.display : "Type a shortcut…") {
            monitor == nil ? startRecording() : stopRecording()
        }
        .frame(minWidth: 130)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != escapeKeyCode {
                let modifiers = event.modifierFlags.intersection(recordableModifiers)
                onRecord(Shortcut(keyCode: event.keyCode, modifiers: modifiers.rawValue))
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
