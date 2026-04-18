import CoreML
import CoreVideo
import Foundation
import Vision
import Accelerate

final class DepthEstimationService {
    private let storageService: ModelStorageService
    private let processingQueue = DispatchQueue(label: "DepthEstimationService.processing")

    private var visionModel: VNCoreMLModel?
    private var isProcessingFrame = false

    // Cache the last depth map for bounding box lookups
    private var lastDepthBuffer: CVPixelBuffer?
    private let depthCacheFrames = 5
    private var frameCounter = 0

    init(storageService: ModelStorageService) {
        self.storageService = storageService
        
        // Load the model asynchronously when the service is created
        Task {
            do {
                let coreMLModel = try storageService.loadModel(named: "depth_anything_v2_small")
                self.visionModel = try VNCoreMLModel(for: coreMLModel)
                print("[Depth] Successfully loaded DepthAnythingV2 Small")
            } catch {
                print("[Depth] Failed to load depth model: \(error)")
            }
        }
    }

    /// Process a new camera frame to update the depth map cache.
    /// Runs inference every `depthCacheFrames` frames to save CPU/GPU.
    func processFrame(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        guard let visionModel = visionModel else { return }

        frameCounter += 1
        if frameCounter % depthCacheFrames != 1 {
            return // Skip inference, continue using the cached depth buffer
        }

        guard !isProcessingFrame else { return }
        isProcessingFrame = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }

            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error = error {
                    print("[Depth] Inference error: \(error)")
                    return
                }

                if let results = request.results as? [VNPixelBufferObservation], let depthBuffer = results.first?.pixelBuffer {
                    // Cache the depth buffer
                    self.lastDepthBuffer = depthBuffer
                }
            }

            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: orientation,
                options: [:]
            )

            do {
                try handler.perform([request])
            } catch {
                print("[Depth] Request perform error: \(error)")
            }
        }
    }

    /// Estimate the distance for a Vision-normalized bounding box [0, 1].
    /// Uses the bottom 30% of the bounding box and calculates the 10th percentile depth.
    func estimateDistance(for normalizedBBox: CGRect) -> Float? {
        guard let depthBuffer = lastDepthBuffer else { return nil }

        // The depth buffer is usually Float16 or Float32.
        // Let's read the pixels.
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(depthBuffer)
        let height = CVPixelBufferGetHeight(depthBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthBuffer) else { return nil }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(depthBuffer)

        // Vision's normalizedRect origin is bottom-left. We must flip Y to match the top-left origin of CVPixelBuffer.
        let x = normalizedBBox.minX * CGFloat(width)
        let y = (1.0 - normalizedBBox.maxY) * CGFloat(height)
        let w = normalizedBBox.width * CGFloat(width)
        let h = normalizedBBox.height * CGFloat(height)

        let x1 = max(0, Int(x))
        let y1 = max(0, Int(y))
        let x2 = min(width - 1, Int(x + w))
        let y2 = min(height - 1, Int(y + h))

        if x1 >= x2 || y1 >= y2 {
            return 10.0 // Default fallback
        }

        // We only care about the bottom 30% of the bounding box (where it touches the ground)
        let hBox = y2 - y1
        let yGroundStart = y2 - max(1, Int(Float(hBox) * 0.30))
        let startY = max(y1, yGroundStart)

        // Read the entire buffer to find global min/max for relative normalization
        let totalPixels = width * height
        var globalMin: Float = 0
        var globalMax: Float = 0
        var roiPixels: [Float] = []

        if pixelFormat == kCVPixelFormatType_DepthFloat16 || pixelFormat == kCVPixelFormatType_OneComponent16Half {
            // Read Float16
            let float16Pointer = baseAddress.bindMemory(to: UInt16.self, capacity: height * bytesPerRow / 2)
            
            // Extract ROI
            for row in startY...y2 {
                let rowStart = (row * bytesPerRow) / 2
                for col in x1...x2 {
                    roiPixels.append(float16to32(float16Pointer[rowStart + col]))
                }
            }
            // Estimate global min/max by subsampling to save CPU
            var minVal: Float = 999999
            var maxVal: Float = -999999
            for i in stride(from: 0, to: totalPixels, by: 16) {
                let val = float16to32(float16Pointer[i])
                if val < minVal { minVal = val }
                if val > maxVal { maxVal = val }
            }
            globalMin = minVal
            globalMax = maxVal
            
        } else if pixelFormat == kCVPixelFormatType_DepthFloat32 || pixelFormat == kCVPixelFormatType_OneComponent32Float {
            // Read Float32
            let float32Pointer = baseAddress.bindMemory(to: Float.self, capacity: height * bytesPerRow / 4)
            
            // Extract ROI
            for row in startY...y2 {
                let rowStart = (row * bytesPerRow) / 4
                for col in x1...x2 {
                    roiPixels.append(float32Pointer[rowStart + col])
                }
            }
            // Use Accelerate for instant global min/max over the entire F32 buffer
            vDSP_minv(float32Pointer, 1, &globalMin, vDSP_Length(totalPixels))
            vDSP_maxv(float32Pointer, 1, &globalMax, vDSP_Length(totalPixels))
            
        } else {
            return 0.0 // Default fallback
        }

        if roiPixels.isEmpty {
            return 0.0
        }

        // Depth Anything V2 outputs RELATIVE INVERSE DEPTH (disparity). Larger = closer.
        roiPixels.sort()
        let percentileIndex = Int(Float(roiPixels.count) * 0.90) // 90th percentile to get closest surface
        let rawDisparity = roiPixels[percentileIndex]

        // Normalize the disparity to [0.0, 1.0] based on the current scene
        let range = max(0.0001, globalMax - globalMin)
        let normalizedDisparity = (rawDisparity - globalMin) / range
        
        // Return normalized disparity directly to Detection struct
        // 1.0 = Closest thing in the room | 0.0 = Furthest background
        return min(1.0, max(0.0, normalizedDisparity))
    }

    /// Converts Float16 (UInt16) to Float32 using Accelerate vImage
    private func float16to32(_ f16: UInt16) -> Float {
        var f16In = f16
        var f32Out: Float = 0.0
        var sourceBuffer = vImage_Buffer(data: &f16In, height: 1, width: 1, rowBytes: 2)
        var destBuffer = vImage_Buffer(data: &f32Out, height: 1, width: 1, rowBytes: 4)
        vImageConvert_Planar16FtoPlanarF(&sourceBuffer, &destBuffer, 0)
        return f32Out
    }
}
