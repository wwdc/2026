//
//  Companion.swift
//  Nook
//
//  Created by Yedil on 06.02.2026.
//

import SwiftUI
import UIKit
import CoreMotion
import AudioToolbox
import AVFoundation
import FoundationModels
import Foundation

@MainActor
final class MotionDetector: ObservableObject {
    private let motion = CMMotionManager()

    @Published var isRunning = false
    @Published var alarmTriggered = false
    @Published var detectCount = 0
    @Published var lastDetectedAt: Date?
    @Published var magnitude: Double = 0

    private let cooldown: TimeInterval = 3
    private var lastTriggerTime: Date?  = nil

    private let notifier = UINotificationFeedbackGenerator()
    private let impactor = UIImpactFeedbackGenerator(style: .heavy)

    func start() {
        notifier.prepare()
        impactor.prepare()
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.05
        isRunning = true
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            let mag = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
            self.magnitude = mag

            let now = Date()
            let cooledDown = self.lastTriggerTime.map {
                now.timeIntervalSince($0) >= self.cooldown
            } ?? true

            if mag > 1.5, cooledDown {
                self.detectCount    += 1
                self.lastDetectedAt  = now
                self.lastTriggerTime = now
                self.alarmTriggered  = true

                self.notifier.notificationOccurred(.error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.impactor.impactOccurred(intensity: 1.0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    self.impactor.impactOccurred(intensity: 1.0)
                    self.notifier.prepare()
                    self.impactor.prepare()
                }

                DispatchQueue.main.async { self.alarmTriggered = false }
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        isRunning  = false
        magnitude  = 0
    }

    func reset() {
        stop()
        detectCount     = 0
        lastDetectedAt  = nil
        lastTriggerTime = nil
    }
}

@MainActor
final class DecibelMonitor: ObservableObject {
    @Published var decibels: Float = -160
    @Published var isRunning = false
    @Published var silenceDetected = false

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var silenceSince: Date?

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted, let self else { return }
            Task { @MainActor in self.setup() }
        }
    }

    private func setup() {
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]
        let url = URL(fileURLWithPath: "/dev/null")
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.isMeteringEnabled = true
        rec.prepareToRecord()
        rec.record()
        recorder = rec
        isRunning = true
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func update() {
        guard let rec = recorder else { return }
        rec.updateMeters()
        decibels = rec.averagePower(forChannel: 0)

        if decibels < -30 {
            if silenceSince == nil { silenceSince = Date() }
            if let since = silenceSince,
               Date().timeIntervalSince(since) >= 10 {
                silenceSince = nil
                silenceDetected = true
                DispatchQueue.main.async { self.silenceDetected = false }
            }
        } else {
            silenceSince = nil
        }
    }

    func stop() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        isRunning = false
        decibels = -160
        silenceSince = nil
        silenceDetected = false
    }
}

@MainActor
func generateWritingPrompt(promptText: String) async -> String {
    let model = SystemLanguageModel.default
    guard model.availability == .available else {
        return "Model unavailable on this device."
    }

    let session = LanguageModelSession(
        instructions: """
        You are a warm, thoughtful conversation facilitator for a gadget-free dinner table.
        Your goal is to help people genuinely connect, reflect, and share meaningful stories over a meal.
        When asked for a conversation starter, output exactly one question or prompt: 2–3 sentences.
        Start with a specific, grounding question, then gently invite reflection or a follow-up angle.
        Keep the tone warm, curious, and inclusive — suitable for all ages and backgrounds.
        Go a little deeper than surface level: encourage storytelling, emotion, or personal insight.
        Avoid controversial topics, politics, religion, or anything that could cause discomfort.
        Plain text only — no preamble, no labels, no bullet points, no formatting, no emojis.
        """
    )
    do {
        let response = try await session.respond(to: promptText)
        return response.content
    } catch {
        return "Generation error: \(error.localizedDescription)"
    }
}



struct CompanionView: View {
    @Binding var path: NavigationPath
    @StateObject private var detector = MotionDetector()
    @StateObject private var decibelMonitor = DecibelMonitor()
    @State private var timeElapsed: TimeInterval = 0
    @State private var showingAlert = false
    @State private var generatedPrompt: String = ""
    @State private var isGenerating = false
    @State private var promptCount = 0
    @State private var lastPromptAt: Date? = nil

    private let promptCooldown: TimeInterval = 5 * 60

    private let promptThemes: [String] = [
        "a childhood memory that still feels vivid — what made it so memorable and how it shaped who you are today",
        "a book, film, or song that genuinely changed the way you see the world — what it made you feel and whether that perspective stuck",
        "a moment when a stranger's small act of kindness caught you completely off guard — what happened and why it stayed with you",
        "a place you've always felt drawn to visit — not just what it looks like, but what you imagine you'd feel or discover there",
        "a skill or craft you've always admired from afar — what stops you from pursuing it and what it would mean if you did",
        "the best meal you've ever had — not just the food, but the people, the setting, and the feeling around the table",
        "someone outside your family who quietly shaped the person you became — what they did and whether they know the impact they had",
        "a belief or assumption you held firmly when you were younger that life gradually proved wrong — and what replaced it",
        "something ordinary in your daily life that you'd genuinely miss if it disappeared — and why it matters more than it might seem",
        "a challenge you faced that felt overwhelming at the time — and what you learned about yourself on the other side of it",
    ]

    private var canGeneratePrompt: Bool {
        guard !isGenerating else { return false }
        guard let last = lastPromptAt else { return true }
        return Date().timeIntervalSince(last) >= promptCooldown
    }

    private var cooldownRemaining: TimeInterval {
        guard let last = lastPromptAt else { return 0 }
        return max(0, promptCooldown - Date().timeIntervalSince(last))
    }

    private func buildPromptText() -> String {
        let minutes = Int(timeElapsed / 60)
        let stage: String
        switch minutes {
        case 0..<5:  stage = "just sat down for dinner"
        case 5..<15: stage = "been at the table for about \(minutes) minutes"
        case 15..<30: stage = "been enjoying dinner together for \(minutes) minutes"
        default:     stage = "been sharing a long, relaxed meal for over \(minutes) minutes"
        }
        let theme = promptThemes[promptCount % promptThemes.count]
        return "We have \(stage) with no phones. Give us exactly one warm, friendly conversation starter about \(theme)."
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func accessibleTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        switch (m, s) {
        case (0, let s): return "\(s) second\(s == 1 ? "" : "s")"
        case (let m, 0): return "\(m) minute\(m == 1 ? "" : "s")"
        default:         return "\(m) minute\(m == 1 ? "" : "s") and \(s) second\(s == 1 ? "" : "s")"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                VStack(spacing: 16) {
                    fireView(decibelLevel: decibelMonitor.decibels)
                        .frame(width: 140, height: 140)
                    Text(formatTime(timeElapsed))
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .accessibilityLabel(accessibleTime(timeElapsed))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Label("Sound Level", systemImage: "waveform")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    GeometryReader { geo in
                        let normalized = min(1, max(0, CGFloat((decibelMonitor.decibels + 60) / 60)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(.secondary.opacity(0.2))
                            Capsule()
                                .fill(
                                    normalized > 0.75 ? Color.red :
                                    normalized > 0.45 ? Color.orange : Color.green
                                )
                                .frame(width: geo.size.width * normalized)
                        }
                    }
                    .frame(height: 10)
                    .accessibilityHidden(true)

                    Text(decibelMonitor.isRunning
                         ? String(format: "%.0f dB", decibelMonitor.decibels)
                         : "Microphone off")
                        .font(.subheadline)
                        .foregroundStyle(decibelMonitor.isRunning ? .green : .red)
                        .monospacedDigit()
                        .animation(.easeInOut(duration: 0.2), value: decibelMonitor.isRunning)
                        .accessibilityLabel(
                            decibelMonitor.isRunning
                                ? "Sound level: \(String(format: "%.0f", decibelMonitor.decibels)) decibels"
                                : "Microphone is off"
                        )
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Conversation Starter", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        if promptCount > 0 {
                            Text("#\(promptCount)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isGenerating {
                        HStack(spacing: 10) {
                            ProgressView()
                                .accessibilityHidden(true)
                            Text("Crafting your prompt\u{2026}")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Generating your conversation starter, please wait")
                        }
                        .padding(.vertical, 4)
                    } else if generatedPrompt.isEmpty {
                        Text("A conversation starter will appear after 10 seconds of silence.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        Text(generatedPrompt)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 4)
                            .accessibilityAddTraits(.updatesFrequently)

                        if cooldownRemaining > 0 {
                            let mins = Int(cooldownRemaining / 60)
                            let secs = Int(cooldownRemaining) % 60
                            Label(
                                mins > 0
                                    ? "Next prompt in \(mins)m \(secs)s"
                                    : "Next prompt in \(secs)s",
                                systemImage: "clock"
                            )
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        } else if promptCount > 0 {
                            Label("Ready for next prompt", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Motion Guard", systemImage: "figure.walk.motion")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    Text("Vibrates and alerts when the device is moved. Toggle via the toolbar button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Text(detector.isRunning ? "On" : "Off")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(detector.isRunning ? Color.green : Color.red)
                            .animation(.easeInOut(duration: 0.2), value: detector.isRunning)
                            .accessibilityLabel("Motion guard is \(detector.isRunning ? "on" : "off")")

                        if detector.isRunning {
                            GeometryReader { geo in
                                let norm = min(1, max(0, CGFloat((detector.magnitude - 1) / 1.5)))
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.secondary.opacity(0.15))
                                    Capsule()
                                        .fill(norm > 0.6 ? Color.red : Color.orange)
                                        .frame(width: geo.size.width * norm)
                                }
                            }
                            .frame(height: 8)
                            .transition(.opacity)
                            .accessibilityHidden(true)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: detector.isRunning)

                    if detector.detectCount > 0 {
                        HStack(spacing: 12) {
                            Label("\(detector.detectCount) event\(detector.detectCount == 1 ? "" : "s")",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)

                            if let last = detector.lastDetectedAt {
                                Text(last, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Clear") { detector.detectCount = 0; detector.lastDetectedAt = nil }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Clear motion detection history")
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: detector.detectCount)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Companion")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    detector.isRunning ? detector.stop() : detector.start()
                } label: {
                    Image(systemName: detector.isRunning
                          ? "figure.walk.motion.trianglebadge.exclamationmark"
                          : "figure.walk.motion.trianglebadge.exclamationmark")
                }
                .tint(detector.isRunning ? .green : .secondary)
                .accessibilityLabel(detector.isRunning ? "Stop motion guard" : "Start motion guard")
                .accessibilityHint(detector.isRunning
                    ? "Disables movement detection and haptic alerts"
                    : "Enables movement detection; the device will vibrate when moved")
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    decibelMonitor.isRunning ? decibelMonitor.stop() : decibelMonitor.start()
                } label: {
                    Image(systemName: decibelMonitor.isRunning ? "mic.fill" : "mic.slash.fill")
                }
                .tint(decibelMonitor.isRunning ? .primary : .secondary)
                .accessibilityLabel(decibelMonitor.isRunning ? "Stop microphone" : "Start microphone")
                .accessibilityHint(decibelMonitor.isRunning
                    ? "Disables the sound level monitor and pauses conversation prompts"
                    : "Enables the sound level monitor and conversation starters")
            }
        }
        .onReceive(timer) { _ in timeElapsed += 1 }
        .onReceive(detector.$alarmTriggered) { triggered in
            guard triggered else { return }
            showingAlert = true
        }
        .onReceive(decibelMonitor.$silenceDetected) { detected in
            guard detected, canGeneratePrompt else { return }
            Task {
                isGenerating = true
                generatedPrompt = await generateWritingPrompt(promptText: buildPromptText())
                promptCount += 1
                lastPromptAt = Date()
                isGenerating = false
            }
        }
        .alert("Motion detected!", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text("Device movement exceeded the threshold. Total events this session: \(detector.detectCount).")
        }
        .onDisappear {
            detector.stop()
            decibelMonitor.stop()
        }
    }
}
