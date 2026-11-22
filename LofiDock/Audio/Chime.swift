import Foundation

/// The timer's "time's up" sound: three soft rising bell strikes, generated in
/// code like the rest of the audio.
enum Chime {
    static let peak: Float = 0.6

    static func samples(sampleRate: Double) -> [Float] {
        let strikes: [(time: Double, frequency: Double)] = [(0, 659.25), (0.45, 783.99), (0.9, 987.77)]  // E5 G5 B5
        let count = Int(3.0 * sampleRate)
        var out = [Float](repeating: 0, count: count)
        for strike in strikes {
            let start = Int(strike.time * sampleRate)
            let f = strike.frequency
            for i in start..<count {
                let t = Double(i - start) / sampleRate
                let attack = min(1, t / 0.004)  // 4 ms ramp so the strike doesn't click
                // A bell's partials are inharmonic and the high ones die first.
                let tone = sin(2 * .pi * f * t)
                    + 0.45 * sin(2 * .pi * 2.76 * f * t) * exp(-t / 0.35)
                    + 0.25 * sin(2 * .pi * 5.4 * f * t) * exp(-t / 0.15)
                out[i] += Float(attack * exp(-t / 0.9) * tone)
            }
        }
        let tail = Int(0.1 * sampleRate)
        for i in (count - tail)..<count {
            out[i] *= Float(count - i) / Float(tail)
        }
        let loudest = out.map(abs).max() ?? 1
        return out.map { $0 / loudest * peak }
    }
}

/// 16-bit PCM WAV encoding.
enum WAVFile {
    /// `channels` are equal-length sample arrays; two or more are interleaved.
    static func data(channels: [[Float]], sampleRate: Int) -> Data {
        let frames = channels.first?.count ?? 0
        let channelCount = channels.count
        let bytes = frames * channelCount * 2
        var data = Data(capacity: 44 + bytes)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1))
        append(UInt16(channelCount)); append(UInt32(sampleRate))
        append(UInt32(sampleRate * channelCount * 2)); append(UInt16(channelCount * 2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(bytes))
        for i in 0..<frames {
            for channel in channels {
                append(Int16((max(-1, min(1, channel[i])) * 32_767).rounded()))
            }
        }
        return data
    }
}

/// The chime as a file in Library/Sounds, the one folder both AVAudioPlayer
/// and notification sounds can play from. Written on first use.
enum ChimeFile {
    static let name = "LofiChime-1.wav"

    static func url(fileManager: FileManager = .default) -> URL? {
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let folder = library.appendingPathComponent("Sounds", isDirectory: true)
        let url = folder.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let rate = 44_100
            try? WAVFile.data(channels: [Chime.samples(sampleRate: Double(rate))], sampleRate: rate).write(to: url)
        }
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
} 
