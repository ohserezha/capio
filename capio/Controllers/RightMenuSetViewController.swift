//
//  RightMenuSetViewController.swift
//  capio
//
//  Created by Roman on 2/22/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit
import AVFoundation

enum OrientationStates: Int {
    case landscapeLocked, portraitLocked, auto
}

enum TimerStates: Int {
    case off, ticking
}

enum TimerScales: Int {
    case off, treeSec, tenSec
}

class RightMenuSetViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet var deviceOrientationView:        UIView!

    @IBOutlet var deviceOrientationImage:       UIImageView!
    @IBOutlet var deviceOrientationLockedImage: UIImageView!
    @IBOutlet var deviceOrientationFreeImage:   UIImageView!
    
    @IBOutlet var flashModeView:                UIView!
    
    @IBOutlet var flashOnImg:                   UIImageView!
    @IBOutlet var flashOffImg:                  UIImageView!
    @IBOutlet var flashAutoImg:                 UIImageView!
    
    @IBOutlet var gridView:                     UIView!
    
    @IBOutlet var gridOffImgView:               UIImageView!
    @IBOutlet var gridDoubleImg:                UIImageView!
    @IBOutlet var gridQuadImg:                  UIImageView!
    
    @IBOutlet var timerView:                    UIView!
    
    @IBOutlet var timerViewImg:                 UIImageView!
    @IBOutlet var timePicker:                   UIPickerView!
    @IBOutlet var timerOffImg:                  UIImageView!
    
    private var photoTimer:                     Timer!
    
    var timerState: TimerStates! {
        didSet {
            timerStateRaw = timerState.rawValue
        }
    }
    
    var timerScale: TimerScales! {
        didSet {
            timerScaleRaw = timerScale.rawValue
        }
    }
    
    var gridState: GridFactors! {
        didSet {
            gridRawState = gridState.rawValue
        }
    }
    
    private var _isOrientationSwitchEnabled:    Bool = false
    
    var isOrientationSwitchEnabled: Bool {
        set {
            if (self.deviceOrientationView != nil) {
                if (newValue) {
                    self.deviceOrientationView?.alpha = 1.0
                } else {
                    self.deviceOrientationView?.alpha = 0.4
                }
            }
            
            self._isOrientationSwitchEnabled = newValue
        }
        get {
            return self._isOrientationSwitchEnabled
        }
    }
    
    var orientationState: OrientationStates! {
        didSet {
            orientationRawState = orientationState.rawValue
        }
    }
    
    private var _isFlashAvailable: Bool = false
    
    var isFlashAvailable: Bool {
        set {
            if (self.flashModeView != nil) {
                if (newValue) {
                    self.flashModeView?.alpha = 1.0
                } else {
                    self.flashModeView?.alpha = 0.4
                }
            }
            
            self._isFlashAvailable = newValue
        }
        get {
            return self._isFlashAvailable
        }
    }
    
    var flashModeState: AVCaptureFlashMode? {
        didSet {
            flashModeRawState = (flashModeState?.rawValue)!
        }
    }
    
    dynamic var flashModeRawState:      Int = 0
    
    dynamic var orientationRawState:    Int = 0
    
    dynamic var gridRawState:           Int = 0
    
    dynamic var timerStateRaw:          Int = 0
    
    dynamic var timerScaleRaw:          Int = 1
    
    override func viewDidLoad() {
        
        let orientationTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onOrientationTap))
        
        deviceOrientationView.addGestureRecognizer(orientationTapRecognizer)
        
        let flashTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onFlashModeTap))
        
        flashModeView.addGestureRecognizer(flashTapRecognizer)
        
        let gridTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onGridTap))
        
        gridView.addGestureRecognizer(gridTapRecognizer)
        
        let timerTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onTimerTap))
        
        timerView.addGestureRecognizer(timerTapRecognizer)
        
        orientationState            = OrientationStates.auto
        isOrientationSwitchEnabled  = true
        setOrientation(orientationState!)
        
        flashModeState              = .off
        setFlashMode(flashModeState!)
        
        timerView.layer.masksToBounds   = true
        timerScale                      = .off
        timerState                      = .off
        
        timePicker.delegate = self
        timePicker.dataSource = self
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch timerScale as TimerScales {
            case .treeSec:
                return 4
            case .tenSec:
                return 11
            default:
                return 0
        }
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        //todo: on tick goes here
    }
    
    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 50
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(row)
    }
    
    public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        
        let title = NSAttributedString(string: String(row), attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16.0, weight: UIFontWeightRegular)])
        label.attributedText = title
        label.textColor = UIColor.white
        label.textAlignment = .right
        
        return label
    }
    
    func startTimerTick(_ completion: @escaping () -> Void) {
        self.timerState = TimerStates.ticking
        self.timerViewImg.alpha = 0.4

        photoTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer) in
            if (self.timePicker.selectedRow(inComponent: 0) == 0) {
                self.photoTimer.invalidate()
                self.photoTimer = nil
                self.timerState = TimerStates.off
                self.timerViewImg.alpha = 1.0

                self._resetTimerPicker()
                completion()
            } else {
                let nextRowToSelect = self.timePicker.selectedRow(inComponent: 0) - 1
                self.timePicker.selectRow(nextRowToSelect, inComponent: 0, animated: true)
            }
        })
        
    }
    
    func onOrientationTap(_ recognizer: UIGestureRecognizer) {
        if (isOrientationSwitchEnabled) {
            let newVal = OrientationStates(rawValue: orientationRawState + 1)
            orientationState = newVal == nil ? OrientationStates.landscapeLocked : newVal!
            
            setOrientation(orientationState!)
        }
    }
    
    func onFlashModeTap(_ recognizer: UIGestureRecognizer) {
        if (isFlashAvailable) {
            let newVal = AVCaptureFlashMode(rawValue: flashModeRawState + 1)
            //todo: do a better cal for state than <=2
            flashModeState = newVal != nil && (newVal?.rawValue)! <= 2 ? newVal! : AVCaptureFlashMode.off
            
            setFlashMode(flashModeState!)
        }
    }
    
    func onGridTap(_ recognizer: UIGestureRecognizer) {
        let newVal = GridFactors(rawValue: gridRawState + 1)
        //todo: do a better cal for state than <=2
        gridState = newVal != nil ? newVal! : GridFactors.off
        
        setGridMode(gridState!)
    }
    
    func onTimerTap(_ recogniaer: UIGestureRecognizer) {
        if (timerState != .ticking) {
            let newVal = TimerScales(rawValue: timerScaleRaw + 1)
            //todo: do a better cal for state than <=2
            timerScale = newVal != nil ? newVal! : TimerScales.off
            
            setTimerMode(timerScale!)
        }
    }
    
    private func setTimerMode(_ timerMode: TimerScales) {
        var onAlpha: CGFloat = 0.0
        var offAlpha: CGFloat = 0.0
        switch timerMode {
        case .off:
            offAlpha = 1.0
            break
        default :
            onAlpha = 1.0
            _resetTimerPicker()
            break
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.timerOffImg.alpha = offAlpha
            self.timerViewImg.alpha = onAlpha
            self.timePicker.alpha = onAlpha
        })
    }
    
    private func _resetTimerPicker() {
        timePicker.reloadComponent(0)
        timePicker.selectRow(timePicker.numberOfRows(inComponent: 0) - 1, inComponent: 0, animated: true)
    }
    
    private func setGridMode(_ gridMode: GridFactors) {
        var quadAlpha: CGFloat = 0.0
        var doubleAlpha: CGFloat = 0.0
        var offAlpha: CGFloat = 0.0
        switch gridMode {
        case .off:
            offAlpha = 1.0
            break
        case .double:
            doubleAlpha = 1.0
            break
        case .quad:
            quadAlpha = 1.0
            break
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.gridOffImgView.alpha = offAlpha
            self.gridDoubleImg.alpha = doubleAlpha
            self.gridQuadImg.alpha = quadAlpha
        })
    }
    
    private func setFlashMode(_ flashMode: AVCaptureFlashMode) {
        var autoAlpha: CGFloat = 0.0
        var onAlpha: CGFloat = 0.0
        var offAlpha: CGFloat = 0.0
        switch flashMode {
        case .off:
            offAlpha = 1.0
            break
        case .on:
            onAlpha = 1.0
            break
        case .auto:
            autoAlpha = 1.0
            break
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.flashOnImg.alpha = onAlpha
            self.flashOffImg.alpha = offAlpha
            self.flashAutoImg.alpha = autoAlpha
        })
    }
    
    private func setOrientation(_ orientationState: OrientationStates) {
        let transform: CGAffineTransform
        var lockAlpha: Float = 0.0
        switch orientationState {
            case .landscapeLocked:
                transform =  CGAffineTransform(rotationAngle: degToRad(270.0))
                lockAlpha = 1.0
                break
            case .portraitLocked:
                transform =  CGAffineTransform(rotationAngle: degToRad(0.0))
                lockAlpha = 1.0
                break
            case .auto:
                transform =  CGAffineTransform(rotationAngle: degToRad(315.0))
                lockAlpha = 0.0
                break
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.deviceOrientationImage.transform = transform
            self.deviceOrientationLockedImage.alpha = CGFloat(lockAlpha)
            self.deviceOrientationFreeImage.alpha = lockAlpha == 0.0 ? 1.0 : 0.0
        })
    }
    
    private func degToRad(_ angleDeg: CGFloat = 0) -> CGFloat {
        return angleDeg * CGFloat(M_PI/180)
    }
}
