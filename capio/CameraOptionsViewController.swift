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
import ElasticTransition

class CameraOptionsViewController: UIViewController, ElasticMenuTransitionDelegate {
    
    //ElasticTransition options
    var contentLength:CGFloat = 250
    var dismissByBackgroundTouch = true
    var dismissByBackgroundDrag = true
    var dismissByForegroundDrag = true
    
    // Some default settings
    let EXPOSURE_DURATION_POWER:            Float       = 4.0 //the exposure slider gain
    let EXPOSURE_MINIMUM_DURATION:          Float64     = 1.0/2000.0
    
    var captureDevice :                     AVCaptureDevice!
    
    var exposureDuration:                   CMTime!
    var focusDistance:                      Float       = 0
    var isoValue:                           Float       = 100
    
    var temperatureValue:                   Float!
    
    var currentColorTemperature:            AVCaptureWhiteBalanceTemperatureAndTintValues!
    var currentColorGains:                  AVCaptureWhiteBalanceGains!
    
    
    @IBOutlet var focusSlider:              UISlider!
    
    @IBOutlet var shutterValueLabel:        UILabel!
    @IBOutlet var shutterSlider:            UISlider!
    
    @IBOutlet var isoLabel:                 UILabel!
    @IBOutlet var isoSlider:                UISlider!
    
    @IBOutlet var temperatureSlider:        UISlider!
    @IBOutlet var temperatureValueLabel:    UILabel!
    
    @IBOutlet var focusIconLabel:           UILabel!
    @IBOutlet var shutterIconLabel:         UILabel!
    @IBOutlet var isoIconLabel:             UILabel!
    @IBOutlet var tempIconLabel:            UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        focusIconLabel.processIcons();
        shutterIconLabel.processIcons();
        isoIconLabel.processIcons();
        tempIconLabel.processIcons();

        currentColorGains = captureDevice?.deviceWhiteBalanceGains
        
        setCurrentDefaultCameraSettings()
        configureCamera()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    @IBAction func onFocusSlideDrag(sender: UISlider) {
        focusDistance = sender.value
        configureCamera()
    }
    
    @IBAction func onTemperatureSliderChange(sender: UISlider) {
        temperatureValue = sender.value
        temperatureValueLabel.text = String(temperatureValue)
        
        changeTemperatureRaw(sender.value)
        configureCamera()
    }    
    
    @IBAction func onIsoSliderChange(sender: UISlider) {
        isoValue = sender.value
        isoLabel.text = String(isoValue)
        configureCamera()
    }
    
    @IBAction func onShutterSliderChange(sender: UISlider) {
        setExposureDuration()
        configureCamera()
    }
    
    private func setCurrentDefaultCameraSettings() {
        
        focusDistance = captureDevice!.lensPosition
        isoValue = captureDevice!.ISO
        
        isoLabel.text = String(isoValue)
        isoSlider.value = isoValue
        
        focusSlider.value = focusDistance

        currentColorGains = captureDevice!.deviceWhiteBalanceGains
        currentColorTemperature = captureDevice!.temperatureAndTintValuesForDeviceWhiteBalanceGains(currentColorGains)
        temperatureSlider.value = currentColorTemperature.temperature
        temperatureValueLabel.text = String(temperatureSlider.value)
        
        exposureDuration = captureDevice!.exposureDuration
        
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        
        let shutterSpeedSliderValue = pow(
            Float((CMTimeGetSeconds(exposureDuration) - minDurationSeconds) / (maxDurationSeconds - minDurationSeconds)),
            1/EXPOSURE_DURATION_POWER)
        shutterSlider.value = shutterSpeedSliderValue
        shutterValueLabel.text = "1/\(Int(1.0 / CMTimeGetSeconds(exposureDuration)))"
    }

    private func setExposureDuration() {
        let p: Double = Double(pow( shutterSlider.value, EXPOSURE_DURATION_POWER )); // Apply power function to expand slider's low-end range
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        let newSecondsAmount = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds
        exposureDuration = CMTimeMakeWithSeconds(Float64(newSecondsAmount), 1000*1000*1000); // Scale from 0-1 slider range to actual duration
        
        shutterValueLabel.text = "1/\(Int(1.0 / newSecondsAmount))"
    }
    
    
    //Take the actual temperature value
    private func changeTemperatureRaw(temperature: Float) {
        currentColorTemperature = AVCaptureWhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0.0)
        currentColorGains = captureDevice!.deviceWhiteBalanceGainsForTemperatureAndTintValues(currentColorTemperature)        
    }
    
    // Normalize the gain so it does not exceed
    private func normalizedGains(gains: AVCaptureWhiteBalanceGains) -> AVCaptureWhiteBalanceGains {
        var g = gains;
        g.redGain = max(1.0, g.redGain);
        g.greenGain = max(1.0, g.greenGain);
        g.blueGain = max(1.0, g.blueGain);
        
        g.redGain = min(captureDevice!.maxWhiteBalanceGain, g.redGain);
        g.greenGain = min(captureDevice!.maxWhiteBalanceGain, g.greenGain);
        g.blueGain = min(captureDevice!.maxWhiteBalanceGain, g.blueGain);
        
        return g;
    }
    
    private func configureCamera() {
        
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                device.focusMode = .Locked
                device.setFocusModeLockedWithLensPosition(focusDistance, completionHandler: { (time) -> Void in })
                device.setExposureModeCustomWithDuration(exposureDuration, ISO: isoValue, completionHandler: { (time) -> Void in })
                device.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(normalizedGains(currentColorGains), completionHandler: { (time) -> Void in })
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
}