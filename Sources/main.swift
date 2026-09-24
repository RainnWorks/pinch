import AppKit
import AVFoundation
import MediaPlayer
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
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settingsWindow: NSWindow?
    private var events: [String] = []
    private var lastSinglePress = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = mainMenu()
        let image = airpodsImage(pointSize: 15)
        image?.isTemplate = true
        statusItem.button?.image = image

        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        log(trusted ? "Accessibility granted" : "Accessibility missing: grant it, then relaunch")

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

    private func log(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        events.insert("\(time)  \(message)", at: 0)
        events = Array(events.prefix(15))
        NSLog("Pinch: \(message)")
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        for event in events {
            menu.addItem(NSMenuItem(title: event, action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(showSettings), ","))
        menu.addItem(item("Reclaim now playing", #selector(reclaimNow), "r"))
        menu.addItem(NSMenuItem(title: "Quit Pinch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func mainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(item("Settings…", #selector(showSettings), ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Pinch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let main = NSMenu()
        main.addItem(appItem)
        return main
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
