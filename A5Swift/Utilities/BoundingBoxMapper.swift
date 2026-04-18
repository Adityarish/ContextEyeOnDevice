import CoreGraphics

enum BoundingBoxMapper {
    /// Map a Vision-normalized bounding box to view coordinates.
    ///
    /// Vision's coordinate space:
    ///   - Origin (0, 0) = bottom-left of the image
    ///   - (1, 1)        = top-right of the image
    ///
    /// Since we use VNCoreMLRequest with `.scaleFill`, Vision scales the
    /// model's 640×640 predictions back to fill the *entire* input image,
    /// so the normalized rect already maps 1:1 to the view after a Y-flip.
    ///
    /// The `imageSize` parameter is kept for API compatibility but is no
    /// longer used in the mapping — using it caused the misalignment.
    static func rect(for normalizedRect: CGRect, imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }

        // Flip Y: Vision (0,0) = bottom-left → UIKit (0,0) = top-left
        let x = normalizedRect.minX * viewSize.width
        let y = (1.0 - normalizedRect.maxY) * viewSize.height
        let w = normalizedRect.width  * viewSize.width
        let h = normalizedRect.height * viewSize.height

        // Clamp to the visible view area
        let clampedW = min(w, viewSize.width)
        let clampedH = min(h, viewSize.height)
        let clampedX = min(max(0, x), viewSize.width  - clampedW)
        let clampedY = min(max(0, y), viewSize.height - clampedH)

        return CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
    }
}
