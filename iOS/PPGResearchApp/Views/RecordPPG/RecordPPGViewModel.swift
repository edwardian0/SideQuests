//
//  RecordPPGViewModel.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 25/02/2025.
//

import SwiftUI
import Foundation
import SwiftData
import AVFoundation

struct PresetList: Codable {
    let presets: [CameraPreset]
}

struct CameraPreset: Codable {
    let id: Int
    let ISO: Int
    let ExposureSeconds: Double
    let WhiteBalance: Int
    let Focus: Double
}

@Observable
class RecordPPGViewModel {
    
    let camera = Camera()
    var viewfinderImage: Image?
    var livePreviewData = PPGPreviewData()
    var recordedData = [String : [DataPoint]]()
    var isRecording = false
//    var recording: PPGRecording?
    var recordings = [PPGRecording]()

    // An array to store pre-loaded presets
    var availablePresets: [CameraPreset] = []
    
    private var preProcessingList = [(name: String, function: (CVPixelBuffer) -> DataPoint?)]()
    
    
    private var recordingStartedTimestamp: Date?
    private var lastFrameTimestamp = Date()
    
    private var selectedSamplingMethod = SamplingMethod.spread
    
    var torchOn: Bool = false {
        didSet {
            if torchOn {
                camera.setTorch(torchLevel: 1.0)
            }else{
                camera.setTorch(torchLevel: 0.0)
            }
            
        }
    }
    
    var recordingTime: String {
        let defaultValue = "00:00:00"
        guard isRecording else { return defaultValue }
        guard let recordingStartedTimestamp else { return defaultValue }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.hour,.minute,.second],
            from: recordingStartedTimestamp,
            to: Date()
        )
        
        if let hours = components.hour,
           let minutes = components.minute,
           let seconds = components.second {
            return "\(String(format:"%02d", hours)):\(String(format:"%02d", minutes)):\(String(format:"%02d", seconds))"
        }
        
        return defaultValue
    }
    
    init() {
        preparePreProcesingList()
        availablePresets = loadAllPresets()
        Task {
            await handleCameraStream()
        }
    }
    
//    func applyPreset(preset: CameraPreset){
//        if !camera.applyPreset(preset: preset) {
//            //handle error
//        }
//    }
//
    func startRecording(){
        recordings.removeAll()
        recordedData.removeAll()
        for preprocessor in preProcessingList {
            recordedData[preprocessor.name] = [DataPoint]()
        }
        isRecording = true
        recordingStartedTimestamp = Date()
    }
    
    func stopRecording(){
        isRecording = false
        camera.stop()
        torchOn = false
        
        for key in recordedData.keys {
            if let data = recordedData[key]{
                let newRecording = PPGRecording(
                    timestamp: Date(),
                    duration: Date()
                        .timeIntervalSince(recordingStartedTimestamp!),
                    lightIntensity:  0.0,
                    subjectID: key,
                    data: data,
                    notes: [],
                    events: []
                )
                recordings.append(newRecording)
            }
        }
        
        recordedData.removeAll()
    }
    
    // Added threshold, grid, and random ROI selector methods
    private func preparePreProcesingList(){
        self.preProcessingList.removeAll()
        
        self.preProcessingList = [(name: "corner", function: cornerPixelsAverage(buffer:)),
                                  (name: "spread", function: spreadedPixelsAverage(buffer:)),
                                  (name: "threshold", function: thresholdedPixelsAverage(buffer:)),
                                  (name: "grid", function: gridPixelsAverage(buffer:)),
                                  (name: "random", function: randomPixelsAverage(buffer:))]
    }
    
    func prepareExportZip() -> URL?{
        let files = recordings.map { ($0.csvFileName(), $0.exportFile()) }
        let zipFileName = "\(Date().toWebServiceFormat()).zip"
        let zipUrl = FileManager.default.temporaryDirectory.appendingPathComponent(zipFileName)
        do {
            try Archiver.createZip(with: files, zipFileURL: zipUrl)
            return zipUrl
        }
        catch {
            return nil
        }
    }
    
    private func handleCameraStream() async {
        let rawPixels = camera.rawPreviewStream
        
        for await pixelBuffer in rawPixels {
            if let dataPoint = try? getDataPointFromBuffer(
                pixelBuffer: pixelBuffer) {
                addToHistory(dataPoint: dataPoint)
            }
            
            if isRecording {
                for preprcessor in preProcessingList {
                    if let data = preprcessor.function(pixelBuffer) {
                        recordedData[preprcessor.name]?.append(data)
                    }
                }
            }
            
            await MainActor.run {
                showPreview(pixelBuffer)
            }
            
        }
    }
    
    @MainActor
    private func showPreview(_ pixelBuffer: CVPixelBuffer){
        if (Date().timeIntervalSince(lastFrameTimestamp) > 0.06){
            let image = CIImage(cvPixelBuffer: pixelBuffer).image
            viewfinderImage = image
            lastFrameTimestamp = Date()
        }
    }
    
    private func dataFromBuffer(_ pixelBuffer: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil}
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let totalSize = bytesPerRow * height
        let rawData = Data(bytes: baseAddress, count: totalSize)
        
        return rawData
    }
    
    private func addToHistory(dataPoint: DataPoint) {
        livePreviewData.addDataPoint(dataPoint)
    }
}

extension RecordPPGViewModel {
    func selectCameraResolution(resolution: CameraResolution){
        camera.stop()
        camera.resetConfig()
        
        switch resolution {
        case .vga:
            camera.selectedResolution = .vga640x480
        case .hd720:
            camera.selectedResolution = .hd1280x720
        case .hd1080:
            camera.selectedResolution = .hd1920x1080
        }
        
        
        Task {
            await camera.start()
        }
    }
    
    enum CameraResolution{
        case vga
        case hd720
        case hd1080
    }
}

//Image bufer processing
extension RecordPPGViewModel {
    
    func cornerPixelsAverage(buffer: CVPixelBuffer) -> DataPoint?{
        guard let pixels = try? getPixels(pixelBuffer: buffer, coordinates: prepareSamplingCoordinatesCorner(pixelBuffer: buffer)) else { return nil }
        
        let output = pixelsToDataPointAverage(pixels: pixels)
        return output
    }
    
    func spreadedPixelsAverage(buffer: CVPixelBuffer) -> DataPoint?{
        guard let pixels = try? getPixels(pixelBuffer: buffer, coordinates: prepareSamplingCoordinatesSpreaded(pixelBuffer: buffer)) else { return nil }
        
        let output = pixelsToDataPointAverage(pixels: pixels)
        return output
    }
    
    func thresholdedPixelsAverage(buffer: CVPixelBuffer) -> DataPoint? {
        guard let pixels = try? getPixels(pixelBuffer: buffer, coordinates: prepareSamplingCoordinatesThreshold(pixelBuffer: buffer)) else {return nil}
        
        let output = pixelsToDataPointAverage(pixels: pixels)
        return output
    }
    
    func gridPixelsAverage(buffer: CVPixelBuffer) -> DataPoint? {
        guard let pixels = try? getPixels(pixelBuffer: buffer, coordinates: prepareSamplingCoordinatesGrid(pixelBuffer: buffer)) else {return nil}
        
        let output = pixelsToDataPointAverage(pixels: pixels)
        return output
    }
    
    func randomPixelsAverage(buffer: CVPixelBuffer) -> DataPoint? {
        guard let pixels = try? getPixels(pixelBuffer: buffer, coordinates: prepareSamplingCoordinatesRandom(pixelBuffer: buffer)) else {return nil}
        
        let output = pixelsToDataPointAverage(pixels: pixels)
        return output
    }
    
    
    private func getPixels(pixelBuffer: CVPixelBuffer, coordinates: [(x: Int, y: Int)]) throws -> (r: [Double], g: [Double], b: [Double], w: [Double]) {
        
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else{
            throw PPGReadError.incorrectPixelType
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        var whiteArray = [Double]()
        var redArray = [Double]()
        var greenArray = [Double]()
        var blueArray = [Double]()
        
        coordinates.forEach { x, y in
            let index = x*4 + y*bytesPerRow
            let b = buffer[index]
            let g = buffer[index+1]
            let r = buffer[index+2]
            
            let w = Double(Int(r) + Int(g) + Int(b)) / 3.0
            whiteArray.append(w)
            redArray.append(Double(r))
            greenArray.append(Double(g))
            blueArray.append(Double(b))
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        let result = (r: redArray, g: greenArray, b: blueArray, w: whiteArray)
        
        return result
    }

    private func pixelsToDataPointAverage(pixels: (r: [Double], g: [Double], b: [Double], w: [Double])) -> DataPoint {
        
        let avgBrightness = (pixels.w.reduce(0, +) / Double(pixels.w.count)) / 255.0
        let avgR = (pixels.r.reduce(0, +) / Double(pixels.r.count)) / 255.0
        let avgG = (pixels.g.reduce(0, +) / Double(pixels.g.count)) / 255.0
        let avgB = (pixels.b.reduce(0, +) / Double(pixels.b.count)) / 255.0
        
        //invert values
        let dataPoint = DataPoint(
            time: Date(),
            brightness: 1 - avgBrightness,
            red: 1 - avgR,
            green: 1 - avgG,
            blue: 1 - avgB
        )
        
        return dataPoint
    }
    
    private func getDataPointFromBuffer(pixelBuffer: CVPixelBuffer) throws -> DataPoint {
        
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else{
            throw PPGReadError.incorrectPixelType
        }
        
        var coordinates: [(Int, Int)] = []
        
        switch selectedSamplingMethod {
            case .corner:
                coordinates = prepareSamplingCoordinatesCorner(pixelBuffer: pixelBuffer)
            case .spread:
                coordinates = prepareSamplingCoordinatesSpreaded(pixelBuffer: pixelBuffer)
            case .threshold:
                coordinates = prepareSamplingCoordinatesThreshold(pixelBuffer: pixelBuffer)
            case .grid:
                coordinates = prepareSamplingCoordinatesGrid(pixelBuffer: pixelBuffer)
            case .random:
                coordinates = prepareSamplingCoordinatesRandom(pixelBuffer: pixelBuffer)
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        var brightnessArray = [Double]()
        var redArray = [Double]()
        var greenArray = [Double]()
        var blueArray = [Double]()
        
        coordinates.forEach { x, y in
            let index = x*4 + y*bytesPerRow
            let b = buffer[index]
            let g = buffer[index+1]
            let r = buffer[index+2]
            
            let brightness = Double(Int(r) + Int(g) + Int(b)) / 3.0
            brightnessArray.append(brightness)
            redArray.append(Double(r))
            greenArray.append(Double(g))
            blueArray.append(Double(b))
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        let avgBrightness = (brightnessArray.reduce(0, +) / Double(brightnessArray.count)) / 255.0
        let avgR = (redArray.reduce(0, +) / Double(redArray.count)) / 255.0
        let avgG = (greenArray.reduce(0, +) / Double(greenArray.count)) / 255.0
        let avgB = (blueArray.reduce(0, +) / Double(blueArray.count)) / 255.0
        
        //invert values
        let dataPoint = DataPoint(
            time: Date(),
            brightness: 1 - avgBrightness,
            red: 1 - avgR,
            green: 1 - avgG,
            blue: 1 - avgB
        )
        
        return dataPoint
    }
    
    private func prepareSamplingCoordinatesCorner(pixelBuffer: CVPixelBuffer) -> [(x: Int, y: Int)] {
        var coordinates = [(x: Int, y: Int)]()
            
        let startX = 100
        let startY = 100
        let sizeX = 10
        let sizeY = 10
        
        for x in startX..<startX + sizeX {
            for y in startY..<startY + sizeY {
                coordinates.append((x, y))
            }
        }
        
        return coordinates
    }
    
    private func prepareSamplingCoordinatesSpreaded(pixelBuffer: CVPixelBuffer) -> [(x: Int, y: Int)] {
        let bufferSizeX = CVPixelBufferGetWidth(pixelBuffer)
        let bufferSizeY = CVPixelBufferGetHeight(pixelBuffer)
        let coordinates = [
            (10, 10),
            (10, 11),
            (11, 11),
            (11, 10),
            
            (bufferSizeX - 11, 10),
            (bufferSizeX - 11, 11),
            (bufferSizeX - 10, 11),
            (bufferSizeX - 10, 10),
            
            (10, bufferSizeY - 10),
            (10, bufferSizeY - 11),
            (11, bufferSizeY - 11),
            (11, bufferSizeY - 10),
            
            (bufferSizeX - 10, bufferSizeY - 10),
            (bufferSizeX - 10, bufferSizeY - 11),
            (bufferSizeX - 11, bufferSizeY - 11),
            (bufferSizeX - 11, bufferSizeY - 10),
            
            ((bufferSizeX / 2), (bufferSizeY / 2)),
            ((bufferSizeX / 2), (bufferSizeY / 2) + 1),
            ((bufferSizeX / 2) + 1, (bufferSizeY / 2) + 1),
            ((bufferSizeX / 2) + 1, (bufferSizeY / 2)),
        ]
        return coordinates
    }
    
    private func prepareSamplingCoordinatesThreshold(pixelBuffer: CVPixelBuffer) -> [(x: Int, y: Int)] {
            guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
                    return []
                }
                
                CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
                
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
                
                // Use histogram to obtain threshold to improve performance.
                // Build histogram of brightness values [0...255]
                var histogram = [[Int]]()   /*(repeating: 0, count: 256)*/
            for y in stride(from: 0, to: height, by: 50) {/*0..<height {*/
                for x in stride(from: 0, to: width, by: 50) {/*0..<width {*/
                        let index = x * 4 + y * bytesPerRow
                        let b = baseAddress[index]
                        let g = baseAddress[index + 1]
                        let r = baseAddress[index + 2]
                        
                        let brightness = (Int(r) + Int(g) + Int(b)) / 3
    //                    histogram[brightness] += 1
                    histogram.append([brightness, x, y])
                    }
                }

            let histogramSorted = histogram.sorted { $0[0] < $1[0] }
            let k = Int(Double(histogramSorted.count)*0.05)
            let top5 = histogramSorted.prefix(k)
            let coordinates = top5.map{ ($0[1], $0[2]) }
                return coordinates
        }
        
        
        //        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
//                return []
//            }
//
//            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
//
//            let width = CVPixelBufferGetWidth(pixelBuffer)
//            let height = CVPixelBufferGetHeight(pixelBuffer)
//            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
//
//            // Use histogram to obtain threshold to improve performance.
//            // Build histogram of brightness values [0...255]
//            var histogram = [Int](repeating: 0, count: 256)
//        for y in stride(from: 0, to: height, by: 10) {/*0..<height {*/
//            for x in stride(from: 0, to: width, by: 10) {/*0..<width {*/
//                    let index = x * 4 + y * bytesPerRow
//                    let b = baseAddress[index]
//                    let g = baseAddress[index + 1]
//                    let r = baseAddress[index + 2]
//
//                    let brightness = (Int(r) + Int(g) + Int(b)) / 3
//                    histogram[brightness] += 1
//                }
//            }
//
//            // Find 95th percentile threshold
//            let totalPixels = width * height
//            let cutoff = Int(Double(totalPixels) * 0.95)
//            var cumulative = 0
//            var threshold = 255
//            for i in 0..<256 {
//                cumulative += histogram[i]
//                if cumulative >= cutoff {
//                    threshold = i
//                    break
//                }
//            }
//
//            // 3. Collect coordinates above threshold
//            var coordinates = [(x: Int, y: Int)]()
//            for y in 0..<height {
//                for x in 0..<width {
//                    let index = x * 4 + y * bytesPerRow
//                    let b = baseAddress[index]
//                    let g = baseAddress[index + 1]
//                    let r = baseAddress[index + 2]
//                    let brightness = (Int(r) + Int(g) + Int(b)) / 3
//                    if brightness >= threshold {
//                        coordinates.append((x, y))
//                    }
//                }
//            }
//
//            return coordinates
    }
    
    private func prepareSamplingCoordinatesGrid(pixelBuffer: CVPixelBuffer) -> [(x: Int, y: Int)] {
        let bufferSizeX = CVPixelBufferGetWidth(pixelBuffer)
        let bufferSizeY = CVPixelBufferGetHeight(pixelBuffer)
        
        let margin = 10        // distance from edge
            let patchRadius = 2    // 2 → 5x5 patch, 3 → 7x7 patch, etc.
            
            // Define 9 center points
            let centers = [
                (margin, margin),                         // Top-left
                (bufferSizeX / 2, margin),                // Top edge center
                (bufferSizeX - margin, margin),           // Top-right
                
                (margin, bufferSizeY / 2),                // Left edge center
                (bufferSizeX / 2, bufferSizeY / 2),       // Center
                (bufferSizeX - margin, bufferSizeY / 2),  // Right edge center
                
                (margin, bufferSizeY - margin),           // Bottom-left
                (bufferSizeX / 2, bufferSizeY - margin),  // Bottom edge center
                (bufferSizeX - margin, bufferSizeY - margin) // Bottom-right
            ]
            
            var coordinates = [(x: Int, y: Int)]()
            
            for (cx, cy) in centers {
                for dx in -patchRadius...patchRadius {
                    for dy in -patchRadius...patchRadius {
                        let x = cx + dx
                        let y = cy + dy
                        // Safety check (avoid out-of-bounds)
                        if x >= 0 && x < bufferSizeX && y >= 0 && y < bufferSizeY {
                            coordinates.append((x, y))
                        }
                    }
                }
            }
            
            return coordinates
    }
    
    private func prepareSamplingCoordinatesRandom(pixelBuffer: CVPixelBuffer) -> [(x: Int, y: Int)] {
        let bufferSizeX = CVPixelBufferGetWidth(pixelBuffer)
        let bufferSizeY = CVPixelBufferGetHeight(pixelBuffer)
        
        var coordinates = [(x: Int, y: Int)]()
        let count = 100
        let patchRadius = 2
        
        for _ in 0..<count {
            let cx = Int.random(in: 0..<bufferSizeX)
            let cy = Int.random(in: 0..<bufferSizeY)
            
            for dx in -patchRadius...patchRadius {
                for dy in -patchRadius...patchRadius {
                    let x = cx + dx
                    let y = cy + dy
                    if x >= 0 && x < bufferSizeX && y >= 0 && y < bufferSizeY {
                        coordinates.append((x, y))
                    }
                }
            }
        }
        
        return coordinates
    }


    
    enum SamplingMethod{
        case corner
        case spread
        case threshold
        case grid
        case random
    }
    
    enum PPGReadError: Error{
        case incorrectPixelType
    }


// Camera Configurations extension
extension RecordPPGViewModel {
    func applyPreset(_ preset: CameraPreset) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera detected")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Baseline preset:
            if preset.id == 1 {
                
                // Focus
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }

                // Exposure
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }

                // White Balance
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                
                device.unlockForConfiguration()
                print("Successfully applied baseline preset (auto modes)")
                return

            }
            
            
            // Focus
            let lensPosition = Float(preset.Focus)
            let clampedLensPosition: Float = max(0.0, min(lensPosition, 1.0))
            
            if device.isFocusModeSupported(.locked) {
                device.setFocusModeLocked(lensPosition: clampedLensPosition) { _ in
                    print("Focus locked at position \(clampedLensPosition)")
                }
            } else {
                print("Locked focus mode not supported")
            }
            
            // ISO + Exposure (must be set together)
            let clampedISO = max(device.activeFormat.minISO,
                                 min(Float(preset.ISO), device.activeFormat.maxISO))
            
            let exposureDuration = CMTimeMakeWithSeconds(
                preset.ExposureSeconds,
                preferredTimescale: 1000
            )
            
            // Clamp exposure duration to device limits
            let clampedExposureDuration = CMTimeClampToRange(
                exposureDuration,
                range: CMTimeRangeMake(
                    start: device.activeFormat.minExposureDuration,
                    duration: CMTimeSubtract(device.activeFormat.maxExposureDuration, device.activeFormat.minExposureDuration)
                )
            )
            
            device.setExposureModeCustom(duration: clampedExposureDuration, iso: clampedISO) { _ in
                print("ISO set to \(clampedISO), Exposure set to \(CMTimeGetSeconds(clampedExposureDuration)) seconds")
            }
            
            // White Balance
            let wbTemperatureValue = Float(preset.WhiteBalance)
            let tint: Float = 0 // neutral tint
            
            let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: wbTemperatureValue,
                tint: tint
            )
            
            var gains = device.deviceWhiteBalanceGains(for: tempAndTint)
            
            // Clamp each gain: min is always 1.0, max comes from device
            gains.redGain   = max(1.0, min(gains.redGain, device.maxWhiteBalanceGain))
            gains.greenGain = max(1.0, min(gains.greenGain, device.maxWhiteBalanceGain))
            gains.blueGain  = max(1.0, min(gains.blueGain, device.maxWhiteBalanceGain))
            
            if device.isWhiteBalanceModeSupported(.locked) {
                device.setWhiteBalanceModeLocked(with: gains) { (_: CMTime) in
                    print("White Balance locked at \(wbTemperatureValue)K")
                }
            } else {
                print("Locked white balance mode not supported")
            }
            
            device.unlockForConfiguration()
            print("Successfully applied preset \(preset.id)")
            
        } catch {
            print("Error configuring camera: \(error)")
        }
    }

    func loadAllPresets() -> [CameraPreset] {
        guard let url = Bundle.main.url(forResource: "camera-presets", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load presets file.")
            return []
        }
        
        do {
            let presetList = try JSONDecoder().decode(PresetList.self, from: data)
            return presetList.presets
        } catch {
            print("Failed to decode presets: \(error)")
            return []
        }
    }
    
}

// Read presets extension from JSON file
extension Bundle {
    func decode<T: Decodable>(file: String) -> T{
        guard let url = self.url(forResource: file, withExtension: nil) else {
            fatalError("Could not locate file in project.")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load in \(file).")
        }
        let decoder = JSONDecoder()
        
        guard let loadedPreset = try? decoder.decode(T.self, from: data) else {
            fatalError("Could not decode \(file)")
        }
        
        return loadedPreset
    }
}


