//
//  DeepFocus.swift
//  Nook
//
//  Created by Yedil on 06.02.2026.
//

import SwiftUI
import UIKit
import AudioToolbox

@MainActor
final class HapticPulse: ObservableObject {
    private let light  = UIImpactFeedbackGenerator(style: .heavy)
    @Published var isOn = true

    func prepare() { light.prepare() }

    func tick() {
        guard isOn else { return }
        light.impactOccurred(intensity: 1)
    }
}

private func hourglassX(y: CGFloat, halfH: CGFloat,
                         outerR: CGFloat, waistR: CGFloat) -> CGFloat {
    let t = abs(y) / halfH
    return waistR + (outerR - waistR) * t
}

private func hourglassOutline(halfW: CGFloat, halfH: CGFloat, waistR: CGFloat) -> Path {
    var p = Path()
    let tl = CGPoint(x: -halfW, y: -halfH)
    let tr = CGPoint(x:  halfW, y: -halfH)
    let wr = CGPoint(x:  waistR, y: 0)
    let wl = CGPoint(x: -waistR, y: 0)
    let br = CGPoint(x:  halfW, y:  halfH)
    let bl = CGPoint(x: -halfW, y:  halfH)

    p.move(to: tl)
    p.addLine(to: tr)
    p.addQuadCurve(to: wr, control: CGPoint(x: halfW * 0.28, y: -halfH * 0.12))
    p.addLine(to: br)
    p.addLine(to: bl)
    p.addQuadCurve(to: wl, control: CGPoint(x: -halfW * 0.28, y: halfH * 0.12))
    p.closeSubpath()
    return p
}

private func bottomSandPath(progress: Double,
                             halfW: CGFloat, halfH: CGFloat, waistR: CGFloat) -> Path {
    let p = CGFloat(progress)
    let surfaceY = halfH * (1 - p)
    let surfaceX = hourglassX(y: surfaceY, halfH: halfH, outerR: halfW, waistR: waistR)

    var path = Path()
    path.move(to: CGPoint(x: -surfaceX, y: surfaceY))
    path.addLine(to: CGPoint(x:  surfaceX, y: surfaceY))
    path.addLine(to: CGPoint(x:  halfW,    y: halfH))
    path.addLine(to: CGPoint(x: -halfW,    y: halfH))
    path.closeSubpath()
    return path
}

private func topSandPath(progress: Double,
                          halfW: CGFloat, halfH: CGFloat, waistR: CGFloat) -> Path {
    let p      = CGFloat(progress)
    let floorY  = -halfH * p
    let floorX  = hourglassX(y: floorY, halfH: halfH, outerR: halfW, waistR: waistR)

    var path = Path()
    path.move(to: CGPoint(x: -halfW,  y: -halfH))
    path.addLine(to: CGPoint(x: halfW,   y: -halfH))
    path.addLine(to: CGPoint(x: floorX,  y: floorY))
    path.addLine(to: CGPoint(x: -floorX, y: floorY))
    path.closeSubpath()
    return path
}

struct DeepFocusView: View {
    @Binding var path: NavigationPath
    @StateObject private var haptic = HapticPulse()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isRunning   = false
    @State private var elapsed: TimeInterval = 0
    @State private var duration: TimeInterval = 25 * 60
    @State private var controlsVisible = true
    @State private var controlsFade = false
    @State private var showCustomPicker = false
    @State private var customMinutes = 30
    private var isCustomDuration: Bool {
        !durationOptions.map(\.seconds).contains(duration)
    }

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double { min(elapsed / duration, 1.0) }
    private var isFinished: Bool  { elapsed >= duration }

    private func formatRemaining() -> String {
        let rem = max(duration - elapsed, 0)
        let m   = Int(rem) / 60
        let s   = Int(rem) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func accessibleRemaining() -> String {
        if isFinished { return "Focus session complete" }
        let rem = max(duration - elapsed, 0)
        let m   = Int(rem) / 60
        let s   = Int(rem) % 60
        switch (m, s) {
        case (0, let s): return "\(s) second\(s == 1 ? "" : "s") remaining"
        case (let m, 0): return "\(m) minute\(m == 1 ? "" : "s") remaining"
        default:         return "\(m) minute\(m == 1 ? "" : "s") and \(s) second\(s == 1 ? "" : "s") remaining"
        }
    }

    private let durationOptions: [(label: String, seconds: TimeInterval)] = [
        ("15 min", 15 * 60),
        ("25 min", 25 * 60),
        ("45 min", 45 * 60),
        ("60 min", 60 * 60),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                Group {
                    if reduceMotion {
                        staticHourglass()
                    } else {
                        TimelineView(.animation) { tl in
                            let t = tl.date.timeIntervalSinceReferenceDate
                            Canvas { ctx, size in
                                drawHourglass(ctx: &ctx, size: size, t: t)
                            }
                        }
                    }
                }
                .frame(width: 130, height: 220)
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
                .onLongPressGesture { handleReset() }
                .accessibilityLabel(
                    isFinished
                        ? "Hourglass, session complete"
                        : "Hourglass, \(Int(progress * 100)) percent complete, \(accessibleRemaining())"
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Tap to \(isRunning ? "pause" : elapsed > 0 ? "resume" : "start"). Long press to reset.")

                Spacer().frame(height: 36)

                Text(isFinished ? "Complete" : formatRemaining())
                    .font(.system(.title3, design: .rounded, weight: .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(isFinished ? 0.80 : 0.55))
                    .animation(.easeInOut(duration: 0.6), value: isFinished)
                    .accessibilityLabel(accessibleRemaining())

                Spacer()

                VStack(spacing: 20) {

                    if !isRunning && elapsed == 0 {
                        HStack(spacing: 8) {
                            ForEach(durationOptions, id: \.seconds) { opt in
                                Button {
                                    duration = opt.seconds
                                    elapsed  = 0
                                    showCustomPicker = false
                                } label: {
                                    Text(opt.label)
                                        .font(.caption.weight(.ultraLight))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            duration == opt.seconds
                                                ? Color.white.opacity(0.18)
                                                : Color.white.opacity(0.07)
                                        )
                                        .clipShape(Capsule())
                                        .foregroundStyle(.white.opacity(0.70))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(opt.label)
                                .accessibilityHint("Sets focus session duration")
                                .accessibilityAddTraits(duration == opt.seconds ? .isSelected : [])
                            }

                            Button {
                                showCustomPicker.toggle()
                            } label: {
                                Text(isCustomDuration ? "\(Int(duration / 60)) min" : "Custom")
                                    .font(.caption.weight(.ultraLight))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        isCustomDuration
                                            ? Color.white.opacity(0.18)
                                            : Color.white.opacity(0.07)
                                    )
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isCustomDuration ? "Custom duration, \(Int(duration / 60)) minutes" : "Custom duration")
                            .accessibilityHint(showCustomPicker ? "Closes the duration picker" : "Opens a picker to set a custom session length")
                            .accessibilityAddTraits(isCustomDuration ? .isSelected : [])
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                        if showCustomPicker {
                            VStack(spacing: 6) {
                                Picker("Minutes", selection: $customMinutes) {
                                    ForEach(1...120, id: \.self) { m in
                                        Text("\(m) min")
                                            .foregroundStyle(.white.opacity(0.75))
                                            .tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 110)
                                .colorScheme(.dark)
                                .onChange(of: customMinutes) { _, newVal in
                                    duration = TimeInterval(newVal * 60)
                                    elapsed  = 0
                                }

                                Button("Set \(customMinutes) min") {
                                    duration = TimeInterval(customMinutes * 60)
                                    elapsed  = 0
                                    showCustomPicker = false
                                }
                                .font(.caption.weight(.ultraLight))
                                .foregroundStyle(.white.opacity(0.60))
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeInOut(duration: 0.25), value: showCustomPicker)
                        }
                    }

                    if !isFinished {
                        HStack(spacing: 12) {
                            Button {
                                handleTap()
                            } label: {
                                Label(
                                    isRunning ? "Pause" : (elapsed > 0 ? "Resume" : "Begin Focus"),
                                    systemImage: isRunning ? "pause" : "play.fill"
                                )
                                .font(.subheadline.weight(.ultraLight))
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isRunning ? "Pause focus session" : (elapsed > 0 ? "Resume focus session" : "Begin focus session"))
                            .accessibilityHint(isRunning ? "Pauses the timer" : "Starts the timer")

                            if elapsed > 0 {
                                Button {
                                    handleReset()
                                } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                        .font(.subheadline.weight(.ultraLight))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.07))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                                .accessibilityLabel("Reset timer")
                                .accessibilityHint("Stops the session and resets to zero")
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: elapsed > 0)
                    } else {
                        Button {
                            handleReset()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.ultraLight))
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start a new session")
                        .accessibilityHint("Resets the timer so you can begin again")
                    }

                    Button {
                        haptic.isOn.toggle()
                    } label: {
                        Label(
                            haptic.isOn ? "Pulse On" : "Pulse Off",
                            systemImage: haptic.isOn ? "waveform" : "waveform.slash"
                        )
                        .font(.caption.weight(.ultraLight))
                        .foregroundStyle(.white.opacity(haptic.isOn ? 0.60 : 0.28))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Haptic pulse")
                    .accessibilityValue(haptic.isOn ? "On" : "Off")
                    .accessibilityHint("Toggles the repeating haptic rhythm during focus")
                }
                .opacity(controlsFade ? 0 : 1)
                .animation(.easeInOut(duration: 1.2), value: controlsFade)
                .padding(.bottom, 52)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onReceive(ticker) { _ in
            guard isRunning, !isFinished else { return }
            elapsed += 1
            haptic.tick()
            if elapsed == 4, !voiceOverEnabled { controlsFade = true }
        }
        .onAppear { haptic.prepare() }
        .onDisappear {
            isRunning   = false
            controlsFade = false
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                if controlsFade {
                    controlsFade = false
                    if isRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if isRunning { controlsFade = true }
                        }
                    }
                }
            }
        )
    }

    private func handleTap() {
        isRunning.toggle()
        if isRunning {
            haptic.prepare()
            controlsFade = false
            if !voiceOverEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    if isRunning { controlsFade = true }
                }
            }
        } else {
            controlsFade = false
        }
    }

    private func handleReset() {
        isRunning    = false
        elapsed      = 0
        controlsFade = false
    }

    private func drawHourglass(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width  / 2
        let cy = size.height / 2
        let halfW = size.width  * 0.42
        let halfH = size.height * 0.46
        let waistR = size.width  * 0.045

        ctx.translateBy(x: cx, y: cy)

        let outline = hourglassOutline(halfW: halfW, halfH: halfH, waistR: waistR)
        let btm     = bottomSandPath(progress: progress, halfW: halfW, halfH: halfH, waistR: waistR)
        let top     = topSandPath(progress: progress,    halfW: halfW, halfH: halfH, waistR: waistR)

        let sandGrad = Gradient(stops: [
            .init(color: Color(red: 0.85, green: 0.55, blue: 0.20, opacity: 0.90), location: 0.0),
            .init(color: Color(red: 0.65, green: 0.35, blue: 0.08, opacity: 0.75), location: 1.0),
        ])
        var btmCtx = ctx
        btmCtx.clip(to: outline)
        btmCtx.fill(btm, with: .linearGradient(sandGrad,
            startPoint: CGPoint(x: 0, y: 0),
            endPoint:   CGPoint(x: 0, y: halfH)))

        var topCtx = ctx
        topCtx.clip(to: outline)
        topCtx.fill(top, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.90, green: 0.62, blue: 0.25, opacity: 0.85), location: 0.0),
                .init(color: Color(red: 0.70, green: 0.40, blue: 0.12, opacity: 0.70), location: 1.0),
            ]),
            startPoint: CGPoint(x: 0, y: -halfH),
            endPoint: CGPoint(x: 0, y: 0)))

        if isRunning, !isFinished, progress < 1.0 {
            let streamAmp = CGFloat(sin(t * 3.5)) * waistR * 0.4
            let streamH = halfH * 0.35
            let yStart: CGFloat = waistR * 0.5
            let yEnd = yStart + streamH
            let rect = CGRect(x: -1.2 + streamAmp, y: yStart, width: 2.4, height: yEnd - yStart)
            var sc = ctx
            sc.clip(to: outline)
            sc.fill(Path(rect), with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 1.0, green: 0.75, blue: 0.35, opacity: 0.80), location: 0.0),
                    .init(color: Color(red: 1.0, green: 0.75, blue: 0.35, opacity: 0.00), location: 1.0),
                ]),
                startPoint: CGPoint(x: 0, y: yStart),
                endPoint: CGPoint(x: 0, y: yEnd)))
        }

        ctx.stroke(outline,
                   with: .color(.white.opacity(0.18)),
                   lineWidth: 1.2)

        if isRunning, !isFinished {
            let glowPulse = 0.10 + 0.06 * sin(t * 1.8)
            let glowRect  = CGRect(x: -halfW * 0.5, y: -halfH * 0.08,
                                    width: halfW, height: halfH * 0.16)
            ctx.fill(Path(ellipseIn: glowRect),
                     with: .color(Color(red: 1.0, green: 0.65, blue: 0.2,
                                        opacity: glowPulse)))
        }
    }

    @ViewBuilder
    private func staticHourglass() -> some View {
        Canvas { ctx, size in
            drawHourglass(ctx: &ctx, size: size, t: 0)
        }
    }
}
