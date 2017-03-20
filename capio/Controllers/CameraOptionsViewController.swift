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

    var captureSessionManager:CaptureSessionManager! = CaptureSessionManager.sharedInstance

    private var activeSlider:               ScalePicker!
    private var activeSliderType:           CameraOptionsTypes = CameraOptionsTypes.focus
    private var activeSliderValueObj:       CameraSettingValueObj!

    @IBOutlet var blurViewMain:             UIVisualEffectView!
    @IBOutlet var sliderView:               UIView!
    @IBOutlet var modeSwitch:               UISegmentedControl!
    @IBOutlet var activeSliderValueLabel:   UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSessionManager.cameraSettingsObservable.subscribe(onNext: { deviceCurrentSettings in
            if self.activeSlider != nil && !self.captureSessionManager.isSettingAdjustble(self.activeSliderType) {
                self.activeSliderValueObj = self.captureSessionManager.getCameraSettingValueObjForType(self.activeSliderType)
                self.activeSlider.currentValue = self.activeSliderValueObj.value

                if self.modeSwitch.selectedSegmentIndex == 1 {
                    self.modeSwitch.selectedSegmentIndex = 0
                    self.activeSlider.blockedUI = true
                    self.activeSlider.alpha = 0.5
                }
            }
        })
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

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    @IBAction func onModeSwitchChange(_ modeSwitch: UISegmentedControl) {
        setActiveSettingMode(SettingLockModes(rawValue: modeSwitch.selectedSegmentIndex)!)
    }

    func setActiveSlider(_ sliderType: CameraOptionsTypes = CameraOptionsTypes.focus) {
        activeSliderType = sliderType
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

    func willChangeScaleValue(_ picker: ScalePicker, value: CGFloat) {

        if (captureSessionManager.isSettingAdjustble(activeSliderType) && abs(picker.currentValue - value) > 0.01) {
            AudioServicesPlaySystemSound(1519)

            let roundedValue = Float(Double(value).roundTo(2))

            switch(activeSliderType) {
                case CameraOptionsTypes.focus:
                    captureSessionManager.focusDistance = Float(roundedValue/activeSliderValueObj.valueFactor)
                    break
                case CameraOptionsTypes.shutter:
                    captureSessionManager.shutterValue = Float(roundedValue/activeSliderValueObj.valueFactor)
                    break
                case CameraOptionsTypes.iso:
                    captureSessionManager.isoValue = Float(roundedValue * activeSliderValueObj.valueFactor)
                    break
                case CameraOptionsTypes.temperature:
                    captureSessionManager.temperatureValue = Float(roundedValue * activeSliderValueObj.valueFactor)
                    break
            }
        }
    }

    func didChangeScaleValue(_ picker: ScalePicker, value: CGFloat) {
        setSliderLabelValue()
    }

    private func setUi() {

        guard let pickerView = getActiveSlider()
            else {
                return
        }

        sliderView.addSubview(pickerView)
    }

    private func getActiveSlider() -> ScalePicker? {

        initSlider()

        modeSwitch.selectedSegmentIndex = activeSlider.blockedUI ? 0 : 1

        activeSliderValueObj = captureSessionManager.getCameraSettingValueObjForType(activeSliderType)

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

        activeSlider.blockedUI = !captureSessionManager.isSettingAdjustble(activeSliderType)
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

    private func setActiveSettingMode(_ mode: SettingLockModes = SettingLockModes.auto) {
        captureSessionManager.setActiveSettingMode(mode, settingType: activeSliderType)
        if (mode == SettingLockModes.auto) {
            activeSlider.blockedUI = true
        } else if (mode == SettingLockModes.manual) {
            activeSlider.blockedUI = false
        }

        activeSlider.alpha = activeSlider.blockedUI ? 0.5 : 1
    }

    private func setSliderLabelValue() {
        switch(activeSliderType) {
            case CameraOptionsTypes.focus:
                activeSliderValueLabel.text = String(captureSessionManager.focusDistance)
                break
            case CameraOptionsTypes.shutter:
                activeSliderValueLabel.text = captureSessionManager.shutterStringValue
                break
            case CameraOptionsTypes.iso:
                activeSliderValueLabel.text = String(captureSessionManager.isoValue)
                break
            case CameraOptionsTypes.temperature:
                activeSliderValueLabel.text = String(captureSessionManager.temperatureValue) + "K"
                break
        }
    }
}
