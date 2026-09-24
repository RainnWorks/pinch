import AppKit
import Carbon

enum Press: String, CaseIterable, Codable, Identifiable {
    case single, double, triple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: "Single press"
        case .double: "Double press"
        case .triple: "Triple press"
        }
    }

    var musicCommand: String {
        switch self {
        case .single: "playpause"
        case .double: "next track"
        case .triple: "previous track"
        }
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    static let optionSpace = Shortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags.option.rawValue)

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var cgFlags: CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.command) { result.insert(.maskCommand) }
        return result
    }

    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + Shortcut.keyName(keyCode)
    }

    func post() {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = cgFlags
            event?.post(tap: .cghidEventTap)
        }
    }

    private static let namedKeys: [UInt16: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    private static func keyName(_ keyCode: UInt16) -> String {
        if let name = namedKeys[keyCode] { return name }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key \(keyCode)"
        }
        let layout = unsafeBitCast(layoutData, to: CFData.self)
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = CFDataGetBytePtr(layout).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
            UCKeyTranslate($0, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

enum PressAction: Codable, Equatable {
    case music
    case shortcut(Shortcut)
    case command(String)
    case nothing
}

final class BindingStore: ObservableObject {
    private static let defaultsKey = "bindings"

    @Published var actions: [Press: PressAction] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([Press: PressAction].self, from: data) {
            actions = saved
        } else {
            actions = [.single: .music, .double: .shortcut(.optionSpace), .triple: .music]
        }
    }

    func action(for press: Press) -> PressAction { actions[press] ?? .music }

    private func save() {
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
