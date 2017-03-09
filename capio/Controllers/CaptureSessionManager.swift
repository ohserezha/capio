//
//  CaptureSessionManager.swift
//  capio
//
//  Created by Roman on 3/7/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit
import Photos
import CoreMotion

import BRYXBanner

import RxSwift
import RxCocoa

class CaptureSessionManager:
    NSObject,
    AVCaptureFileOutputRecordingDelegate,
    AVCapturePhotoCaptureDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate {

    //this is how a roll singletons here
    static let sharedInstance : CaptureSessionManager = {
        let instance = CaptureSessionManager()
        return instance
    }()

    // Some default settings
    let EXPOSURE_DURATION_POWER:            Float       = 4.0 //the exposure slider gain
    let EXPOSURE_MINIMUM_DURATION:          Float64     = 1.0/2000.0
    let SUPPORTED_ASPECT_RATIO:             Double      = 1280/720

    private class DebounceAccumulator: NSObject {

        static let DEFAULT_DEBOUNCE_COUNT:         Int     = 30
        static let DEFAULT_INTERVAL_UPDATE:        Double  = 0.1 //sec

        var resultsAmountCount:             Int
        var updateInsureTimer:              Timer!
        var updateInsureTimerInterval:      Double

        dynamic var accValue:               Float   = 0.0

        private var currentlyAccValsArray:  Array   = [Float]()

        init(
            _resultsAmountCount:    Int     = DebounceAccumulator.DEFAULT_DEBOUNCE_COUNT,
            _updateTimerInterval:   Double  = DebounceAccumulator.DEFAULT_INTERVAL_UPDATE
            ) {
            resultsAmountCount          = _resultsAmountCount
            updateInsureTimerInterval   = _updateTimerInterval
        }

        func stop() {
            _killTimer()
        }

        private func _killTimer() {
            if (updateInsureTimer != nil) {
                updateInsureTimer.invalidate()
                updateInsureTimer = nil
            }
        }

        func addValue(newVal: Float) {
            _killTimer()

            if(currentlyAccValsArray.count < resultsAmountCount) {
                currentlyAccValsArray.append(newVal)

                updateInsureTimer = Timer.scheduledTimer(withTimeInterval: updateInsureTimerInterval, repeats: false, block: { timer in
                    self.addValue(newVal: self.currentlyAccValsArray.last!)
                })
            } else {
                accValue = currentlyAccValsArray.reduce(0, { $0 + $1 }) / Float(resultsAmountCount)
                currentlyAccValsArray = [Float]()
            }
        }
    }

    private class ValueStepper {

        private var timer: Timer!

        func startReachingTarget(
            _currentVal: Float,
            _targetVal: Float,
            delta: Float = 1,
            speed: Float = 2500.0, //the lower the value the faster it goes
            precision: Float = 0.000000001,
            stepResultCallback: @escaping (_ result: Float) -> Void
            ) {
            var time: Float = 0.0
            var timeLapsed: Float = 0

            _killTimer()

            timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true, block: { timer in
                var value: Float

                timeLapsed += 16.0
                time = time >= 1.0 ? time : Float(timeLapsed/speed)

                value = max(0.000001, delta * self.getTime(time: Float(time)))

                let exitCriteria: Float = _currentVal + value * (_targetVal - _currentVal);

                if( abs(exitCriteria - _targetVal) <= precision ) {
                    self._killTimer()
                } else {
                    stepResultCallback(exitCriteria)
                }
            })
        }

        private func getTime(time: Float) -> Float {
            // ease_in_quad
            return time * time
        }

        func stop() {
            _killTimer()
        }

        private func _killTimer() {
            if (timer != nil) {
                timer.invalidate()
                timer = nil
            }
        }
    }

    var cameraSettingsObservable:               BehaviorSubject<CameraSessionSettings> = BehaviorSubject<CameraSessionSettings>(value: CameraSessionSettings())

    private var captureSession:                 AVCaptureSession?
    private var captureStillImageOut:           AVCapturePhotoOutput?
    //todo: do private here
    var captureVideoOut:                        AVCaptureMovieFileOutput?
    private var previewLayer:                   AVCaptureVideoPreviewLayer?
    private var audioSession:                   AVAudioSession?
    private var captureDevice:                  AVCaptureDevice?

    //responsible for orientation watch
    private var motionManager:                  CMMotionManager!

    private var valueStepper:                   ValueStepper! = ValueStepper()

    private var currentOrientation:             UIInterfaceOrientation!
    private var currentPreviewLayerOrientation: AVCaptureVideoOrientation!
    private var lockOrientationState:           OrientationStates = OrientationStates.auto

    var resolutionFormatsArray:                 [ResolutionFormat] = [ResolutionFormat]()
    var activeResolutionFormat:                 ResolutionFormat!

    private var exposureValueAccumulator:       DebounceAccumulator! = DebounceAccumulator()
    var exposureDuration:                       CMTime!

    var recodringState:                         RecordingStates = .off

    var _focusDistance:                         Float       = 0
    var focusDistance:                          Float {
        set {
            _focusDistance = newValue
            self.configureCamera()
        }
        get {
            return _focusDistance
        }
    }

    var isIsoLocked:                            Bool            = false

    var _isoValue:                              Float       = 100.0
    var isoValue:                               Float {
        set {
            self._isoValue = self.getValueWithinRange(
                value: newValue,
                min: self.captureDevice!.activeFormat.minISO,
                max: self.captureDevice!.activeFormat.maxISO,
                defaultReturn: 100.0
            )

            self.configureCamera()
        }
        get {
            return self.getValueWithinRange(
                value: self._isoValue,
                min: self.captureDevice!.activeFormat.minISO,
                max: self.captureDevice!.activeFormat.maxISO,
                defaultReturn: 100.0
            )
        }
    }

    var isShutterLocked:                        Bool            = false

    var _shutterValue:                          Float       = 0.0
    var shutterValue:                           Float {
        set {
            _shutterValue = newValue
            setExposureDuration(value: newValue)
            self.configureCamera()
        }
        get {
            return _shutterValue
        }
    }

    var shutterStringValue:                     String {
        get {
            return getShutterStringValue()
        }
    }

    var _temperatureValue:                      Float       = 0.0
    var temperatureValue:                       Float {
        set {
            _temperatureValue = newValue
            changeTemperatureRaw(newValue)
            self.configureCamera()
        }
        get {
            return _temperatureValue
        }
    }

    var currentColorTemperature:                AVCaptureWhiteBalanceTemperatureAndTintValues!
    var currentColorGains:                      AVCaptureWhiteBalanceGains!

    var isFlashAvailable:                       Bool            = true
    var flashModeState:                         AVCaptureFlashMode  = .off

    func isSettingAdjustble(_ settingType: CameraOptionsTypes) -> Bool {
        switch(settingType) {
            case CameraOptionsTypes.focus:
                return captureDevice?.focusMode == .locked
            case CameraOptionsTypes.shutter:
                return captureDevice?.exposureMode == .custom && isShutterLocked
            case CameraOptionsTypes.iso:
                return captureDevice?.exposureMode == .custom && isIsoLocked
            case CameraOptionsTypes.temperature:
                return captureDevice?.whiteBalanceMode == .locked
        }
    }

    func getValueWithinRange(value: Float, min: Float, max: Float, defaultReturn: Float) -> Float {

        let valueRange:ClosedRange = min...max

        if(valueRange.contains(value)) {
            return value
        } else if (value > valueRange.upperBound){
            return valueRange.upperBound
        } else if (value < valueRange.lowerBound) {
            return valueRange.lowerBound
        }

        return defaultReturn.isFinite ? defaultReturn : (min + max)/2.0
    }

    func setPointOfInterest(_ point: CGPoint) {
        let focusPoint = CGPoint(x: point.y / (previewLayer?.bounds.height)!, y: 1.0 - point.x / (previewLayer?.bounds.width)!)

        do {
            try captureDevice!.lockForConfiguration()

            if captureDevice!.isFocusPointOfInterestSupported {
                captureDevice!.focusPointOfInterest = focusPoint
                captureDevice!.focusMode = .continuousAutoFocus
            }
            if captureDevice!.exposureMode != .custom && captureDevice!.isExposurePointOfInterestSupported {
                captureDevice!.exposurePointOfInterest = focusPoint
                captureDevice!.exposureMode = .continuousAutoExposure
            }
            captureDevice!.unlockForConfiguration()

        } catch {
            print (" [handlerCamViewTap] Error in on configuring camera")
        }
    }

    func getCameraSettingValueObjForType(_ settingType: CameraOptionsTypes) -> CameraSettingValueObj {
        let cameraSettingValueObj = CameraSettingValueObj()

        switch(settingType) {
            case CameraOptionsTypes.focus:
                cameraSettingValueObj.value = CGFloat(focusDistance * 10)
                cameraSettingValueObj.maxValue = 10.0
                cameraSettingValueObj.minValue = 0.0
                break
            case CameraOptionsTypes.shutter:
                let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
                let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);

                cameraSettingValueObj.value = CGFloat(pow(
                    Float((CMTimeGetSeconds(exposureDuration) - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds)),
                    1/EXPOSURE_DURATION_POWER)) * 10

                cameraSettingValueObj.minValue = 0.0
                cameraSettingValueObj.maxValue = 10.0

                break

            case CameraOptionsTypes.iso:

                cameraSettingValueObj.valueFactor = 100

                cameraSettingValueObj.value = CGFloat(Double(isoValue/cameraSettingValueObj.valueFactor))

                cameraSettingValueObj.maxValue = CGFloat(floor(Double(captureDevice!.activeFormat.maxISO/cameraSettingValueObj.valueFactor)))
                cameraSettingValueObj.minValue = CGFloat(floor(Double(captureDevice!.activeFormat.minISO/cameraSettingValueObj.valueFactor)))

                break

            case CameraOptionsTypes.temperature:

                cameraSettingValueObj.valueFactor = 1000

                cameraSettingValueObj.value = CGFloat(floor(Double(temperatureValue/cameraSettingValueObj.valueFactor)))

                cameraSettingValueObj.maxValue = 10.0
                cameraSettingValueObj.minValue = 1.0

                break
        }

        return cameraSettingValueObj
    }

    func setActiveSettingMode(_ mode: SettingLockModes = SettingLockModes.auto, settingType: CameraOptionsTypes) {
        do {
            try captureDevice?.lockForConfiguration()
            if (mode == SettingLockModes.auto) {
                switch(settingType) {
                case CameraOptionsTypes.focus:
                    captureDevice?.focusMode = .continuousAutoFocus
                    break
                case CameraOptionsTypes.shutter:
                    captureDevice?.exposureMode = isIsoLocked ? .custom : .continuousAutoExposure
                    isShutterLocked = false
                    break
                case CameraOptionsTypes.iso:
                    captureDevice?.exposureMode = isShutterLocked ? .custom : .continuousAutoExposure
                    isIsoLocked = false
                    break
                case CameraOptionsTypes.temperature:
                    captureDevice?.whiteBalanceMode = .continuousAutoWhiteBalance
                    break
                }


            } else if (mode == SettingLockModes.manual) {
                switch(settingType) {
                case CameraOptionsTypes.focus:
                    captureDevice?.focusMode = .locked
                    break
                case CameraOptionsTypes.shutter:
                    captureDevice?.exposureMode = .custom
                    isShutterLocked = true
                    break
                case CameraOptionsTypes.iso:
                    captureDevice?.exposureMode = .custom
                    isIsoLocked = true
                    break
                case CameraOptionsTypes.temperature:
                    captureDevice?.whiteBalanceMode = .locked
                    break
                }

            }

            captureDevice?.unlockForConfiguration()
        } catch {
            print(error)
        }

        configureCamera()
    }

    func onSessionDispose() {
        captureSession?.stopRunning()
        
        if (captureVideoOut?.isRecording)! {
            stopRecording()
        }
        
        setAndEmitCameraSettings(captureDevice!);
        
        if let inputs = captureSession?.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession?.removeInput(input)
            }
        }

        if let outputs = captureSession?.outputs as? [AVCaptureOutput] {
            for output in outputs {
                captureSession?.removeOutput(output)
            }
        }

        do {
            try audioSession?.setActive(false)
        } catch {
            print(error)
        }
    }

    func resetCaptureSession(camView: UIView) {

        self.setAudioSession()
        if !(captureSession?.isRunning)! {
            self.startCaptureSession(camView)
        }
        self.restartMotionManager()
    }

    func startStopRecording() {
        if (!(captureVideoOut?.isRecording)!) {
            self.startRecording()
        } else if(captureVideoOut?.isRecording)! {
            self.stopRecording()
        }
    }

    func onLockUnLockOrientation(_ _lockOrientationState: OrientationStates) {
        lockOrientationState = _lockOrientationState

        switch lockOrientationState {
            case .landscapeLocked:
                setPreviewLayerOrientation(UIInterfaceOrientation.landscapeLeft)
            case .portraitLocked:
                setPreviewLayerOrientation(UIInterfaceOrientation.portrait)
            case .auto:
                if currentOrientation != nil {
                    // if currentOrientation was not set -> means there was no data from accelerometer
                    // and we keep the current aorientation
                    // todo: rvisit this
                    setPreviewLayerOrientation(currentOrientation)
                }
            default:
                break
        }
    }

    func captureImage() {
        _captureImage()
    }

    func setResolution(_ newResolutionFormat: ResolutionFormat) {
        if (newResolutionFormat != activeResolutionFormat) {
            isIsoLocked     = false
            isShutterLocked = false
            
            activeResolutionFormat = newResolutionFormat

            if (self.captureVideoOut?.isRecording)! {
                self.stopRecording()
            }

            do {
                try self.captureDevice?.lockForConfiguration()
                self.captureDevice!.focusMode = .continuousAutoFocus
                self.captureDevice!.exposureMode = .continuousAutoExposure
                self.captureDevice!.whiteBalanceMode = .continuousAutoWhiteBalance

                self.captureDevice!.activeFormat = activeResolutionFormat.format
                self.captureDevice!.activeVideoMinFrameDuration = activeResolutionFormat.fpsRange.minFrameDuration
                self.captureDevice!.activeVideoMaxFrameDuration = activeResolutionFormat.fpsRange.maxFrameDuration

                self.captureDevice?.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }

    private override init() {
        super.init()
        setCaptureSession()
        setAndEmitCameraSettings(self.captureDevice!)
        setObservers()
    }

    private func setObservers() {
        captureDevice?.addObserver(self, forKeyPath: "isFlashAvailable", options: NSKeyValueObservingOptions.new, context: nil)
        captureDevice?.addObserver(self, forKeyPath: "exposureTargetOffset", options: NSKeyValueObservingOptions.new, context: nil)

        exposureValueAccumulator.addObserver(self, forKeyPath: "accValue", options: NSKeyValueObservingOptions.new, context: nil)
    }

    //1.
    private func setCaptureSession() {

        captureSession = AVCaptureSession()
        // in case you have music plaing in your phone
        // it will not get muted thanks to that AND! setAudioSession
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        // todo -> write getter for Preset (device based)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080

        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    }

    private func setAudioSession() {
        do {
            //todo -> do audioSession set/unset on video record start/stop
            audioSession = AVAudioSession.sharedInstance()
            // in case you have music plaing in your phone
            // it will not get muted thanks to that AND! automaticallyConfiguresApplicationAudioSession
            try audioSession?.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .mixWithOthers)
            let currentOutputPortNames = (audioSession?.currentRoute as AVAudioSessionRouteDescription!).outputs
            var currentOutputPortName = AVAudioSessionPortBuiltInSpeaker
            if (currentOutputPortNames.count > 0) {
                currentOutputPortName  = (currentOutputPortNames[0] as AVAudioSessionPortDescription!).portName
            }

            if (currentOutputPortName == AVAudioSessionPortBuiltInSpeaker || currentOutputPortName == AVAudioSessionPortBuiltInReceiver) {
                try audioSession?.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
            }

            try audioSession!.setActive(true)
        } catch {
            print(error)
        }
    }

    //2.
    private func startCaptureSession(_ camView: UIView) {

        var videoDeviceInput: AVCaptureInput!

        do {
            //setting video
            try videoDeviceInput = AVCaptureDeviceInput(device: captureDevice!)
        } catch {
            fatalError()
        }

        guard (captureSession?.canAddInput(videoDeviceInput))! else {
            fatalError()
        }

        captureSession?.addInput(videoDeviceInput)

        //setting audio
        let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)

        let audioDeviceInput: AVCaptureDeviceInput

        do {
            audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)

            try captureSession?.canAddInput(audioDeviceInput)
        }
        catch {
            fatalError("[startCaptureSession]Could not create AVCaptureDeviceInput instance with error: \(error).")
        }

        guard (captureSession?.canAddInput(audioDeviceInput))! else {
            fatalError()
        }

        captureSession?.addInput(audioDeviceInput as AVCaptureInput)


        captureStillImageOut = AVCapturePhotoOutput()

        guard (captureSession?.canAddOutput(captureStillImageOut))! else {
            fatalError()
        }

        captureSession?.addOutput(captureStillImageOut)

        captureStillImageOut?.isHighResolutionCaptureEnabled = true

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
        previewLayer?.frame = camView.bounds

        camView.layer.addSublayer((previewLayer)!)


        let audioDataOutput = AVCaptureAudioDataOutput()
        let queue = DispatchQueue(label: "com.theroman.capio.audiosamplequeue")

        audioDataOutput.setSampleBufferDelegate(self, queue: queue)

        guard (captureSession?.canAddOutput(audioDataOutput))! else {
            fatalError()
        }

        captureSession?.addOutput(audioDataOutput)

        captureVideoOut = AVCaptureMovieFileOutput()

        if(captureSession?.canAddOutput(captureVideoOut) != nil) {
            captureVideoOut?.minFreeDiskSpaceLimit = 1024 * 1024
            captureVideoOut?.movieFragmentInterval = kCMTimeInvalid

            captureSession?.addOutput(captureVideoOut)
        } else {
            fatalError()
        }

        //reseting res array
        resolutionFormatsArray = [ResolutionFormat]()
        for vFormat in self.captureDevice!.formats as! [AVCaptureDeviceFormat] {

            let formatDescription = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)

            let ratio = Double(formatDescription.width) / Double(formatDescription.height)

            if (ratio != SUPPORTED_ASPECT_RATIO) {
                continue
            }

            let ranges = (vFormat as AnyObject).videoSupportedFrameRateRanges as! [AVFrameRateRange]
            let frameRateObj: AVFrameRateRange = ranges[0]

            if (resolutionFormatsArray.count == 0) {
                let newResolutionFormat = ResolutionFormat(_format: vFormat, _frameRateObj: frameRateObj)
                resolutionFormatsArray.append(newResolutionFormat)
            } else {
                var matchFound:Bool = false

                resolutionFormatsArray = resolutionFormatsArray.map({ (resolutionFormat: ResolutionFormat) -> ResolutionFormat in
                    //accumulating maximum possible res for each frame-rate set
                    if(resolutionFormat.fpsRange.maxFrameRate == frameRateObj.maxFrameRate && CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription).width >= resolutionFormat.videoResolution.width) {
                        matchFound = true
                        return ResolutionFormat(_format: vFormat, _frameRateObj: frameRateObj)
                    } else {
                        return resolutionFormat
                    }
                })

                if (!matchFound) {
                    resolutionFormatsArray.append(ResolutionFormat(_format: vFormat, _frameRateObj: frameRateObj))
                }

                resolutionFormatsArray = resolutionFormatsArray.sorted(by: { $0.fpsRange.maxFrameRate < $1.fpsRange.maxFrameRate })
            }
        }
        //if we app is comming back from BG => don't reset res format that was already there
        if activeResolutionFormat == nil {
            setResolution(resolutionFormatsArray.first!)
        }
        captureSession?.startRunning()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        let _keyPath: String = keyPath == nil ? "" : keyPath!

        switch _keyPath {
            case "isFlashAvailable":
                isFlashAvailable = change?[NSKeyValueChangeKey.newKey] as! Bool

                setAndEmitCameraSettings(self.captureDevice!)

            case "accValue":
                if (captureDevice!.exposureMode == .custom) {
                    if (isShutterLocked && !isIsoLocked) {
                        valueStepper.startReachingTarget(_currentVal: (captureDevice?.iso)!, _targetVal: getEmulatedIso(), stepResultCallback: { stepResult in
                            if(self.isShutterLocked && !self.isIsoLocked) {
                                self.isoValue = stepResult
                            } else {
                                self.valueStepper.stop()
                            }
                        })
                    }
                    if (isIsoLocked && !isShutterLocked) {
                        valueStepper.startReachingTarget(
                            _currentVal: Float(CMTimeGetSeconds((captureDevice?.exposureDuration)!)),
                            _targetVal: Float(CMTimeGetSeconds(getExposureFromValue(
                                                value: pow(exp(exposureValueAccumulator.accValue + 18), -0.36),
                                                activeFormat: captureDevice!.activeFormat
                                            ))),
                            speed: 1500,
                            stepResultCallback: { stepResult in
                                if(self.isIsoLocked && !self.isShutterLocked) {
                                    self.exposureDuration = self.getExposureFromValue(value: stepResult, activeFormat: self.captureDevice!.activeFormat)
                                    self.configureCamera()
                                } else {

                                    self.valueStepper.stop()
                                }
                        })
                    }
                }

                setAndEmitCameraSettings(self.captureDevice!)

            case "exposureTargetOffset":
                exposureValueAccumulator.addValue(newVal: (captureDevice?.exposureTargetOffset)!)
            default:
                break
        }
    }

    //sets accelerometer tracking to get orientation
    private func restartMotionManager() {

        motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.2

        motionManager.startAccelerometerUpdates()
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { (timer) in
            if let accelerometerData = self.motionManager.accelerometerData {
                self.onAccelerationData(accelerometerData.acceleration)
            }
        }
    }

    private func getEmulatedIso() -> Float {

        return getValueWithinRange(
            value: pow(exp(exposureValueAccumulator.accValue - 0.25), -2) + 10,
            min: captureDevice!.activeFormat.minISO,
            max: captureDevice!.activeFormat.maxISO,
            defaultReturn: 100.0
        )
    }

    private func getExposureFromValue(value: Float, activeFormat: AVCaptureDeviceFormat) -> CMTime {
        let minDurationSeconds: Double = max(CMTimeGetSeconds(activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(activeFormat.maxExposureDuration);

        let exposure: Double = Double(getValueWithinRange(
                                        value: value,
                                        min: Float(minDurationSeconds),
                                        max: Float(maxDurationSeconds),
                                        defaultReturn: 0.01
                                    ))

        return CMTime.init(seconds: exposure, preferredTimescale: captureDevice!.exposureDuration.timescale)
    }

    private func getShutterStringValue() -> String {
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);

        let p: Double = Double(pow( shutterValue, EXPOSURE_DURATION_POWER ))
        var newSecondsAmount = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds

        if(newSecondsAmount.isNaN) {
            newSecondsAmount = minDurationSeconds
        }

        return String("1/\(Int(1.0 / newSecondsAmount))")
    }

    private func setExposureDuration(value: Float) {
        let p: Double = Double(pow( value, EXPOSURE_DURATION_POWER )); // Apply power function to expand slider's low-end range
        let minDurationSeconds: Double = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        let newSecondsAmount = min(0.16, p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds)

        exposureDuration = CMTimeMakeWithSeconds(Float64(newSecondsAmount), 1000*1000*1000); // Scale from 0-1 slider range to actual duration
    }

    //Take the actual temperature value
    private func changeTemperatureRaw(_ temperature: Float) {
        currentColorTemperature = AVCaptureWhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0.0)
        currentColorGains = captureDevice!.deviceWhiteBalanceGains(for: currentColorTemperature)
    }

    // Normalize the gain so it does not exceed
    private func normalizedGains(_ gains: AVCaptureWhiteBalanceGains) -> AVCaptureWhiteBalanceGains {
        var g = gains;
        g.redGain = max(1.0, g.redGain);
        g.greenGain = max(1.0, g.greenGain);
        g.blueGain = max(1.0, g.blueGain);

        g.redGain = min(captureDevice!.maxWhiteBalanceGain, g.redGain);
        g.greenGain = min(captureDevice!.maxWhiteBalanceGain, g.greenGain);
        g.blueGain = min(captureDevice!.maxWhiteBalanceGain, g.blueGain);

        return g;
    }

    //starts video recording
    private func startRecording(){
        recodringState = RecordingStates.on

        setAndEmitCameraSettings(self.captureDevice!)

        //todo: address long start on big resolution videos -> need a message promt for user to wait till it actually starts
        let fileNameAndExtension: String = "capioTempMovie.mov"
        let urlPath: String = NSTemporaryDirectory() + fileNameAndExtension

        let outputUrl = URL(fileURLWithPath: urlPath)
        if(FileManager().fileExists(atPath: urlPath)) {
            print("temp .mov file exists -> so gonna remove it. and todo: i might wanna remove that also after recording is done")
            do {
                try FileManager().removeItem(atPath: urlPath)
            } catch {
                print(error)
            }
        }

        captureVideoOut?.startRecording(toOutputFileURL: outputUrl as URL!, recordingDelegate: self)
    }

    private func stopRecording() {
        recodringState = RecordingStates.off

        setAndEmitCameraSettings(self.captureDevice!)

        captureVideoOut?.stopRecording()
    }

    private func onAccelerationData(_ acceleration: CMAcceleration) {
        var orientationNew: UIInterfaceOrientation!;

        if (acceleration.x >= 0.75) {
            orientationNew = UIInterfaceOrientation.landscapeLeft
        }
        else if (acceleration.x <= -0.75) {
            orientationNew = UIInterfaceOrientation.landscapeRight
        }
        else if (acceleration.y <= -0.75) {
            orientationNew = UIInterfaceOrientation.portrait
        }
        else if (acceleration.y >= 0.75) {
            orientationNew = UIInterfaceOrientation.portraitUpsideDown
        }
        else {
            // Consider same as last time
            return
        }

        if (orientationNew == currentOrientation) {
            return
        }

        currentOrientation = orientationNew;

        setPreviewLayerOrientation(currentOrientation)
    }

    private func setPreviewLayerOrientation(_ deviceOrientattion: UIInterfaceOrientation) {
        if (!(self.captureVideoOut?.isRecording)!) {
            switch deviceOrientattion {
                case .landscapeLeft:
                    if (lockOrientationState != OrientationStates.portraitLocked) {
                        currentPreviewLayerOrientation = AVCaptureVideoOrientation.landscapeLeft
                    }
                    break
                case .landscapeRight:
                    if (lockOrientationState != OrientationStates.portraitLocked) {
                        currentPreviewLayerOrientation = AVCaptureVideoOrientation.landscapeRight
                    }
                    break
                case .portrait:
                    if (lockOrientationState != OrientationStates.landscapeLocked) {
                        currentPreviewLayerOrientation = AVCaptureVideoOrientation.portrait
                    }
                    break
                case .portraitUpsideDown:
                    if (lockOrientationState != OrientationStates.landscapeLocked) {
                        currentPreviewLayerOrientation = AVCaptureVideoOrientation.portraitUpsideDown
                    }
                    break

                default:
                    break
            }

            guard let videoConnection = self.captureVideoOut?.connection(withMediaType: AVMediaTypeVideo) else {
                return
            }

            videoConnection.videoOrientation = self.currentPreviewLayerOrientation

            guard let photoConnection = self.captureStillImageOut?.connection(withMediaType: AVMediaTypeVideo) else {
                return
            }

            photoConnection.videoOrientation = self.currentPreviewLayerOrientation
        }
    }

    private func _captureImage() {
        //currently any vibration won'e work due to "by design" bug on apple's side
        //https://github.com/lionheart/openradar-mirror/issues/5479
        //https://developer.apple.com/reference/audiotoolbox/1405202-audioservicesplayalertsound
        AudioServicesPlaySystemSound(1519)

        let settings = AVCapturePhotoSettings()

        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
                                kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                                kCVPixelBufferWidthKey as String:           160,
                                kCVPixelBufferHeightKey as String:          160
                            ]

        settings.previewPhotoFormat = previewFormat
        if (captureDevice?.isFlashAvailable)! {
            settings.flashMode = flashModeState
        } else {
            settings.flashMode = AVCaptureFlashMode.off
        }

        settings.isHighResolutionPhotoEnabled = true

        //todo: make a wait_promt here, cuz on higher resolution sampleBuffer might take pretty long
        // specifically on night images

        captureStillImageOut!.capturePhoto(with: settings, delegate: self)
    }

    // photo success/fail save
    func onImageSaved(_ savedImage: UIImage, didFinishSavingWithError error: NSError?, contextInfo:UnsafeRawPointer) {
        if error == nil {
            //coz you need to run UIKit opeartions on main thread
            DispatchQueue.main.async {
                let banner = Banner(
                    title: "Awesome!",
                    subtitle: "You made a picture!",
                    // todo
                    // works locally but this needs to be merged:
                    // https://github.com/bryx-inc/BRYXBanner/pull/48
                    image: savedImage,
                    backgroundColor: UIColor(red:13.00/255.0, green:13.0/255.0, blue:13.5/255.0, alpha:0.500))
                banner.dismissesOnTap = true
                banner.show(duration: 1.0)
            }
        } else {

            //coz you need to run UIKit opeartions on main thread
            DispatchQueue.main.async {
                let errorBanner = Banner(
                    title: "Shoot!",
                    subtitle: "something went terrebly wrong :(",
                    backgroundColor: UIColor(red:188.00/255.0, green:16.0/255.0, blue:16.5/255.0, alpha:0.500))
                errorBanner.dismissesOnTap = true
                errorBanner.show(duration: 1.5)
            }
        }
    }

    //photo is being captured right here
    @objc(captureOutput:didFinishProcessingPhotoSampleBuffer:previewPhotoSampleBuffer:resolvedSettings:bracketSettings:error:) func capture(
        _ captureOutput: AVCapturePhotoOutput,
        didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
        previewPhotoSampleBuffer: CMSampleBuffer?,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        bracketSettings racketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {

        if let error = error {
            print(error.localizedDescription)
        }

        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {

            let imageToSave = UIImage(data: dataImage)

            UIImageWriteToSavedPhotosAlbum(imageToSave!,
                                           self,
                                           #selector(CaptureSessionManager.onImageSaved(_:didFinishSavingWithError:contextInfo:)),
                                           nil)
        } else {
            print("Error on saving the image")
        }
    }
    //video is being captured right here
    func capture(
        _ captureOutput: AVCaptureFileOutput!,
        didFinishRecordingToOutputFileAt fileURL: URL!,
        fromConnections connections: [Any]!,
        error: Error!
        ) {

        if (error != nil) {
            //finish loading message is being written in error obj for what ever reason
            // todo: test for space limit
            print("error: " + error.localizedDescription)
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)})
        { completed, error in
            if completed {
                print("Video asset created")
                //coz you need to run UIKit opeartions on main thread
                DispatchQueue.main.async {
                    let banner = Banner(
                        title: "Swells!",
                        subtitle: "You made a video!",
                        backgroundColor: UIColor(red:13.00/255.0, green:13.0/255.0, blue:13.5/255.0, alpha:0.500))
                    banner.dismissesOnTap = true
                    banner.show(duration: 1.0)
                }
            } else {
                print(error?.localizedDescription ?? "PHPhotoLibrary.requestAuthorization did not worked out")

                //coz you need to run UIKit opeartions on main thread
                DispatchQueue.main.async {
                    let errorBanner = Banner(
                        title: "Damn!",
                        subtitle: "no luck saving dat :(",
                        backgroundColor: UIColor(red:188.00/255.0, green:16.0/255.0, blue:16.5/255.0, alpha:0.500))
                    errorBanner.dismissesOnTap = true
                    errorBanner.show(duration: 1.5)
                }
            }
        }
    }

    private func setAndEmitCameraSettings(_ captureDevice: AVCaptureDevice) {

        if !isSettingAdjustble(CameraOptionsTypes.iso) {
            isoValue = getValueWithinRange(
                value: captureDevice.iso,
                min: captureDevice.activeFormat.minISO,
                max: captureDevice.activeFormat.maxISO,
                defaultReturn: 100.0)
        }

        if !isSettingAdjustble(CameraOptionsTypes.temperature) {
            currentColorGains = captureDevice.deviceWhiteBalanceGains
            currentColorTemperature = captureDevice.temperatureAndTintValues(forDeviceWhiteBalanceGains: currentColorGains)
            temperatureValue = currentColorTemperature.temperature
        }

        if !isSettingAdjustble(CameraOptionsTypes.shutter) {
            exposureDuration = captureDevice.exposureDuration

            let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
            let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration);

            shutterValue = pow(
                Float(max(0,(CMTimeGetSeconds(exposureDuration) - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds))),
                1/EXPOSURE_DURATION_POWER)
        }

        if !isSettingAdjustble(CameraOptionsTypes.focus) {
            focusDistance = captureDevice.lensPosition
        }
        
        isFlashAvailable = captureDevice.isFlashAvailable
        
        //todo: guess need to trigger this only if anything is changed actually
        cameraSettingsObservable.onNext(CameraSessionSettings.init(
            _iso:               isoValue,
            _shutter:           shutterValue,
            _temperature:       temperatureValue,
            _focusdistance:     focusDistance,
            _flashModeState:    flashModeState,
            _isFlashAvailable:  isFlashAvailable,
            _recordingState:    recodringState
        ))
    }

    private func configureCamera() {

        if let device = captureDevice {
            do {
                try device.lockForConfiguration()

                if (device.focusMode == .locked) {
                    device.setFocusModeLockedWithLensPosition(focusDistance, completionHandler: { (time) -> Void in })
                }

                //iso and shutter
                if (device.exposureMode == .custom) {
                    device.setExposureModeCustomWithDuration(exposureDuration, iso: isoValue, completionHandler: { (time) -> Void in })
                }

                //temperature
                if (device.whiteBalanceMode == .locked) {
                    device.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(normalizedGains(currentColorGains), completionHandler: { (time) -> Void in })

                }

                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
}

enum RecordingStates: Int {
    case off, on
}

enum CameraOptionsTypes: Int {
    case focus, shutter, iso, temperature
}

enum SettingLockModes: Int {
    case auto, manual
}

class CameraSessionSettings {
    let iso:                Float
    let shutter:            Float
    let temperature:        Float
    let focusdistance:      Float
    let flashModeState:     AVCaptureFlashMode
    let isFlashAvailable:   Bool
    let recordingState:     RecordingStates

    init (
        _iso:               Float                   = 0.0,
        _shutter:           Float                   = 0.0,
        _temperature:       Float                   = 1000,
        _focusdistance:     Float                   = 0.0,
        _flashModeState:    AVCaptureFlashMode      = .off,
        _isFlashAvailable:  Bool                    = true,
        _recordingState:    RecordingStates         = .off
        ) {
        iso              = 	_iso
        shutter          = 	_shutter
        temperature      =   _temperature
        focusdistance    =   _focusdistance
        flashModeState   =   _flashModeState
        isFlashAvailable =  _isFlashAvailable
        recordingState   =   _recordingState
    }
}

class CameraSettingValueObj {
    var value:      CGFloat = 0.0
    var maxValue:   CGFloat = 1.0
    var minValue:   CGFloat = -1.0
    var valueFactor: Float = 10.0

    init(
        _value: CGFloat = 0.0,
        _maxValue: CGFloat = 1.0,
        _minValue: CGFloat = -1.0,
        _valueFactor: Float = 10.0) {
        value       = _value
        maxValue    = _maxValue
        minValue    = _minValue
        valueFactor = _valueFactor
    }
}
