//
//  MenuHostViewController.swift
//  capio
//
//  Created by Roman on 2/12/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

class MenuHostView: SharedBlurView {
    
    var activeMenuType: SettingMenuTypes = .none
    
    private var cameraOptionsViewController: CameraOptionsViewController?

    private var activeSubview: UIView!
    private var activeSubviewController: UIViewController!

    func setActiveMenu(_ viewController: UIViewController, menuType: SettingMenuTypes = .none) {
        
        activeMenuType          = menuType
        activeSubviewController = viewController
        activeSubview           = activeSubviewController.view
        
        self.bounds.size.height = activeSubview.bounds.height
        
        switch activeMenuType {
        case .cameraSliderMenu:
            self.contentView.addSubview(activeSubview!)
            break
        case .resolutionMenu:
            self.contentView.addSubview(activeSubview!)
        default:
            break
        }
    }
    
    func unsetActiveMenu() {
        
        switch activeMenuType {
        case .cameraSliderMenu:
            (activeSubviewController as! CameraOptionsViewController).unsetActiveslider()
            break
        case .resolutionMenu:
            //todo
            break
        default:
            break
        }
        
        if (activeSubview != nil) {
            activeSubview.removeFromSuperview()
            activeMenuType          = .none
            activeSubview           = nil
            activeSubviewController = nil
        }
    }
    
    func setCameraSliderViewControllerForIndex(_ index:Int, callbackToOpenMenu: () -> Void){
        var activeSliderPresent: Bool = false
        
            switch index {
                
            case 0:
                (self.activeSubviewController as! CameraOptionsViewController).setActiveSlider(CameraOptionsTypes.focus)
                activeSliderPresent = true
                break
            case 1:
                (self.activeSubviewController as! CameraOptionsViewController).setActiveSlider(CameraOptionsTypes.shutter)
                activeSliderPresent = true
                break
            case 2:
                (self.activeSubviewController as! CameraOptionsViewController).setActiveSlider(CameraOptionsTypes.iso)
                activeSliderPresent = true
                break
            case 3:
                (self.activeSubviewController as! CameraOptionsViewController).setActiveSlider(CameraOptionsTypes.temperature)
                activeSliderPresent = true
                break
            default:
                unsetActiveMenu()
                break
            }
        
        if (activeSliderPresent) {
            callbackToOpenMenu()
        }
    }
}
