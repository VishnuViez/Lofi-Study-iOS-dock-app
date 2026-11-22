import AudioToolbox
import AVFoundation
import Foundation
import os

/// Plays AmbienceSynth through AVAudioEngine. Main-thread API; the synth runs
/// on the audio render thread.
@MainActor
final class AmbiencePlayer {
    private let engine = AVAudioEngine()
    private var synth: AmbienceSynth?
    private var inForeground = false
    private var rainOn = false
    private var vinylOn = false
    private var muted = false
    private var chimePlayer: AVAudioPlayer?
    private var alarm: Task<Void, Never>?
    private var pendingStop: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private let log = Logger(subsystem: "LofiDock", category: "audio")

    /// Long enough for the synth's glide to fall below −50 dB before the
    /// engine stops, so switching the last source off never clicks.
    private static let stopDelay: TimeInterval = 2

    func setSources(rain: Bool, vinyl: Bool) {
        rainOn = rain
        vinylOn = vinyl
        update()
    }

    func setForeground(_ foreground: Bool) {
        inForeground = foreground
        update()
    }

    /// Silences everything, ambience and timer chime alike. The rain/vinyl
    /// choices are kept for when sound comes back.
    func setMuted(_ muted: Bool) {
        self.muted = muted
        if muted { chimePlayer?.stop() }
        update()
    }

    /// Rings the timer chime every 3 s for up to a minute, until stopAlarm().
    /// Each ring also vibrates, so a muted phone still gets your attention.
    func startAlarm() {
        stopAlarm()
        alarm = Task { [weak self] in
            for _ in 0..<20 {
                self?.ringOnce()
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { return }
            }
        }
    }

    func stopAlarm() {
        alarm?.cancel()
        alarm = nil
        chimePlayer?.stop()
    }

    private func ringOnce() {
        #if os(iOS)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #endif
        guard !muted, let url = ChimeFile.url() else { return }
        activateSession()
        chimePlayer = try? AVAudioPlayer(contentsOf: url)
        chimePlayer?.play()
    }

    private var shouldPlay: Bool { inForeground && !muted && (rainOn || vinylOn) }

    private func update() {
        observeIfNeeded()
        if shouldPlay {
            pendingStop?.cancel()
            pendingStop = nil
            start()
            synth?.rainLevel = rainOn ? 1 : 0
            synth?.vinylLevel = vinylOn ? 1 : 0
        } else {
            synth?.rainLevel = 0
            synth?.vinylLevel = 0
            if inForeground {
                scheduleStop()
            } else {
                // Leaving the app: iOS suspends it within moments anyway.
                stop()
            }
        }
    }

    private func start() {
        activateSession()
        if synth == nil { buildGraph() }
        guard !engine.isRunning else { return }
        synth?.silence()
        do {
            try engine.start()
        } catch {
            log.error("Audio engine failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stop() {
        pendingStop?.cancel()
        pendingStop = nil
        guard engine.isRunning else { return }
        engine.stop()
        deactivateSession()
    }

    private func scheduleStop() {
        guard pendingStop == nil, engine.isRunning else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pendingStop = nil
                if !self.shouldPlay { self.stop() }
            }
        }
        pendingStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopDelay, execute: work)
    }

    private func buildGraph() {
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = hardwareRate > 0 ? hardwareRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let synth = AmbienceSynth(sampleRate: rate)
        let node = Self.makeSourceNode(format: format, synth: synth)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.synth = synth
    }

    /// Kept out of the main actor on purpose: a closure formed inside a
    /// main-actor method inherits that isolation, and the render thread
    /// calling it can trip Swift's runtime isolation checks.
    nonisolated private static func makeSourceNode(format: AVAudioFormat, synth: AmbienceSynth) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let left = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let right = buffers.count > 1 ? (buffers[1].mData?.assumingMemoryBound(to: Float.self) ?? left) : left
            synth.render(frames: Int(frameCount), left: left, right: right)
            return noErr
        }
    }

    /// A route change (headphones, AirPlay) or an interruption (a call, Siri)
    /// stops the engine without telling the app's own state; restart it.
    private func restartIfNeeded() {
        guard shouldPlay, !engine.isRunning else { return }
        start()
    }

    private func observeIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        })
        #if os(iOS)
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard type == AVAudioSession.InterruptionType.ended.rawValue else { return }
            MainActor.assumeIsolated { self?.restartIfNeeded() }
        })
        #endif
    }

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps the ambience audible with the silent switch on;
            // .mixWithOthers lets it sit under music from another app.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            log.error("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
