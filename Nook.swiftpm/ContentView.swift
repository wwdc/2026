import SwiftUI

private struct NotionIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(color.opacity(0.18))
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(color.opacity(0.22), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let destination: String
    @Binding var path: NavigationPath

    var body: some View {
        Button {
            path.append(destination)
        } label: {
            HStack(spacing: 16) {
                NotionIcon(symbol: icon, color: iconColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens \(title)")
    }
}

private struct FeatureTile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let destination: String
    @Binding var path: NavigationPath

    var body: some View {
        Button {
            path.append(destination)
        } label: {
            VStack(spacing: 20) {
                NotionIcon(symbol: icon, color: iconColor, size: 72)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens \(title)")
    }
}

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var showAbout = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<21: return "Good evening."
        default:      return "Good night."
        }
    }

    private let features: [(icon: String, color: Color, title: String, subtitle: String, destination: String)] = [
        ("flame.fill", .orange, "Companion",  "Ambient campfire atmosphere with gentle conversation nudges for a phone-free meal.",  "CompanionView"),
        ("moon.stars.fill", .indigo, "Deep Focus", "Minimalist hourglass timer that makes staying off your phone feel intentional.", "DeepFocusView"),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if sizeClass == .regular {
                    VStack(spacing: 48) {
                        VStack(spacing: 4) {
                            Text(greeting)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("Nook")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 32)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 20),
                                      GridItem(.flexible(), spacing: 20)],
                            spacing: 20
                        ) {
                            ForEach(features, id: \.destination) { f in
                                FeatureTile(
                                    icon: f.icon, iconColor: f.color,
                                    title: f.title, subtitle: f.subtitle,
                                    destination: f.destination, path: $path
                                )
                            }
                        }
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 40)

                        AboutButton { showAbout = true }
                    }
                    .padding(.bottom, 48)

                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Nook")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        VStack(spacing: 12) {
                            ForEach(features, id: \.destination) { f in
                                FeatureCard(
                                    icon: f.icon, iconColor: f.color,
                                    title: f.title, subtitle: f.subtitle,
                                    destination: f.destination, path: $path
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        AboutButton { showAbout = true }
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { value in
                if value == "CompanionView" {
                    CompanionView(path: $path)
                } else if value == "DeepFocusView" {
                    DeepFocusView(path: $path)
                }
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
    }
}

private struct AboutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("About Nook", systemImage: "info.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("About Nook")
        .accessibilityHint("Opens project overview")
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let technologies: [(icon: String, color: Color, name: String, note: String)] = [
        ("paintbrush.fill",      .blue,   "SwiftUI",          "UI, Canvas animations, etc."),
        ("brain.head.profile",   .purple, "FoundationModels", "On-device Apple Intelligence conversation prompts"),
        ("gyroscope",            .orange, "CoreMotion",       "Accelerometer-based motion guard in Companion"),
        ("mic.fill",             .teal,   "AVFoundation",     "Microphone metering for silence detection"),
        ("waveform",             .gray,   "UIKit",            "Haptic feedback via UIImpactFeedbackGenerator & UINotificationFeedbackGenerator"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nook")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Put the phone down. Be present at the table.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Purpose", systemImage: "sparkles")
                            .font(.headline)
                        Text("Nook is an offline-first app that reduces phone distraction at the meal table. It turns your device into ambient scenery — a live campfire that reacts to the room's sound — and quietly works in the background to bring people back into conversation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Features", systemImage: "square.grid.2x2")
                            .font(.headline)
                        FeaturePill(
                            icon: "flame.fill", color: .orange,
                            title: "Companion",
                            description: "An animated campfire that reacts to ambient sound via the microphone. CoreMotion guards against picking the device up. After 10 seconds of silence, Apple Intelligence generates a warm, topic-specific conversation starter to bring everyone back to the table."
                        )
                        FeaturePill(
                            icon: "moon.stars.fill", color: .indigo,
                            title: "Deep Focus",
                            description: "A minimalist hourglass timer with fully custom Canvas geometry. Set a duration (1–120 min), tap to begin, and let the sand fall. A subtle haptic pulse marks each second so you feel time passing without looking at the screen."
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Technologies", systemImage: "cpu")
                            .font(.headline)
                        ForEach(technologies, id: \.name) { tech in
                            HStack(spacing: 12) {
                                Image(systemName: tech.icon)
                                    .font(.body.weight(.medium))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(tech.color)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tech.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(tech.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Accessibility", systemImage: "accessibility")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            AccessibilityRow(
                                icon: "mic",
                                text: "VoiceOver labels and hints on every interactive element; accessible time strings (e.g. \"2 minutes and 30 seconds remaining\")"
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

private struct AccessibilityRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .frame(width: 24)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
