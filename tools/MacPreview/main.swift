// macOS-only dev tool: renders the dock screen and app icon to PNG, and the
// ambience to WAV, from the same sources the iOS app compiles. Lets the scene
// and sound be checked without Xcode or a device. Built by tools/check-mac.sh.

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@main
struct MacPreview {
    @MainActor
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            print("usage: MacPreview <output-dir> [app-icon.png]")
            exit(2)
        }
        let out = URL(fileURLWithPath: args[1], isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        // A fixed evening moment, 42 min into a session.
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 21, minute: 41))!
        let session = SessionClock(now: date.addingTimeInterval(-2_533))
        let size = CGSize(width: 852, height: 393)

        let previewDefaults = UserDefaults(suiteName: "LofiDockPreview")!
        previewDefaults.removePersistentDomain(forName: "LofiDockPreview")
        defer { previewDefaults.removePersistentDomain(forName: "LofiDockPreview") }
        let checklist = ChecklistStore(defaults: previewDefaults)
        for task in ["Read chapter 4: thermodynamics", "Flashcards, 30 min", "Past paper Q1–Q5",
                     "Summarise lecture notes", "Email study group"] {
            checklist.add(task)
        }
        checklist.toggle(checklist.checklist.items[0].id)
        checklist.toggle(checklist.checklist.items[1].id)

        let idleTimer = TimerController()
        // 25-minute timer with 12:34 to go, as the frames below render it.
        let runningTimer = TimerController(timer: CountdownTimer(
            length: 1_500, phase: .running(endsAt: date.addingTimeInterval(27 + 754))))

        func frame(_ face: ClockFace, at moment: Date, time: Double = 7.3, vinyl: Bool = true, night: Bool = false,
                   controls: Bool = false, muted: Bool = false, rain: Bool = true,
                   timers: TimerController = idleTimer) -> some View {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    DockFrame(face: face, size: size, date: moment, sessionElapsed: session.elapsed(at: moment),
                              recordSpinning: vinyl && !muted, burnInShift: true, night: night)
                        .environment(\.showsRain, rain)
                    if face != .timer, timers.timer.phase != .idle {
                        TimerChip(timer: timers.timer, now: moment) {}
                            .padding(.top, 16)
                            .padding(.trailing, 72)
                    }
                }
                if controls {
                    ControlsBar(face: face, muted: .constant(muted), rainOn: .constant(true), vinylOn: .constant(vinyl),
                                isCharging: true, onNextFace: {}, onSettings: {})
                        .padding(.bottom, 18)
                }
            }
            .frame(width: size.width, height: size.height)
            .environment(timers)
            .environment(checklist)
            .environment(\.frozenMoment, FrozenMoment(time: time, date: moment))
            .environment(\.colorScheme, .dark)
        }

        let lateNight = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 23, minute: 30, second: 12))!
        let moment = date.addingTimeInterval(27)
        for face in ClockFace.allCases {
            try render(frame(face, at: moment), scale: 2, to: out.appendingPathComponent("face-\(face.rawValue).png"))
        }
        try render(frame(.timer, at: moment, timers: runningTimer), scale: 2, to: out.appendingPathComponent("timer-running.png"))
        try render(frame(.digits, at: moment, timers: runningTimer), scale: 2, to: out.appendingPathComponent("digits-timer-chip.png"))
        try render(frame(.room, at: date, time: 61.9, vinyl: false, controls: true, muted: true, rain: false), scale: 2,
                   to: out.appendingPathComponent("room-muted-norain.png"))
        try render(frame(.room, at: date, time: 61.9, vinyl: false, controls: true), scale: 2,
                   to: out.appendingPathComponent("room-controls.png"))
        try render(frame(.digits, at: lateNight, night: true), scale: 2, to: out.appendingPathComponent("digits-night.png"))
        try render(frame(.room, at: lateNight, night: true), scale: 2, to: out.appendingPathComponent("room-night.png"))

        let icon = AppIconArt().frame(width: 1024, height: 1024)
        let iconURL = args.count >= 3 ? URL(fileURLWithPath: args[2]) : out.appendingPathComponent("AppIcon.png")
        try render(icon, scale: 1, to: iconURL, opaque: true)

        try renderAudio(to: out)
        timeSceneFrames(size: size)
        print("wrote previews to \(out.path)")
    }

    /// CPU rasterisation through ImageRenderer at the iPhone 15's 3x scale: a
    /// pessimistic stand-in for the on-device cost, measured against the
    /// 33 ms frame budget at 30 fps.
    @MainActor
    static func timeSceneFrames(size: CGSize) {
        let frames = 30
        var bytes = 0
        let elapsed = ContinuousClock().measure {
            for i in 0..<frames {
                let renderer = ImageRenderer(content: LofiSceneCanvas(time: 5 + Double(i) / 30)
                    .frame(width: size.width, height: size.height))
                renderer.scale = 3
                // cgImage can defer rasterising; reading the bytes forces it.
                if let image = renderer.cgImage, let data = image.dataProvider?.data {
                    bytes += CFDataGetLength(data)
                }
            }
        }
        guard bytes > 0 else { return print("scene: timing unavailable") }
        let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1e3
        print(String(format: "scene: %.1f ms per frame at 3x (%d frames, CPU raster)", ms / Double(frames), frames))
    }

    @MainActor
    static func render(_ view: some View, scale: CGFloat, to url: URL, opaque: Bool = false) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard var image = renderer.cgImage else { throw PreviewError.render(url.lastPathComponent) }
        if opaque, let flat = dropAlpha(image) { image = flat }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw PreviewError.write(url.path)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw PreviewError.write(url.path) }
    }

    /// App Store icons must not carry an alpha channel.
    static func dropAlpha(_ image: CGImage) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }

    static func renderAudio(to out: URL) throws {
        let rate = 48_000
        for (name, rain, vinyl) in [("rain", Float(1), Float(0)), ("vinyl", 0, 1), ("both", 1, 1)] {
            let synth = AmbienceSynth(sampleRate: Double(rate))
            synth.rainLevel = rain
            synth.vinylLevel = vinyl
            let frames = rate * 12
            var left = [Float](repeating: 0, count: frames), right = left
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    var i = 0
                    while i < frames {
                        let n = min(512, frames - i)
                        synth.render(frames: n, left: l.baseAddress! + i, right: r.baseAddress! + i)
                        i += n
                    }
                }
            }
            let steady = left[(rate * 2)...]
            let rms = (steady.reduce(0) { $0 + $1 * $1 } / Float(steady.count)).squareRoot()
            let peak = steady.map(abs).max() ?? 0
            print(String(format: "%@: rms %.4f (%.1f dBFS)  peak %.3f  crest %.1f",
                         name, rms, 20 * log10(rms), peak, peak / rms))
            try WAVFile.data(channels: [left, right], sampleRate: rate).write(to: out.appendingPathComponent("\(name).wav"))
        }
        let chimeRate = 44_100
        try WAVFile.data(channels: [Chime.samples(sampleRate: Double(chimeRate))], sampleRate: chimeRate)
            .write(to: out.appendingPathComponent("chime.wav"))
    }

    enum PreviewError: Error {
        case render(String)
        case write(String)
    }
}

/// The app icon: the rainy night window with its cross frame and a warm
/// lamp glow in the corner, reusing the scene's own drawing.
struct AppIconArt: View {
    var body: some View {
        Canvas(opaque: true) { gc, size in
            let full = CGRect(origin: .zero, size: size)
            gc.fill(Path(full), with: .color(Palette.wallTop))
            let glass = full.insetBy(dx: size.width * 0.1, dy: size.height * 0.1)
            LofiScene.drawNightView(&gc, in: glass, t: 3.2, lampReflection: false)

            // Frame wood lit warm from the lamp's corner; the glass stays clear.
            let bar = size.width * 0.035
            let wood = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [Color(hex: 0x8A5A48), Color(hex: 0x3A2A44), Color(hex: 0x241A30)]),
                center: CGPoint(x: 0, y: size.height), startRadius: 0, endRadius: size.width * 1.2)
            var frame = Path(full)
            frame.addRect(glass)
            gc.fill(frame, with: wood, style: FillStyle(eoFill: true))
            var bars = Path()
            bars.addRect(CGRect(x: glass.midX - bar / 2, y: glass.minY, width: bar, height: glass.height))
            bars.addRect(CGRect(x: glass.minX, y: glass.minY + glass.height * 0.42 - bar / 2, width: glass.width, height: bar))
            gc.fill(bars, with: wood)
            gc.stroke(Path(glass), with: .color(.black.opacity(0.35)), lineWidth: 3)
        }
    }
} 
