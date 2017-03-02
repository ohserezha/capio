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

class RightMenuSetViewController: UIViewController {
    
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
    
    var orientationState: OrientationStates? {
        didSet {
            orientationRawState = (orientationState?.rawValue)!
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
    
    override func viewDidLoad() {
        
        let orientationTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onOrientationTap))
        
        deviceOrientationView.addGestureRecognizer(orientationTapRecognizer)
        
        let flashTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onFlashModeTap))
        
        flashModeView.addGestureRecognizer(flashTapRecognizer)
        
        let gridTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onGridTap))
        
        gridView.addGestureRecognizer(gridTapRecognizer)
        
        orientationState            = OrientationStates.auto
        isOrientationSwitchEnabled  = true
        setOrientation(orientationState!)
        
        flashModeState              = .off
        setFlashMode(flashModeState!)
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
