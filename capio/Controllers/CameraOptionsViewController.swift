//
//  OptionsViewController.swift
//  capio
//
//  Created by Roman on 7/24/16.
//  Copyright © 2016 theroman. All rights reserved.
//
import UIKit
import Foundation
import AVFoundation
import JQSwiftIcon
import ScalePicker

class CameraOptionsViewController:
UIViewController,
ScalePickerDelegate {
    
    enum CameraOptionsTypes {
        case focus, shutter, iso, temperature
    }
    
    enum SettingLockModes: Int {
        case auto, manual
    }
    
    private class SliderValue {
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


    // Some default settings
    let EXPOSURE_DURATION_POWER:            Float       = 4.0 //the exposure slider gain
    let EXPOSURE_MINIMUM_DURATION:          Float64     = 1.0/2000.0
    
    var captureDevice :                     AVCaptureDevice!
    
    var exposureDuration:                   CMTime!
    var focusDistance:                      Float       = 0
    var isoValue:                           Float       = 100
    var shutterValue:                       Float       = 0.0
    
    var isIsoLocked:                        Bool        = false
    var isShutterLocked:                    Bool        = false
    
    var temperatureValue:                   Float!
    
    var currentColorTemperature:            AVCaptureWhiteBalanceTemperatureAndTintValues!
    var currentColorGains:                  AVCaptureWhiteBalanceGains!
    
    private var activeSlider:               ScalePicker!
    private var activeSliderType:           CameraOptionsTypes = CameraOptionsTypes.focus
    private var activeSliderValueObj:       SliderValue!
    
    private var exposureTargetDA:           DebounceAccumulator! = DebounceAccumulator()
    private var valueStepper:               ValueStepper! = ValueStepper()
    
    @IBOutlet var blurViewMain:             UIVisualEffectView!
    @IBOutlet var sliderView:               UIView!
    
    @IBOutlet var modeSwitch: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private var kvoContext: UInt8 = 1
    
    func setActiveDevice(_ device: AVCaptureDevice) {
        if device.isKind(of: AVCaptureDevice.self) {
            captureDevice = device
            
            //todo -> i might can remove it
            setCurrentDefaultCameraSettings()
            
            exposureTargetDA.addObserver(self, forKeyPath: "accValue", options: NSKeyValueObservingOptions.new, context: nil)
            
            //it's a single observer per entire app cycle
            //so no need to remove it
            captureDevice.addObserver(self, forKeyPath: "exposureTargetOffset", options: NSKeyValueObservingOptions.new, context: nil)
        }
        else {
            print("Invalid device added")
        }
    }
    
    @IBOutlet var activeSliderValueLabel: UILabel!
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "accValue"{
            if (captureDevice!.exposureMode == .custom) {
                if (isShutterLocked && !isIsoLocked) {
                    valueStepper.startReachingTarget(_currentVal: captureDevice.iso, _targetVal: getEmulatedIso(), stepResultCallback: { stepResult in
                        if(self.isIsoLocked) {
                            self.valueStepper.stop()
                        } else {
                            self.isoValue = self.getValueWithinRange(
                                value: stepResult,
                                min: self.captureDevice!.activeFormat.minISO,
                                max: self.captureDevice!.activeFormat.maxISO,
                                defaultReturn: 100.0
                            )
                            
                            self.configureCamera()
                        }
                    })
                }
                if (isIsoLocked && !isShutterLocked) {
                    valueStepper.startReachingTarget(
                        _currentVal: Float(CMTimeGetSeconds(captureDevice.exposureDuration)),
                        _targetVal: Float(CMTimeGetSeconds(getExposureFromValue(value: pow(exp(exposureTargetDA.accValue + 18), -0.36)))),
                        speed: 1500,
                        stepResultCallback: { stepResult in
                            if(self.isShutterLocked) {
                                self.valueStepper.stop()
                            } else {
                                self.exposureDuration = self.getExposureFromValue(value: stepResult)
                                self.configureCamera()
                            }
                    })
                }
            }
            
            if (!isActiveSettingAdjustble() && activeSlider != nil) {
                //todo
                setCurrentDefaultCameraSettings()
                activeSliderValueObj = getSliderValueForType()
                activeSlider.currentValue = activeSliderValueObj.value
            }
        }
        
        if keyPath == "exposureTargetOffset"{
            exposureTargetDA.addValue(newVal: captureDevice.exposureTargetOffset)
        }
    }
    
    private func getEmulatedIso() -> Float {
        
        return getValueWithinRange(
            value: pow(exp(exposureTargetDA.accValue - 0.25), -2) + 10,
            min: captureDevice!.activeFormat.minISO,
            max: captureDevice!.activeFormat.maxISO,
            defaultReturn: 100.0
        )
    }    
    
    private func getExposureFromValue(value: Float) -> CMTime {
        let minDurationSeconds: Double = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        
        let exposure: Double = Double(getValueWithinRange(
                                        value: value,
                                        min: Float(minDurationSeconds),
                                        max: Float(maxDurationSeconds),
                                        defaultReturn: 0.01
                                    ))
            
        return CMTime.init(seconds: exposure, preferredTimescale: captureDevice!.exposureDuration.timescale)
    }
    
    func setActiveSlider(_ sliderType: CameraOptionsTypes = CameraOptionsTypes.focus) {
        activeSliderType = sliderType
        setCaptureSession()
        setUi()
        setSliderLabelValue()
    }
    
    func unsetActiveslider() {
        if (activeSlider != nil) {
            activeSlider.removeFromSuperview()
            activeSlider = nil
        }
        
        activeSliderValueLabel.text = String()
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    fileprivate func setUi() {
        
        guard let pickerView = getActiveSlider()
            else {
                return
        }
        
        sliderView.addSubview(pickerView)
    }
    
    private func getActiveSlider() -> ScalePicker? {
        
        initSlider()
        
        modeSwitch.selectedSegmentIndex = activeSlider.blockedUI ? 0 : 1
        
        activeSliderValueObj = getSliderValueForType()
            
        activeSlider.maxValue = activeSliderValueObj.maxValue
        activeSlider.minValue = activeSliderValueObj.minValue
            
        activeSlider.numberOfTicksBetweenValues = UInt(Int(5 * log10(activeSliderValueObj.valueFactor)))
    
        activeSlider.setInitialCurrentValue(activeSliderValueObj.value)
        
        return activeSlider
    }
    
    private func initSlider() {
        activeSlider = ScalePicker(frame:
            CGRect.init(x: 0, y: 0, width: sliderView.bounds.size.width, height: sliderView.bounds.size.height)
        )
        
        activeSlider.blockedUI = !isActiveSettingAdjustble()
        activeSlider.alpha = activeSlider.blockedUI ? 0.5 : 1
        
        activeSlider.delegate           = self
        activeSlider.spaceBetweenTicks  = 12.0
        activeSlider.showTickLabels     = true
        activeSlider.snapEnabled        = true
        activeSlider.bounces            = false
        activeSlider.showCurrentValue   = false
        activeSlider.showTickLabels     = false
        
        activeSlider.centerArrowImage   = UIImage.init(named: "indicator")
    }
    
    private func isActiveSettingAdjustble() -> Bool {
        switch(activeSliderType) {
            case CameraOptionsTypes.focus:
                return captureDevice.focusMode == .locked
            case CameraOptionsTypes.shutter:
                return captureDevice.exposureMode == .custom && isShutterLocked
            case CameraOptionsTypes.iso:
                return captureDevice.exposureMode == .custom && isIsoLocked
            case CameraOptionsTypes.temperature:
                return captureDevice.whiteBalanceMode == .locked
        }
    }
    
    private func getSliderValueForType() -> SliderValue {
        let sliderValue = SliderValue()
        
        switch(activeSliderType) {
            case CameraOptionsTypes.focus:
                sliderValue.value = CGFloat(focusDistance * 10)
                sliderValue.maxValue = 10.0
                sliderValue.minValue = 0.0
                break
            case CameraOptionsTypes.shutter:
                let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
                let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
                
                sliderValue.value = CGFloat(pow(
                    Float((CMTimeGetSeconds(exposureDuration) - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds)),
                    1/EXPOSURE_DURATION_POWER)) * 10
                
                sliderValue.minValue = 0.0
                sliderValue.maxValue = 10.0
                
                break
            
            case CameraOptionsTypes.iso:
                
                sliderValue.valueFactor = 100
                
                sliderValue.value = CGFloat(Double(isoValue/sliderValue.valueFactor))
                
                sliderValue.maxValue = CGFloat(floor(Double(captureDevice!.activeFormat.maxISO/sliderValue.valueFactor)))
                sliderValue.minValue = CGFloat(floor(Double(captureDevice!.activeFormat.minISO/sliderValue.valueFactor)))
                
                break
            
            case CameraOptionsTypes.temperature:
                
                sliderValue.valueFactor = 1000
                
                sliderValue.value = CGFloat(floor(Double(temperatureValue/sliderValue.valueFactor)))
            
                sliderValue.maxValue = 10.0
                sliderValue.minValue = 1.0
            
                break
        }
        
        return sliderValue
    }       
    
    @IBAction func onModeSwitchChange(_ modeSwitch: UISegmentedControl) {
        setActiveSettingMode(SettingLockModes(rawValue: modeSwitch.selectedSegmentIndex)!)
    }
    
    private func setActiveSettingMode(_ mode: SettingLockModes = SettingLockModes.auto) {
        do {
            try captureDevice.lockForConfiguration()
            if (mode == SettingLockModes.auto) {
                switch(activeSliderType) {
                case CameraOptionsTypes.focus:
                    captureDevice.focusMode = .continuousAutoFocus
                    break
                case CameraOptionsTypes.shutter:
                    captureDevice.exposureMode = isIsoLocked ? .custom : .continuousAutoExposure
                    isShutterLocked = false
                    break
                case CameraOptionsTypes.iso:
                    captureDevice.exposureMode = isShutterLocked ? .custom : .continuousAutoExposure
                    isIsoLocked = false
                    break
                case CameraOptionsTypes.temperature:
                    captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                    break
                }
                
                activeSlider.blockedUI = true
                
            } else if (mode == SettingLockModes.manual) {
                switch(activeSliderType) {
                case CameraOptionsTypes.focus:
                    captureDevice.focusMode = .locked
                    break
                case CameraOptionsTypes.shutter:
                    captureDevice.exposureMode = .custom
                    isShutterLocked = true
                    break
                case CameraOptionsTypes.iso:
                    captureDevice.exposureMode = .custom
                    isIsoLocked = true
                    break
                case CameraOptionsTypes.temperature:
                    captureDevice.whiteBalanceMode = .locked
                    break
                }
                
                activeSlider.blockedUI = false
            }
            
            activeSlider.alpha = activeSlider.blockedUI ? 0.5 : 1
            
            captureDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        
        configureCamera()
    }
    
    func willChangeScaleValue(_ picker: ScalePicker, value: CGFloat) {
        
        if (isActiveSettingAdjustble() && abs(picker.currentValue - value) > 0.01) {
            AudioServicesPlaySystemSound(1519)
            
            let roundedValue = Float(Double(value).roundTo(2))
            
            switch(activeSliderType) {
                case CameraOptionsTypes.focus:
                    focusDistance = Float(roundedValue/activeSliderValueObj.valueFactor)
                    break
                case CameraOptionsTypes.shutter:
                    shutterValue = Float(roundedValue/activeSliderValueObj.valueFactor)
                    setExposureDuration(value: shutterValue)
                    break
                case CameraOptionsTypes.iso:
                    isoValue = getValueWithinRange(
                        value: Float(roundedValue * activeSliderValueObj.valueFactor),
                        min: captureDevice!.activeFormat.minISO,
                        max: captureDevice!.activeFormat.maxISO,
                        defaultReturn: 100.0
                    )
                    break
                case CameraOptionsTypes.temperature:
                    temperatureValue = Float(roundedValue * activeSliderValueObj.valueFactor)
                    changeTemperatureRaw(temperatureValue)
                    break
            }
            configureCamera()
        }
    }
    
    func didChangeScaleValue(_ picker: ScalePicker, value: CGFloat) {
        setSliderLabelValue()
    }
    
    private func setSliderLabelValue() {
        switch(activeSliderType) {
        case CameraOptionsTypes.focus:
            activeSliderValueLabel.text = String(focusDistance)
            break
        case CameraOptionsTypes.shutter:
            
            let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
            let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
            
            let p: Double = Double(pow( shutterValue, EXPOSURE_DURATION_POWER ))
            var newSecondsAmount = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds
            
            if(newSecondsAmount.isNaN) {
                print("setSliderLabelValue: newSecondsAmount is NaN setting it to 2000")
                print("setSliderLabelValue: p: " + String(p))
                print("setSliderLabelValue: minDurationSeconds: " + String(minDurationSeconds))
                print("setSliderLabelValue: maxDurationSeconds: " + String(maxDurationSeconds))
                newSecondsAmount = minDurationSeconds
            }
            activeSliderValueLabel.text = String("1/\(Int(1.0 / newSecondsAmount))")
            break
        case CameraOptionsTypes.iso:
            activeSliderValueLabel.text = String(isoValue)
            break
        case CameraOptionsTypes.temperature:
            activeSliderValueLabel.text = String(temperatureValue) + "K"
            break
        }
    }
    
    private func getValueWithinRange(value: Float, min: Float, max: Float, defaultReturn: Float) -> Float {
        
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
    
    fileprivate func setCaptureSession() {
        setCurrentDefaultCameraSettings()
        configureCamera()
    }
    
    fileprivate func setCurrentDefaultCameraSettings() {
        
        isoValue = getValueWithinRange(
            value: captureDevice!.iso,
            min: captureDevice!.activeFormat.minISO,
            max: captureDevice!.activeFormat.maxISO,
            defaultReturn: 100.0)

        currentColorGains = captureDevice!.deviceWhiteBalanceGains
        currentColorTemperature = captureDevice!.temperatureAndTintValues(forDeviceWhiteBalanceGains: currentColorGains)
        temperatureValue = currentColorTemperature.temperature
        
        exposureDuration = captureDevice!.exposureDuration
        
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        
        shutterValue = pow(
            Float(max(0,(CMTimeGetSeconds(exposureDuration) - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds))),
            1/EXPOSURE_DURATION_POWER)
        
        focusDistance = captureDevice!.lensPosition
    }

    fileprivate func setExposureDuration(value: Float) {
        let p: Double = Double(pow( value, EXPOSURE_DURATION_POWER )); // Apply power function to expand slider's low-end range
        let minDurationSeconds: Double = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        let newSecondsAmount = min(0.16, p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds)
        exposureDuration = CMTimeMakeWithSeconds(Float64(newSecondsAmount), 1000*1000*1000); // Scale from 0-1 slider range to actual duration
    }
    
    //Take the actual temperature value
    fileprivate func changeTemperatureRaw(_ temperature: Float) {
        currentColorTemperature = AVCaptureWhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0.0)
        currentColorGains = captureDevice!.deviceWhiteBalanceGains(for: currentColorTemperature)        
    }
    
    // Normalize the gain so it does not exceed
    fileprivate func normalizedGains(_ gains: AVCaptureWhiteBalanceGains) -> AVCaptureWhiteBalanceGains {
        var g = gains;
        g.redGain = max(1.0, g.redGain);
        g.greenGain = max(1.0, g.greenGain);
        g.blueGain = max(1.0, g.blueGain);
        
        g.redGain = min(captureDevice!.maxWhiteBalanceGain, g.redGain);
        g.greenGain = min(captureDevice!.maxWhiteBalanceGain, g.greenGain);
        g.blueGain = min(captureDevice!.maxWhiteBalanceGain, g.blueGain);
        
        return g;
    }
    
    fileprivate func configureCamera() {
        
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
