import AppKit
import AVFoundation
import MediaPlayer
import Sparkle
import SwiftUI

let reclaimDelay: TimeInterval = 1.0

// AirPods presses reach only the app macOS treats as "now playing". A silent
// loop puts Pinch in that slot; restarting it takes the slot back after
// Spotify or Music starts playing.
final class NowPlayingClaim {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var silence: AVAudioPCMBuffer?

    func start() throws {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate))
        silence?.frameLength = silence?.frameCapacity ?? 0
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        reclaim()
    }

    func reclaim() {
        guard let silence else { return }
        player.stop()
        player.scheduleBuffer(silence, at: nil, options: .loops)
        player.play()
        let info = MPNowPlayingInfoCenter.default()
        info.nowPlayingInfo = [MPMediaItemPropertyTitle: "Pinch"]
        info.playbackState = .playing
    }
}

func runningPlayer() -> String? {
    let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    if running.contains("com.spotify.client") { return "Spotify" }
    if running.contains("com.apple.Music") { return "Music" }
    return nil
}

func sendMusic(_ command: String, to app: String) -> String? {
    var error: NSDictionary?
    NSAppleScript(source: "tell application \"\(app)\" to \(command)")?.executeAndReturnError(&error)
    return error?[NSAppleScript.errorMessage] as? String
}

func airpodsImage(pointSize: CGFloat) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    return NSImage(systemSymbolName: "airpods", accessibilityDescription: "Pinch")?.withSymbolConfiguration(config)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = BindingStore()
    private let claim = NowPlayingClaim()
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settingsWindow: NSWindow?
    private var events: [String] = []
    private var lastSinglePress = Date.distantPast
    private var isTrusted = false
    private var accessibilityTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if leaveTranslocation() { return }
        NSApp.mainMenu = mainMenu()

        isTrusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        updateStatusIcon()
        log(isTrusted ? "Accessibility allowed" : "Accessibility missing: shortcuts will not work")
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
        }

        let commands = MPRemoteCommandCenter.shared()
        for command in [commands.togglePlayPauseCommand, commands.playCommand, commands.pauseCommand] {
            command.addTarget { [weak self] _ in self?.handleSinglePress(); return .success }
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in self?.handle(.double); return .success }
        commands.previousTrackCommand.addTarget { [weak self] _ in self?.handle(.triple); return .success }

        do {
            try claim.start()
            log("Holding now playing")
        } catch {
            log("Audio start failed: \(error.localizedDescription)")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    // One stem press can arrive as both pause and togglePlayPause.
    private func handleSinglePress() {
        guard Date().timeIntervalSince(lastSinglePress) > 0.4 else { return }
        lastSinglePress = Date()
        handle(.single)
    }

    private func handle(_ press: Press) {
        switch store.action(for: press) {
        case .nothing:
            log("\(press.rawValue) → nothing")
        case .shortcut(let shortcut):
            guard isTrusted else {
                log("\(press.rawValue) → \(shortcut.display) blocked: allow Accessibility")
                return
            }
            shortcut.post()
            log("\(press.rawValue) → \(shortcut.display)")
        case .music:
            forwardToMusic(press)
        }
    }

    private func forwardToMusic(_ press: Press) {
        guard let app = runningPlayer() else {
            log("\(press.rawValue) → no Spotify or Music running")
            return
        }
        if let error = sendMusic(press.musicCommand, to: app) {
            log("\(press.rawValue) → \(app) failed: \(error)")
            return
        }
        log("\(press.rawValue) → \(app) \(press.musicCommand)")
        DispatchQueue.main.asyncAfter(deadline: .now() + reclaimDelay) { [weak self] in
            self?.reclaimNow()
        }
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        if trusted {
            log("Accessibility allowed: restarting Pinch")
            relaunch()
        } else {
            log("Accessibility removed: shortcuts will not work")
            updateStatusIcon()
        }
    }

    private func relaunch(from path: String = Bundle.main.bundlePath) {
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        reopen.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? reopen.run()
        NSApp.terminate(nil)
    }

    // macOS runs a quarantined app that Finder did not move from a read-only copy,
    // and Sparkle cannot update that copy. Homebrew installs land in this state.
    private func leaveTranslocation() -> Bool {
        let bundle = Bundle.main.bundleURL
        guard bundle.path.contains("/AppTranslocation/"), let original = originalLocation(of: bundle) else { return false }
        let clear = Process()
        clear.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        clear.arguments = ["-dr", "com.apple.quarantine", original.path]
        try? clear.run()
        clear.waitUntilExit()
        relaunch(from: original.path)
        return true
    }

    private func originalLocation(of url: URL) -> URL? {
        typealias CreateOriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL") else { return nil }
        let create = unsafeBitCast(symbol, to: CreateOriginalPath.self)
        return create(url as CFURL, nil)?.takeRetainedValue() as URL?
    }

    private func updateStatusIcon() {
        let image = isTrusted
            ? airpodsImage(pointSize: 15)
            : NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Pinch needs Accessibility")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func log(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        events.insert("\(time)  \(message)", at: 0)
        events = Array(events.prefix(15))
        NSLog("Pinch: \(message)")
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        if !isTrusted {
            let warning = NSMenuItem(title: "Pinch needs Accessibility to send shortcuts", action: nil, keyEquivalent: "")
            warning.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(warning)
            menu.addItem(item("Open Accessibility Settings…", #selector(openAccessibilitySettings), ""))
            menu.addItem(NSMenuItem(title: "If Pinch is listed but not working, remove it with − and add it again", action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
        }
        for event in events {
            menu.addItem(NSMenuItem(title: event, action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(showSettings), ","))
        menu.addItem(checkForUpdatesItem())
        menu.addItem(item("Reclaim now playing", #selector(reclaimNow), "r"))
        menu.addItem(NSMenuItem(title: "Quit Pinch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func mainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(item("Settings…", #selector(showSettings), ","))
        appMenu.addItem(checkForUpdatesItem())
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Pinch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let main = NSMenu()
        main.addItem(appItem)
        return main
    }

    private func checkForUpdatesItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = updater
        return item
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "Pinch Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func reclaimNow() {
        claim.reclaim()
        log("Reclaimed now playing")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
