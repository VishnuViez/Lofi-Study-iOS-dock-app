import SwiftUI

/// The animated study room, drawn entirely in code.
///
/// Every element is a pure function of the canvas size and `t` (seconds since
/// the scene appeared), so any frame can be reproduced exactly; the macOS
/// preview tool and the app icon rely on that.
struct LofiScene {
    let size: CGSize
    let t: Double
    var recordSpinning = true
    var rain = true

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }

    // MARK: Layout (fractions of the canvas, tuned on iPhone 15 landscape)

    var windowRect: CGRect { CGRect(x: w * 0.06, y: h * 0.08, width: w * 0.44, height: h * 0.62) }
    private var frameWidth: CGFloat { max(4, h * 0.022) }
    var glassRect: CGRect { windowRect.insetBy(dx: frameWidth, dy: frameWidth) }
    private var deskTop: CGFloat { h * 0.80 }
    private var deskTopHeight: CGFloat { h * 0.035 }
    /// Where objects meet the desk surface.
    private var objectBase: CGFloat { deskTop + deskTopHeight * 0.6 }

    private var lampBase: CGPoint { CGPoint(x: w * 0.11, y: objectBase) }
    private var lampElbow: CGPoint { CGPoint(x: w * 0.082, y: h * 0.585) }
    private var lampPivot: CGPoint { CGPoint(x: w * 0.15, y: h * 0.445) }
    private static let lampTilt = Angle.degrees(-34)
    private var shadeLength: CGFloat { h * 0.085 }
    private var shadeMouth: CGFloat { h * 0.115 }
    private var lampMouth: CGPoint { lampPivot + rotated(CGPoint(x: 0, y: shadeLength), by: Self.lampTilt) }

    private var mugRect: CGRect {
        let mw = h * 0.068, mh = h * 0.082
        return CGRect(x: w * 0.365 - mw / 2, y: objectBase - mh, width: mw, height: mh)
    }

    func draw(in gc: inout GraphicsContext) {
        drawWall(&gc)
        Self.drawNightView(&gc, in: glassRect, t: t, rain: rain)
        drawWindowFrame(&gc)
        drawDesk(&gc)
        drawLampLight(&gc)
        drawBooks(&gc)
        drawMug(&gc)
        drawPlant(&gc)
        drawTurntable(&gc)
        drawLamp(&gc)
        drawSteam(&gc)
        drawFairyLights(&gc)
        drawVignette(&gc)
    }
}

// MARK: - The view through the window

extension LofiScene {
    /// Sky, moon, city and rain inside `glass`. Also used for the app icon.
    static func drawNightView(_ gc: inout GraphicsContext, in glass: CGRect, t: Double,
                              rain: Bool = true, lampReflection: Bool = true) {
        var g = gc
        g.clip(to: Path(glass))
        // Sizes of small details scale with the glass; 230 pt is its height on iPhone 15.
        let k = glass.height / 230

        g.fill(Path(glass), with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0x0A0E2A), location: 0),
                .init(color: Color(hex: 0x221C48), location: 0.45),
                .init(color: Color(hex: 0x4A3266), location: 0.8),
                .init(color: Color(hex: 0x7C4C6A), location: 1),
            ]),
            startPoint: CGPoint(x: glass.midX, y: glass.minY),
            endPoint: CGPoint(x: glass.midX, y: glass.maxY)))

        drawStars(&g, glass, t, k)
        drawMoon(&g, glass)
        drawClouds(&g, glass, t)
        drawSkyline(&g, glass, t, k, layer: 0)
        drawSkyline(&g, glass, t, k, layer: 1)
        if rain {
            drawRain(&g, glass, t, k)
            drawBeads(&g, glass, t, k)
        }
        drawGlassSheen(&g, glass, lampReflection: lampReflection)
    }

    private static func drawStars(_ g: inout GraphicsContext, _ glass: CGRect, _ t: Double, _ k: CGFloat) {
        for i in 0..<46 {
            let x = glass.minX + rnd(i, 11) * glass.width
            let y = glass.minY + rnd(i, 12) * glass.height * 0.6
            let r = (0.4 + rnd(i, 13) * 0.9) * k
            let rate = 0.5 + 1.5 * SceneRandom.unit(i, 14)
            let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * rate + SceneRandom.unit(i, 15) * 2 * .pi))
            g.fill(Path(ellipseIn: circleRect(CGPoint(x: x, y: y), r)),
                   with: .color(Color(hex: 0xFFF3DA, opacity: 0.85 * twinkle)))
        }
    }

    private static func drawMoon(_ g: inout GraphicsContext, _ glass: CGRect) {
        let c = CGPoint(x: glass.minX + glass.width * 0.74, y: glass.minY + glass.height * 0.24)
        let r = glass.height * 0.075
        g.fill(Path(ellipseIn: circleRect(c, r * 5)), with: .radialGradient(
            glowGradient(0xF3E3C3, 0.26), center: c, startRadius: r * 0.8, endRadius: r * 5))
        let disc = Path(ellipseIn: circleRect(c, r))
        let shadow = Path(ellipseIn: circleRect(CGPoint(x: c.x - r * 0.42, y: c.y - r * 0.2), r * 0.92))
        g.fill(disc, with: .color(Color(hex: 0xF4E6C6, opacity: 0.07)))  // earthshine on the dark side
        g.fill(disc.subtracting(shadow), with: .color(Color(hex: 0xF4E6C6)))
    }

    private static func drawClouds(_ g: inout GraphicsContext, _ glass: CGRect, _ t: Double) {
        let span = glass.width * 1.8
        for i in 0..<3 {
            let speed = Double(glass.width * (0.006 + 0.005 * rnd(i, 21)))
            let travel = CGFloat(fract((Double(rnd(i, 22) * span) + t * speed) / Double(span))) * span
            let x = glass.minX - glass.width * 0.4 + travel
            let y = glass.minY + glass.height * (0.3 + 0.2 * rnd(i, 23))
            let cw = glass.width * (0.3 + 0.2 * rnd(i, 24)), ch = glass.height * 0.055
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: x - cw * 0.5, y: y - ch * 0.5, width: cw * 0.6, height: ch))
            cloud.addEllipse(in: CGRect(x: x - cw * 0.25, y: y - ch, width: cw * 0.55, height: ch * 1.4))
            cloud.addEllipse(in: CGRect(x: x, y: y - ch * 0.45, width: cw * 0.5, height: ch * 0.95))
            g.fill(cloud, with: .color(Color(hex: 0x9A7BA8, opacity: 0.10)))
        }
    }

    private static func drawSkyline(_ g: inout GraphicsContext, _ glass: CGRect, _ t: Double, _ k: CGFloat, layer: Int) {
        let gw = glass.width, gh = glass.height
        let (minHeight, maxHeight): (CGFloat, CGFloat) = layer == 0 ? (0.28, 0.52) : (0.14, 0.38)
        let litChance: CGFloat = layer == 0 ? 0.16 : 0.28
        let windowSize = max(1.2, gh * 0.011)
        let pitch = windowSize * 2.3

        var bodies = Path(), warm = Path(), cool = Path()
        var beacon = CGPoint.zero
        var tallest: CGFloat = 0
        var x = glass.minX - gw * 0.03 * CGFloat(layer + 1)
        var i = 0
        while x < glass.maxX {
            let seed = layer * 1_000 + i
            let bw = gw * (0.06 + 0.07 * rnd(seed, 31))
            let bh = gh * (minHeight + (maxHeight - minHeight) * rnd(seed, 32))
            let rect = CGRect(x: x, y: glass.maxY - bh, width: bw, height: bh)
            bodies.addRect(rect)
            var roof = rect.minY
            if rnd(seed, 33) < 0.3 {
                let box = CGRect(x: rect.minX + bw * 0.3, y: rect.minY - gh * 0.03, width: bw * 0.35, height: gh * 0.03)
                bodies.addRect(box)
                roof = box.minY
            }
            if bh > tallest {
                tallest = bh
                beacon = CGPoint(x: rect.midX, y: roof - 2 * k)
            }

            let cols = Int((bw - pitch * 0.6) / pitch), rows = Int((bh - pitch * 0.6) / pitch)
            for row in 0..<max(0, rows) {
                for col in 0..<max(0, cols) {
                    let key = seed &* 4_096 &+ row &* 64 &+ col
                    // Most windows keep their state; about a third switch now and then.
                    var epoch = 0
                    if rnd(key, 45) < 0.3 {
                        let period = 40 + 120 * SceneRandom.unit(key, 41)
                        epoch = Int(((t + SceneRandom.unit(key, 42) * period) / period).rounded(.down))
                    }
                    guard rnd(key, 43 &+ epoch &* 7) < litChance else { continue }
                    let lit = CGRect(x: rect.minX + pitch * 0.6 + CGFloat(col) * pitch,
                                     y: rect.minY + pitch * 0.6 + CGFloat(row) * pitch,
                                     width: windowSize, height: windowSize)
                    if rnd(key, 44) < 0.82 { warm.addRect(lit) } else { cool.addRect(lit) }
                }
            }
            x += bw + gw * 0.006 * rnd(seed, 34)
            i += 1
        }

        g.fill(bodies, with: .color(layer == 0 ? Color(hex: 0x2A2148) : Color(hex: 0x140E25)))
        let brightness = layer == 0 ? 0.45 : 0.85
        g.fill(warm, with: .color(Color(hex: 0xFFC777, opacity: brightness)))
        g.fill(cool, with: .color(Color(hex: 0x9ED6E6, opacity: brightness * 0.8)))

        guard layer == 1 else { return }
        // Aircraft warning light on the tallest tower.
        let on = fract(t / 2.4) < 0.12
        let r = 1.3 * k
        g.fill(Path(ellipseIn: circleRect(beacon, r * 5)), with: .radialGradient(
            glowGradient(0xFF4D4D, on ? 0.5 : 0.08), center: beacon, startRadius: 0, endRadius: r * 5))
        g.fill(Path(ellipseIn: circleRect(beacon, r)), with: .color(Color(hex: 0xFF5A5A, opacity: on ? 1 : 0.35)))
    }

    static func drawRain(_ g: inout GraphicsContext, _ glass: CGRect, _ t: Double, _ k: CGFloat) {
        let slant: CGFloat = 0.16
        let layers: [(count: Int, speed: CGFloat, length: CGFloat, width: CGFloat, opacity: Double)] = [
            (70, 0.85, 0.035, 0.6, 0.16),  // far, fine
            (45, 1.45, 0.065, 0.9, 0.26),  // near, heavier
        ]
        for (index, layer) in layers.enumerated() {
            let length = glass.height * layer.length
            let travel = glass.height + length * 2
            let cycle = Double(travel / (glass.height * layer.speed))
            var streaks = Path()
            for i in 0..<layer.count {
                let seed = index * 500 + i
                let fall = t / cycle + SceneRandom.unit(seed, 51)
                let lap = Int(fall.rounded(.down))
                let y = glass.minY - length + CGFloat(fall - Double(lap)) * travel
                // A new column on every fall, so no streak retraces the same line.
                let column = rnd(seed &* 31 &+ lap, 52) * (glass.width + slant * glass.height)
                let x = glass.minX + column - slant * (y - glass.minY)
                streaks.move(to: CGPoint(x: x, y: y))
                streaks.addLine(to: CGPoint(x: x + slant * length, y: y - length))
            }
            g.stroke(streaks, with: .color(Color(hex: 0xD2DBF2, opacity: layer.opacity)),
                     style: StrokeStyle(lineWidth: layer.width * k, lineCap: .round))
        }
    }

    /// Drops clinging to the glass, sliding slowly down with a faint trail.
    private static func drawBeads(_ g: inout GraphicsContext, _ glass: CGRect, _ t: Double, _ k: CGFloat) {
        for i in 0..<14 {
            let r = (1.2 + 1.8 * rnd(i, 61)) * k
            let run = t * (0.02 + 0.06 * SceneRandom.unit(i, 62)) + SceneRandom.unit(i, 63)
            let lap = Int(run.rounded(.down))
            let y = glass.minY - 2 * r + CGFloat(run - Double(lap)) * (glass.height + 4 * r)
            let x = glass.minX + rnd(i &* 17 &+ lap, 64) * glass.width + CGFloat(sin(t * 0.9 + Double(i))) * 0.8 * k
            let trail = CGRect(x: x - r * 0.3, y: y - glass.height * 0.08, width: r * 0.6, height: glass.height * 0.08)
            g.fill(Path(roundedRect: trail, cornerRadius: r * 0.3), with: .linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(0.10)]),
                startPoint: CGPoint(x: x, y: trail.minY), endPoint: CGPoint(x: x, y: trail.maxY)))
            g.fill(Path(ellipseIn: circleRect(CGPoint(x: x, y: y), r)), with: .color(.white.opacity(0.16)))
            g.fill(Path(ellipseIn: circleRect(CGPoint(x: x - r * 0.3, y: y - r * 0.3), r * 0.35)),
                   with: .color(.white.opacity(0.5)))
        }
    }

    private static func drawGlassSheen(_ g: inout GraphicsContext, _ glass: CGRect, lampReflection: Bool) {
        g.fill(Path(glass), with: .linearGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.06), location: 0),
                .init(color: .white.opacity(0), location: 0.45),
                .init(color: .white.opacity(0.03), location: 1),
            ]),
            startPoint: CGPoint(x: glass.minX, y: glass.minY),
            endPoint: CGPoint(x: glass.maxX, y: glass.maxY)))
        guard lampReflection else { return }
        let c = CGPoint(x: glass.minX + glass.width * 0.2, y: glass.maxY - glass.height * 0.22)
        let r = glass.height * 0.4
        g.fill(Path(ellipseIn: circleRect(c, r)), with: .radialGradient(
            glowGradient(0xFFB45E, 0.12), center: c, startRadius: 0, endRadius: r))
    }
}

// MARK: - The room

private extension LofiScene {
    func drawWall(_ gc: inout GraphicsContext) {
        let room = Path(CGRect(origin: .zero, size: size))
        gc.fill(room, with: .linearGradient(
            Gradient(colors: [Palette.wallTop, Palette.wallBottom]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        gc.fill(room, with: .radialGradient(
            glowGradient(0xFFB45E, 0.20), center: lampMouth, startRadius: 0, endRadius: w * 0.55))
    }

    func drawWindowFrame(_ gc: inout GraphicsContext) {
        let glass = glassRect
        let wood = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(hex: 0x3C2B42), Color(hex: 0x231A2E)]),
            startPoint: CGPoint(x: windowRect.minX, y: windowRect.midY),
            endPoint: CGPoint(x: windowRect.maxX, y: windowRect.midY))
        var frame = Path(windowRect)
        frame.addRect(glass)
        gc.fill(frame, with: wood, style: FillStyle(eoFill: true))

        let bar = frameWidth * 0.55
        var bars = Path()
        bars.addRect(CGRect(x: glass.midX - bar / 2, y: glass.minY, width: bar, height: glass.height))
        bars.addRect(CGRect(x: glass.minX, y: glass.minY + glass.height * 0.42 - bar / 2, width: glass.width, height: bar))
        gc.fill(bars, with: wood)
        gc.stroke(Path(glass), with: .color(.black.opacity(0.35)), lineWidth: 1)
        gc.stroke(Path(windowRect), with: .color(Palette.lamp.opacity(0.10)), lineWidth: 1)

        let sill = CGRect(x: windowRect.minX - w * 0.012, y: windowRect.maxY - 1,
                          width: windowRect.width + w * 0.024, height: h * 0.028)
        gc.fill(Path(CGRect(x: sill.minX + 4, y: sill.maxY, width: sill.width - 8, height: h * 0.014)),
                with: .color(.black.opacity(0.22)))
        gc.fill(Path(roundedRect: sill, cornerRadius: 2), with: .color(Color(hex: 0x3F2E3E)))
        gc.fill(Path(CGRect(x: sill.minX, y: sill.minY, width: sill.width, height: 1.5)),
                with: .color(Palette.lamp.opacity(0.2)))
    }

    func drawDesk(_ gc: inout GraphicsContext) {
        let top = CGRect(x: 0, y: deskTop, width: w, height: deskTopHeight)
        gc.fill(Path(top), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x5B4037), Color(hex: 0x47312C)]),
            startPoint: CGPoint(x: 0, y: top.minY), endPoint: CGPoint(x: 0, y: top.maxY)))
        let front = CGRect(x: 0, y: top.maxY, width: w, height: h - top.maxY)
        gc.fill(Path(front), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x2E201E), Color(hex: 0x181012)]),
            startPoint: CGPoint(x: 0, y: front.minY), endPoint: CGPoint(x: 0, y: front.maxY)))
        gc.fill(Path(CGRect(x: 0, y: deskTop, width: w, height: max(1, h * 0.004))),
                with: .color(Palette.lamp.opacity(0.22)))
        gc.fill(Path(CGRect(x: 0, y: top.maxY, width: w, height: 1)), with: .color(.black.opacity(0.45)))
    }

    func drawLampLight(_ gc: inout GraphicsContext) {
        var g = gc
        g.blendMode = .screen
        let half = shadeMouth / 2
        var cone = Path()
        cone.move(to: lampPivot + rotated(CGPoint(x: -half, y: shadeLength), by: Self.lampTilt))
        cone.addLine(to: lampPivot + rotated(CGPoint(x: half, y: shadeLength), by: Self.lampTilt))
        cone.addLine(to: CGPoint(x: w * 0.40, y: deskTop + deskTopHeight))
        cone.addLine(to: CGPoint(x: w * 0.12, y: deskTop + deskTopHeight))
        cone.closeSubpath()
        g.fill(cone, with: .linearGradient(
            glowGradient(0xFFC27A, 0.14),
            startPoint: lampMouth, endPoint: CGPoint(x: lampMouth.x + w * 0.04, y: deskTop)))

        var pool = g
        pool.translateBy(x: w * 0.25, y: deskTop + deskTopHeight * 0.5)
        pool.scaleBy(x: 1, y: 0.16)
        let r = w * 0.2
        pool.fill(Path(ellipseIn: circleRect(.zero, r)), with: .radialGradient(
            glowGradient(0xFFB45E, 0.45), center: .zero, startRadius: 0, endRadius: r))
    }

    func drawLamp(_ gc: inout GraphicsContext) {
        gc.fill(Path(ellipseIn: CGRect(x: lampBase.x - w * 0.03, y: lampBase.y - h * 0.018,
                                       width: w * 0.06, height: h * 0.026)),
                with: .color(Color(hex: 0x27403F)))
        var arm = Path()
        arm.move(to: CGPoint(x: lampBase.x, y: lampBase.y - h * 0.01))
        arm.addLine(to: lampElbow)
        arm.addLine(to: lampPivot)
        gc.stroke(arm, with: .color(Color(hex: 0x35585C)),
                  style: StrokeStyle(lineWidth: max(2, h * 0.011), lineCap: .round, lineJoin: .round))
        for joint in [lampElbow, lampPivot] {
            gc.fill(Path(ellipseIn: circleRect(joint, h * 0.011)), with: .color(Color(hex: 0x4D7A7C)))
        }

        // The shade is drawn pointing straight down in its own rotated space.
        var shade = gc
        shade.translateBy(x: lampPivot.x, y: lampPivot.y)
        shade.rotate(by: Self.lampTilt)
        let half = shadeMouth / 2, neck = shadeMouth * 0.16, cap = -h * 0.012
        var body = Path()
        body.move(to: CGPoint(x: -neck, y: cap))
        body.addLine(to: CGPoint(x: neck, y: cap))
        body.addQuadCurve(to: CGPoint(x: half, y: shadeLength), control: CGPoint(x: half * 0.35, y: shadeLength * 0.45))
        body.addLine(to: CGPoint(x: -half, y: shadeLength))
        body.addQuadCurve(to: CGPoint(x: -neck, y: cap), control: CGPoint(x: -half * 0.35, y: shadeLength * 0.45))
        body.closeSubpath()
        shade.fill(body, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x5C8C8C), Color(hex: 0x2C4747)]),
            startPoint: CGPoint(x: -half, y: 0), endPoint: CGPoint(x: half, y: 0)))
        shade.fill(Path(ellipseIn: CGRect(x: -half, y: shadeLength - shadeMouth * 0.12,
                                          width: shadeMouth, height: shadeMouth * 0.24)),
                   with: .color(Color(hex: 0xFFE6B8)))
        var bulb = shade
        bulb.blendMode = .screen
        let mouth = CGPoint(x: 0, y: shadeLength)
        bulb.fill(Path(ellipseIn: circleRect(mouth, shadeMouth * 1.3)), with: .radialGradient(
            glowGradient(0xFFD08A, 0.55), center: mouth, startRadius: 0, endRadius: shadeMouth * 1.3))
    }

    func drawBooks(_ gc: inout GraphicsContext) {
        let books: [(width: CGFloat, color: UInt32, shift: CGFloat)] = [
            (0.115, 0x7E4545, 0), (0.104, 0x3C6464, 0.006), (0.094, 0xB0873E, -0.004),
        ]
        let thickness = h * 0.03
        var y = objectBase
        for book in books {
            let rect = CGRect(x: w * (0.27 + book.shift - book.width / 2), y: y - thickness,
                              width: w * book.width, height: thickness)
            gc.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Color(hex: book.color)))
            gc.fill(Path(CGRect(x: rect.maxX - w * 0.012, y: rect.minY + thickness * 0.18,
                                width: w * 0.009, height: thickness * 0.64)),
                    with: .color(Palette.cream.opacity(0.8)))
            gc.fill(Path(CGRect(x: rect.minX + w * 0.014, y: rect.minY, width: w * 0.005, height: thickness)),
                    with: .color(.black.opacity(0.2)))
            gc.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1)),
                    with: .color(Palette.lamp.opacity(0.3)))
            y -= thickness
        }
    }

    func drawMug(_ gc: inout GraphicsContext) {
        let r = mugRect
        let handle = CGRect(x: r.maxX - r.width * 0.18, y: r.minY + r.height * 0.22,
                            width: r.width * 0.45, height: r.height * 0.46)
        gc.stroke(Path(roundedRect: handle, cornerRadius: r.width * 0.2),
                  with: .color(Color(hex: 0xC9B79F)), lineWidth: r.width * 0.12)
        gc.fill(Path(roundedRect: r, cornerSize: CGSize(width: r.width * 0.14, height: r.width * 0.14)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xEEDFCA), Color(hex: 0xB9A790)]),
                    startPoint: CGPoint(x: r.minX, y: r.midY), endPoint: CGPoint(x: r.maxX, y: r.midY)))
        gc.fill(Path(CGRect(x: r.minX, y: r.minY + r.height * 0.36, width: r.width, height: r.height * 0.12)),
                with: .color(Color(hex: 0xC9785A)))
        let rim = CGRect(x: r.minX, y: r.minY - r.width * 0.08, width: r.width, height: r.width * 0.16)
        gc.fill(Path(ellipseIn: rim), with: .color(Color(hex: 0xDCCBB3)))
        gc.fill(Path(ellipseIn: rim.insetBy(dx: r.width * 0.08, dy: r.width * 0.025)),
                with: .color(Color(hex: 0x3A2418)))
    }

    func drawPlant(_ gc: inout GraphicsContext) {
        let cx = w * 0.455
        let potHeight = h * 0.075, potTop = objectBase - potHeight
        let topWidth = h * 0.088, bottomWidth = topWidth * 0.74
        let stem = CGPoint(x: cx, y: potTop + potHeight * 0.1)

        for i in 0..<7 {
            let spread = -62.0 + Double(i) * (124.0 / 6)
            let sway = sin(t * 0.55 + Double(i) * 1.37) * 2.5
            let length = h * (0.09 + 0.06 * rnd(i, 71)) * CGFloat(1.15 - abs(spread) / 180)
            var leafSpace = gc
            leafSpace.translateBy(x: stem.x, y: stem.y)
            leafSpace.rotate(by: .degrees(spread + sway))
            var leaf = Path()
            leaf.move(to: .zero)
            leaf.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: length * 0.34, y: -length * 0.5))
            leaf.addQuadCurve(to: .zero, control: CGPoint(x: -length * 0.34, y: -length * 0.5))
            leafSpace.fill(leaf, with: .color(Color(hex: i.isMultiple(of: 2) ? 0x3E6C4F : 0x55885F)))
            var rib = Path()
            rib.move(to: .zero)
            rib.addLine(to: CGPoint(x: 0, y: -length * 0.88))
            leafSpace.stroke(rib, with: .color(.black.opacity(0.18)), lineWidth: 0.8)
        }

        var pot = Path()
        pot.move(to: CGPoint(x: cx - topWidth / 2, y: potTop))
        pot.addLine(to: CGPoint(x: cx + topWidth / 2, y: potTop))
        pot.addLine(to: CGPoint(x: cx + bottomWidth / 2, y: objectBase))
        pot.addLine(to: CGPoint(x: cx - bottomWidth / 2, y: objectBase))
        pot.closeSubpath()
        gc.fill(pot, with: .linearGradient(
            Gradient(colors: [Color(hex: 0xC46E52), Color(hex: 0x8E4A37)]),
            startPoint: CGPoint(x: cx - topWidth / 2, y: potTop), endPoint: CGPoint(x: cx + topWidth / 2, y: potTop)))
        gc.fill(Path(roundedRect: CGRect(x: cx - topWidth * 0.54, y: potTop - potHeight * 0.06,
                                         width: topWidth * 1.08, height: potHeight * 0.22), cornerRadius: 1.5),
                with: .color(Color(hex: 0xD27C5E)))
    }

    func drawTurntable(_ gc: inout GraphicsContext) {
        let box = CGRect(x: w * 0.615, y: objectBase - h * 0.058, width: w * 0.24, height: h * 0.058)
        let deck = CGRect(x: box.minX + w * 0.006, y: box.minY - h * 0.05, width: box.width - w * 0.012, height: h * 0.05)
        gc.fill(Path(roundedRect: deck, cornerRadius: 3), with: .color(Color(hex: 0x3A2A2C)))
        gc.fill(Path(roundedRect: box, cornerRadius: 3), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x6E4C38), Color(hex: 0x4A3124)]),
            startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.minX, y: box.maxY)))
        gc.fill(Path(CGRect(x: box.minX, y: box.minY, width: box.width, height: 1)),
                with: .color(Palette.lamp.opacity(0.18)))

        let led = CGPoint(x: box.minX + box.width * 0.07, y: box.midY)
        gc.fill(Path(ellipseIn: circleRect(led, h * 0.016)), with: .radialGradient(
            glowGradient(0xFFB45E, recordSpinning ? 0.5 : 0), center: led, startRadius: 0, endRadius: h * 0.016))
        gc.fill(Path(ellipseIn: circleRect(led, h * 0.005)),
                with: .color(Color(hex: recordSpinning ? 0xFFC27A : 0x5A3A2A)))
        for k in 0..<2 {
            let knob = CGPoint(x: box.maxX - box.width * (0.08 + 0.09 * CGFloat(k)), y: box.midY)
            gc.fill(Path(ellipseIn: circleRect(knob, h * 0.011)), with: .color(Color(hex: 0x2A1D19)))
        }

        let c = CGPoint(x: deck.minX + deck.width * 0.42, y: deck.midY)
        let rx = deck.width * 0.36, ry = deck.height * 0.4
        func ring(_ f: CGFloat) -> CGRect { CGRect(x: c.x - rx * f, y: c.y - ry * f, width: 2 * rx * f, height: 2 * ry * f) }
        gc.fill(Path(ellipseIn: ring(1)), with: .color(Color(hex: 0x111014)))
        for f: CGFloat in [0.85, 0.7, 0.55] {
            gc.stroke(Path(ellipseIn: ring(f)), with: .color(.white.opacity(0.06)), lineWidth: 0.6)
        }
        // Two glints that sweep round at 33⅓ rpm while the record plays.
        let spin = recordSpinning ? t * 2 * .pi * (100.0 / 3.0) / 60 : 0.6
        for start in [spin, spin + .pi] {
            var glint = Path()
            for s in 0...8 {
                let a = start + Double(s) * 0.09
                let p = CGPoint(x: c.x + rx * 0.72 * CGFloat(cos(a)), y: c.y + ry * 0.72 * CGFloat(sin(a)))
                if s == 0 { glint.move(to: p) } else { glint.addLine(to: p) }
            }
            gc.stroke(glint, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        gc.fill(Path(ellipseIn: ring(0.3)), with: .color(Color(hex: 0xC9785A)))
        gc.fill(Path(ellipseIn: circleRect(c, 1.2)), with: .color(Color(hex: 0xE8D9C4)))

        // Tonearm: on the record while it plays, parked beside it otherwise.
        let pivot = CGPoint(x: deck.maxX - deck.width * 0.08, y: deck.minY + deck.height * 0.3)
        let needle = recordSpinning
            ? CGPoint(x: c.x + rx * 0.58, y: c.y + ry * 0.1)
            : CGPoint(x: deck.maxX - deck.width * 0.05, y: deck.maxY - deck.height * 0.15)
        var arm = Path()
        arm.move(to: pivot)
        arm.addLine(to: CGPoint(x: (pivot.x + needle.x) / 2 + 4, y: min(pivot.y, needle.y) - ry * 0.1))
        arm.addLine(to: needle)
        gc.stroke(arm, with: .color(Color(hex: 0xC9C2B7)),
                  style: StrokeStyle(lineWidth: max(1.2, h * 0.005), lineCap: .round, lineJoin: .round))
        gc.fill(Path(roundedRect: CGRect(x: needle.x - 3, y: needle.y - 2, width: 6, height: 4), cornerRadius: 1),
                with: .color(Color(hex: 0xE0D9CE)))
        gc.fill(Path(ellipseIn: circleRect(pivot, h * 0.013)), with: .color(Color(hex: 0x8A837A)))
    }

    func drawSteam(_ gc: inout GraphicsContext) {
        let origin = CGPoint(x: mugRect.midX, y: mugRect.minY - mugRect.width * 0.06)
        let rise = h * 0.2
        let top = CGPoint(x: origin.x, y: origin.y - rise)
        let halo = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.white.opacity(0.07), .white.opacity(0)]), startPoint: origin, endPoint: top)
        let core = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.white.opacity(0.17), .white.opacity(0)]), startPoint: origin, endPoint: top)
        for i in 0..<3 {
            var wisp = Path()
            for j in 0...28 {
                let s = Double(j) / 28
                let amplitude = h * (0.005 + 0.02 * CGFloat(s))
                // Phase moves with t, so the waves travel upward like rising steam.
                let sway = amplitude * CGFloat(sin(s * 5.5 - t * 1.1 + Double(i) * 2.2))
                let p = CGPoint(x: origin.x + CGFloat(i - 1) * h * 0.011 + sway, y: origin.y - CGFloat(s) * rise)
                if j == 0 { wisp.move(to: p) } else { wisp.addLine(to: p) }
            }
            gc.stroke(wisp, with: halo, style: StrokeStyle(lineWidth: h * 0.02, lineCap: .round, lineJoin: .round))
            gc.stroke(wisp, with: core, style: StrokeStyle(lineWidth: h * 0.006, lineCap: .round, lineJoin: .round))
        }
    }

    func drawFairyLights(_ gc: inout GraphicsContext) {
        let hooks = [(-0.02, 0.03), (0.27, 0.036), (0.56, 0.03), (0.83, 0.036), (1.02, 0.03)]
            .map { CGPoint(x: w * $0.0, y: h * $0.1) }
        let sag = h * 0.11  // quad control drop; the wire hangs half this at mid-span
        var wire = Path()
        var bulbs: [CGPoint] = []
        for (a, b) in zip(hooks, hooks.dropFirst()) {
            let control = CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + sag)
            wire.move(to: a)
            wire.addQuadCurve(to: b, control: control)
            for step in 1...7 {
                let s = CGFloat(step) / 8, u = 1 - s
                bulbs.append(CGPoint(x: u * u * a.x + 2 * u * s * control.x + s * s * b.x,
                                     y: u * u * a.y + 2 * u * s * control.y + s * s * b.y))
            }
        }
        gc.stroke(wire, with: .color(Color(hex: 0x0C0912, opacity: 0.85)), lineWidth: max(0.8, h * 0.0025))

        let colors: [UInt32] = [0xFFC46B, 0xFF9F7A, 0xFFE2A0, 0xFFB45E]
        var glowLayer = gc
        glowLayer.blendMode = .screen
        let r = h * 0.007
        for (i, p) in bulbs.enumerated() {
            let wave = sin(t * (0.7 + 0.9 * SceneRandom.unit(i, 81)) + SceneRandom.unit(i, 82) * 2 * .pi)
            let twinkle = 0.6 + 0.4 * (0.5 + 0.5 * wave)
            let hex = colors[i % colors.count]
            let bulb = CGPoint(x: p.x, y: p.y + r)
            glowLayer.fill(Path(ellipseIn: circleRect(bulb, r * 5)), with: .radialGradient(
                glowGradient(hex, 0.42 * twinkle), center: bulb, startRadius: 0, endRadius: r * 5))
            gc.fill(Path(ellipseIn: circleRect(bulb, r)), with: .color(Color(hex: hex, opacity: 0.7 + 0.3 * twinkle)))
        }
    }

    func drawVignette(_ gc: inout GraphicsContext) {
        gc.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [.black.opacity(0), .black.opacity(0.42)]),
            center: CGPoint(x: w * 0.5, y: h * 0.45), startRadius: h * 0.5, endRadius: w * 0.62))
    }
}

// MARK: - Geometry helpers

func circleRect(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

/// A colour fading to fully transparent, for glows.
func glowGradient(_ hex: UInt32, _ opacity: Double) -> Gradient {
    Gradient(colors: [Color(hex: hex, opacity: opacity), Color(hex: hex, opacity: 0)])
}

private func rotated(_ p: CGPoint, by angle: Angle) -> CGPoint {
    let c = CGFloat(cos(angle.radians)), s = CGFloat(sin(angle.radians))
    return CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
}

private func + (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}
