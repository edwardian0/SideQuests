@preconcurrency import AVFoundation
import CoreImage
import UIKit
import os.log

class Camera: NSObject {
    
    var selectedResolution = AVCaptureSession.Preset.vga640x480
    
    private let targetFPS = 100.0
    private var captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var sessionQueue: DispatchQueue!
    
    private var previousTorchMode = AVCaptureDevice.TorchMode.off
    private var previousTorchLevel = Float(1.0)
    
    // Added to keep track of the last used preset for instance where the captureDevice is switched
    private var currentPreset: CameraPreset?
    
    private var allCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice
            .DiscoverySession(
                deviceTypes: [
                    .builtInWideAngleCamera,
                    .builtInTelephotoCamera,
                    .builtInUltraWideCamera
                ],
                mediaType: .video,
                position: .back
            ).devices
    }
    
    private var availableCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter( { $0.isConnected } )
            .filter( { !$0.isSuspended } )
    }
    
    private var captureDevice: AVCaptureDevice? {
        willSet {
            if let device = captureDevice{
                previousTorchMode = device.torchMode
                previousTorchLevel = device.torchLevel
            }
        }
        didSet {
            guard let captureDevice = captureDevice else { return }
            logger.debug("Using capture device: \(captureDevice.localizedName)")
            sessionQueue.async { [unowned self] in
                self.setTorch(torchLevel: 0.0)
                self.captureSession.stopRunning()
                self.updateSessionForCaptureDevice(captureDevice)
                self.setFPS(fps: self.targetFPS)
                self.captureSession.startRunning()
                
                Thread.sleep(forTimeInterval: 0.1)
                self.setTorch(torchLevel: previousTorchMode == .on ? previousTorchLevel : 0)
                
                // Reapply the current preset to the new device
                if let preset = self.currentPreset {
                    self.applyPreset(preset: preset)
                }
            }
        }
    }
    
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    private var addToRawPreviewStream: ((CVPixelBuffer) -> Void)?
    
    var isPreviewPaused = false
    
    lazy var rawPreviewStream: AsyncStream<CVPixelBuffer> = {
        AsyncStream { continuation in
            addToRawPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()
    
    override init() {
        super.init()
        initialize()
    }
    
    private func initialize() {
        sessionQueue = DispatchQueue(label: "session queue")
        captureDevice = availableCaptureDevices.first ?? AVCaptureDevice.default(for: .video)
    }
    
    private func configureCaptureSession(completionHandler: (_ success: Bool) -> Void) {
        
        var success = false
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }
        
        guard
            let captureDevice = captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            logger.error("Failed to obtain video input.")
            return
        }
        
        captureSession.sessionPreset = self.selectedResolution
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA]
        
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        
        guard captureSession.canAddInput(deviceInput) else {
            logger.error("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            logger.error("Unable to add video output to capture session.")
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)
        
        self.deviceInput = deviceInput
        self.videoOutput = videoOutput
        
        isCaptureSessionConfigured = true
        
        success = true
    }
    
    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.debug("Camera access authorized.")
            return true
        case .notDetermined:
            logger.debug("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
            sessionQueue.resume()
            return status
        case .denied:
            logger.debug("Camera access denied.")
            return false
        case .restricted:
            logger.debug("Camera library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
    
    private func deviceInputFor(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            logger.error("Error getting capture device input: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        guard isCaptureSessionConfigured else { return }
        
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }
        
        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput), captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
    }
    
    func setFPS(fps: Double) {
        if let captureDevice = self.captureDevice {
            do{
                try captureDevice.lockForConfiguration()
            }
            catch {
                logger.error("Error locking device for configuration: \(error.localizedDescription)")
                return
            }
            captureDevice.activeVideoMinFrameDuration = CMTime(
                value: 1,
                timescale: Int32(25)
            )
            captureDevice.activeVideoMaxFrameDuration = CMTime(
                value: 1,
                timescale: Int32(25)
            )
            
            for vFormat in captureDevice.formats {
                
                let ranges = vFormat.videoSupportedFrameRateRanges
                let filtered: Array<Double> = ranges.map({ $0.maxFrameRate } ).filter(
                    {Int32($0) >= Int32(fps)
                    } )
                if !filtered.isEmpty {
                    captureDevice.activeFormat = vFormat
                    captureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                    captureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                    break;
                }
            }
            captureDevice.unlockForConfiguration()
        }
        
    }
    
    func applyPreset(preset: CameraPreset) -> Bool{
        guard let device = captureDevice else { return false }
        
        do {
            try device.lockForConfiguration()
            let exposureMiliseonds = Int(preset.ExposureSeconds * 1000)
            let exposure = CMTime(value: CMTimeValue(exposureMiliseonds), timescale: 1000)
            device.setExposureModeCustom(duration: exposure, iso: Float(preset.ISO))
            print("set capture device exposure to \(preset.ExposureSeconds), iso: \(preset.ISO)")
        }
        catch {
            print("failed to lock device for configuration")
            return false
        }
        device.unlockForConfiguration()
        
        self.currentPreset = preset
        
        return true
    }
    
    func resetConfig(){
        self.isCaptureSessionConfigured = false
    }
    
    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("Camera access was not authorized.")
            return
        }
        
        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [unowned self] in
                    self.setFPS(fps: targetFPS)
                    self.captureSession.startRunning()
                    
                }
            }
            return
        }
        
        sessionQueue.async { [unowned self] in
            self.configureCaptureSession { success in
                guard success else { return }
                self.setFPS(fps: targetFPS)
                self.captureSession.startRunning()
                
            }
        }
    }
    
    func stop() {
        guard isCaptureSessionConfigured else { return }
        
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func switchCaptureDevice() {

        if let captureDevice = captureDevice, let index = availableCaptureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % availableCaptureDevices.count
            self.captureDevice = availableCaptureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }
    }
    
    func setTorch(torchLevel: Float){
        guard let device = captureDevice,
              device.hasTorch,
              device.isTorchAvailable else {
            logger.error("Torch not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if torchLevel > 0 {
                device.torchMode = .on
                try device.setTorchModeOn(level: torchLevel)
            }else{
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            logger.error("Error setting torch level: \(error)")
        }
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        connection.videoOrientation = .portrait
        addToRawPreviewStream?(pixelBuffer)
    }
}

extension Camera {
    func applyPreset(_ preset: CameraPreset) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera detected")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Baseline preset:
            if preset.id == 1 {
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                
                device.unlockForConfiguration()
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
            self.currentPreset = preset
            
        } catch {
            print("Error configuring camera: \(error)")
        }
    }
}

fileprivate let logger = Logger(subsystem: "PPG Research APP", category: "Camera")

