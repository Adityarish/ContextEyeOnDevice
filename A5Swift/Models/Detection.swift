import CoreGraphics
import Foundation

struct Detection: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
    var distance: Float? // Distance in meters (optional)

    var confidenceText: String {
        String(format: "%.0f%%", confidence * 100)
    }

    var distanceCategoryText: String? {
        guard let normalizedDisparity = distance else { return nil }
        // normalizedDisparity is 1.0 for the closest object, 0.0 for the furthest background
        if normalizedDisparity > 0.65 { return "Close" }
        if normalizedDisparity > 0.35 { return "Approaching" }
        return "Far"
    }

    var emoji: String {
        let lower = label.lowercased()
        switch lower {
        case "person": return "🧍"
        case "bicycle": return "🚲"
        case "car": return "🚗"
        case "motorcycle": return "🏍️"
        case "airplane": return "✈️"
        case "bus": return "🚌"
        case "train": return "🚆"
        case "truck": return "🚚"
        case "boat": return "⛵"
        case "traffic light": return "🚥"
        case "fire hydrant": return "🧯"
        case "stop sign": return "🛑"
        case "bench": return "🪑"
        case "bird": return "🐦"
        case "cat": return "🐱"
        case "dog": return "🐶"
        case "horse": return "🐴"
        case "sheep": return "🐑"
        case "cow": return "🐄"
        case "elephant": return "🐘"
        case "bear": return "🐻"
        case "zebra": return "🦓"
        case "giraffe": return "🦒"
        case "backpack": return "🎒"
        case "umbrella": return "☔"
        case "handbag": return "👜"
        case "tie": return "👔"
        case "suitcase": return "🧳"
        case "frisbee": return "🥏"
        case "skis": return "🎿"
        case "snowboard": return "🏂"
        case "sports ball": return "⚽"
        case "kite": return "🪁"
        case "baseball bat": return "🏏"
        case "baseball glove": return "🧤"
        case "skateboard": return "🛹"
        case "surfboard": return "🏄"
        case "tennis racket": return "🎾"
        case "bottle": return "🍾"
        case "wine glass": return "🍷"
        case "cup": return "☕"
        case "fork": return "🍴"
        case "knife": return "🔪"
        case "spoon": return "🥄"
        case "bowl": return "🥣"
        case "banana": return "🍌"
        case "apple": return "🍎"
        case "sandwich": return "🥪"
        case "orange": return "🍊"
        case "broccoli": return "🥦"
        case "carrot": return "🥕"
        case "hot dog": return "🌭"
        case "pizza": return "🍕"
        case "donut": return "🍩"
        case "cake": return "🎂"
        case "chair": return "🪑"
        case "couch": return "🛋️"
        case "potted plant": return "🪴"
        case "bed": return "🛏️"
        case "dining table": return "🍽️"
        case "toilet": return "🚽"
        case "tv": return "📺"
        case "laptop": return "💻"
        case "mouse": return "🖱️"
        case "remote": return "🎛️"
        case "keyboard": return "⌨️"
        case "cell phone": return "📱"
        case "microwave": return "🎛️"
        case "oven": return "🍳"
        case "toaster": return "🍞"
        case "sink": return "🚰"
        case "refrigerator": return "🧊"
        case "book": return "📚"
        case "clock": return "⏱️"
        case "vase": return "🏺"
        case "scissors": return "✂️"
        case "teddy bear": return "🧸"
        case "hair drier": return "💨"
        case "toothbrush": return "🪥"
        default: return "📦"
        }
    }
}
