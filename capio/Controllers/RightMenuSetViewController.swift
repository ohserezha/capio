//
//  RightMenuSetViewController.swift
//  capio
//
//  Created by Roman on 2/22/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

enum OrientationStates: Int {
    case landscapeLocked, portraitLocked, auto
}

class RightMenuSetViewController: UIViewController {
    
    @IBOutlet var deviceOrientationView: UIView!

    @IBOutlet var deviceOrientationImage: UIImageView!
    @IBOutlet var deviceOrientationLockedImage: UIImageView!
    @IBOutlet var deviceOrientationFreeImage: UIImageView!
    
    var _isOrientationSwitchEnabled: Bool = false
    
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
    
    dynamic var orientationRawState: Int = 0
    
    override func viewDidLoad() {

        let edgeRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onOrientationTap))
        
        let orientationTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(RightMenuSetViewController.onOrientationTap))
        orientationTapRecognizer.numberOfTapsRequired = 1
        orientationTapRecognizer.numberOfTouchesRequired = 1
        
        deviceOrientationView.addGestureRecognizer(edgeRecognizer)
        deviceOrientationView.addGestureRecognizer(orientationTapRecognizer)
        
        orientationState            = OrientationStates.auto
        isOrientationSwitchEnabled  = true
        setOrientation(orientationState: orientationState!)
    }
    
    func onOrientationTap(_ recognizer: UIGestureRecognizer) {
        if (isOrientationSwitchEnabled) {
            let newVal = OrientationStates(rawValue: orientationRawState + 1)
            orientationState = newVal == nil ? OrientationStates.landscapeLocked : newVal!
            
            setOrientation(orientationState: orientationState!)
        }
    }
    
    private func setOrientation(orientationState: OrientationStates) {
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
