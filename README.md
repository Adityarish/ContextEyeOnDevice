# A5Swift

`A5Swift` is a SwiftUI iOS app that downloads YOLO-style Core ML models, stores them on-device, compiles them into `.mlmodelc`, and runs real-time object detection fully offline with `Vision` and `AVFoundation`.

## Project Structure

```
A5Swift/
  Models/
  ViewModels/
  Views/
  Services/
  Utilities/
  Resources/
```

## How It Works

1. `ModelRegistryService` fetches a remote JSON registry and falls back to the bundled `model_registry.json`.
2. `ModelDownloadService` downloads the selected `.mlmodel` using `URLSession`.
3. `ModelStorageService` saves the raw model in the app's Documents directory, compiles it with `MLModel.compileModel(at:)`, and stores the compiled `.mlmodelc` bundle for offline inference.
4. `CameraService` streams camera frames from `AVCaptureSession`.
5. `ObjectDetectionService` runs `VNCoreMLRequest` on the camera frames and maps `VNRecognizedObjectObservation` results into SwiftUI overlays.

## Run in Xcode

1. Open `/Users/adityasingh/development/projects/A5_swift/A5Swift.xcodeproj`.
2. Set your team and a unique bundle identifier in the Signing & Capabilities tab.
3. Replace the placeholder registry URL in [AppEnvironment.swift](/Users/adityasingh/development/projects/A5_swift/A5Swift/Services/AppEnvironment.swift) with your real server endpoint.
4. Update `/Users/adityasingh/development/projects/A5_swift/A5Swift/Resources/model_registry.json` or your remote registry with real `.mlmodel` URLs.
5. Run on a physical iPhone because the real-time camera flow requires device hardware for the best experience.

## Model Compatibility Note

The current inference layer expects a Vision-compatible Core ML object detector that returns `VNRecognizedObjectObservation`.

If your YOLO conversion exposes raw tensors instead, keep the download/storage flow as-is and extend [ObjectDetectionService.swift](/Users/adityasingh/development/projects/A5_swift/A5Swift/Services/ObjectDetectionService.swift) with custom tensor decoding for that model's output schema.
