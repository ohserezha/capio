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
    
    // Some default settings
    let EXPOSURE_DURATION_POWER:            Float       = 4.0 //the exposure slider gain
    let EXPOSURE_MINIMUM_DURATION:          Float64     = 1.0/2000.0
    
    var captureDevice :                     AVCaptureDevice!
    
    var exposureDuration:                   CMTime!
    var focusDistance:                      Float       = 0
    var isoValue:                           Float       = 100
    var shutterValue:                       Float       = 0.0
    
    var temperatureValue:                   Float!
    
    var currentColorTemperature:            AVCaptureWhiteBalanceTemperatureAndTintValues!
    var currentColorGains:                  AVCaptureWhiteBalanceGains!
    
    private var sliderViewScalePicker:      ScalePicker!
    
    private var activeSlider:               ScalePicker! = nil
    private var activeSliderType:           CameraOptionsTypes = CameraOptionsTypes.focus
    private var activeSliderValueObj:       SliderValue! = nil
    
    @IBOutlet var blurViewMain:             UIVisualEffectView!
    @IBOutlet var sliderView:               UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        blurViewMain.layer.masksToBounds = true
        blurViewMain.layer.cornerRadius = 5
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
    
    func setActiveDevice(_ device: AVCaptureDevice) {
        if device.isKind(of: AVCaptureDevice.self) {
            captureDevice = device

            setCurrentDefaultCameraSettings()
        }
        else {
            print("Invalid device added")
        }
    }
    
    func setActiveSlider(_ sliderType: CameraOptionsTypes = CameraOptionsTypes.focus) {
        activeSliderType = sliderType
        setCaptureSession()
        setUi()
    }
    
    func unsetActiveslider() {
        if (activeSlider != nil) {
            activeSlider.removeFromSuperview()
            activeSlider = nil
        }
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
        
        sliderViewScalePicker = ScalePicker(frame:
            CGRect.init(x: 0, y: 0, width: sliderView.bounds.size.width, height: sliderView.bounds.size.height)
        )
            
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
        
        activeSlider.delegate = self
        activeSlider.spaceBetweenTicks = 12.0
        activeSlider.showTickLabels = true
        activeSlider.snapEnabled = true
        activeSlider.bounces = false
        activeSlider.showCurrentValue = false
        
        activeSlider.centerArrowImage = UIImage.init(named: "indicator")
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
                
                sliderValue.value = CGFloat(floor(Double(isoValue/sliderValue.valueFactor)))
                
                sliderValue.maxValue = CGFloat(floor(Double(captureDevice!.activeFormat.maxISO/sliderValue.valueFactor)))
                sliderValue.minValue = CGFloat(ceil(Double(captureDevice!.activeFormat.minISO/sliderValue.valueFactor)))
                
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
    
    func willChangeScaleValue(_ picker: ScalePicker, value: CGFloat) {
        if (abs(picker.currentValue - value) > 0.01) {
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
                    isoValue = Float(roundedValue * activeSliderValueObj.valueFactor)
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
        //todo?
    }
    
    fileprivate func setCaptureSession() {
        setCurrentDefaultCameraSettings()
        configureCamera()
    }
    
    fileprivate func setCurrentDefaultCameraSettings() {
                
        if(captureDevice!.iso >= captureDevice!.activeFormat.maxISO) {
            isoValue = captureDevice!.activeFormat.maxISO
        } else if (captureDevice!.iso <= captureDevice!.activeFormat.minISO) {
            isoValue = captureDevice!.activeFormat.minISO
        } else {
            isoValue = captureDevice!.iso
        }

        currentColorGains = captureDevice!.deviceWhiteBalanceGains
        currentColorTemperature = captureDevice!.temperatureAndTintValues(forDeviceWhiteBalanceGains: currentColorGains)
        temperatureValue = currentColorTemperature.temperature
        
        exposureDuration = captureDevice!.exposureDuration
        
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        
        shutterValue = pow(
            Float((CMTimeGetSeconds(exposureDuration) - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds)),
            1/EXPOSURE_DURATION_POWER)
        
        focusDistance = captureDevice!.lensPosition
    }

    fileprivate func setExposureDuration(value: Float) {
        let p: Double = Double(pow( value, EXPOSURE_DURATION_POWER )); // Apply power function to expand slider's low-end range
        let minDurationSeconds: Double = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        let newSecondsAmount = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds
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
                
                device.focusMode = .locked
                device.setFocusModeLockedWithLensPosition(focusDistance, completionHandler: { (time) -> Void in })
                device.setExposureModeCustomWithDuration(exposureDuration, iso: isoValue, completionHandler: { (time) -> Void in })
                device.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(normalizedGains(currentColorGains), completionHandler: { (time) -> Void in })
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
}
