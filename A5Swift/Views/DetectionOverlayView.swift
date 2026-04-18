import SwiftUI

// MARK: - Main overlay

struct DetectionOverlayView: View {
    let detections: [Detection]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                    let rect = BoundingBoxMapper.rect(
                        for: detection.boundingBox,
                        imageSize: imageSize,
                        in: proxy.size
                    )

                    TextOverlayView(detection: detection)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    /// Persons → vivid red; everything else cycles through a neon palette
    private func boxColor(for label: String) -> Color {
        let lower = label.lowercased()
        if lower == "person" { return Color(red: 0.93, green: 0.13, blue: 0.22) }

        let palette: [Color] = [
            Color(red: 0.93, green: 0.27, blue: 0.73),   // magenta / pink
            Color(red: 0.18, green: 0.85, blue: 0.78),   // cyan
            Color(red: 1.00, green: 0.60, blue: 0.00),   // amber
            Color(red: 0.30, green: 0.75, blue: 0.30),   // green
            Color(red: 0.40, green: 0.50, blue: 1.00),   // indigo
            Color(red: 1.00, green: 0.90, blue: 0.20),   // yellow
        ]
        // Stable colour per class name
        let hash = abs(label.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return palette[hash % palette.count]
    }
}

// MARK: - Floating Text Overlay

private struct TextOverlayView: View {
    let detection: Detection

    var body: some View {
        HStack(spacing: 4) {
            Text(detection.label.capitalized)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)

            if let distanceText = detection.distanceCategoryText {
                Text("•")
                    .font(.system(size: 9))
                    .foregroundStyle(.green.opacity(0.8))
                Text(distanceText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
