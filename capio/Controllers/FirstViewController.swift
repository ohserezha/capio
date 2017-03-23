//
//  FirstViewController.swift
//  capio
//
//  Created by Roman on 7/10/16.
//  Copyright © 2016 theroman. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation
import CoreMotion

import JQSwiftIcon

import Photos

import ScalePicker
import CariocaMenu

enum SettingMenuTypes {
    case none, cameraSliderMenu, resolutionMenu, flashMenu, allStatsMenu, miscMenu
}

class Singleton {

    //MARK: Shared Instance

    static let sharedInstance : Singleton = {
        let instance = Singleton()
        return instance
    }()

    //MARK: Local Variable

    var emptyStringArray : [String]? = nil

    //MARK: Init

    convenience init() {
        self.init(array : [])
    }

    //MARK: Init Array

    init( array : [String]) {
        emptyStringArray = array
    }
}

class FirstViewController:
    UIViewController,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    UIGestureRecognizerDelegate,
    CariocaMenuDelegate {

    let VIDEO_RECORD_INTERVAL_COUNTDOWN:        Double = 1

    @IBOutlet var myCamView:                    UIView!
    @IBOutlet var doPhotoBtn:                   UIButton!
    @IBOutlet var doVideoBtn:                   UIButton!
    @IBOutlet var actionToolbar:                UIToolbar!
    @IBOutlet var menuHostView:                 MenuHostView!
    @IBOutlet var FPSLabel:                     UILabel!
    @IBOutlet var videoCounterLabel:            UILabel!
    @IBOutlet var videoRecordIndicator:         UIImageView!
    @IBOutlet var resolutionHostBlurView:       SharedBlurView!
    @IBOutlet var enablePermsView:              SharedBlurView!
    @IBOutlet var gridHostView:                 UIView!

    var captureSessionManager:                  CaptureSessionManager! = CaptureSessionManager.sharedInstance

    var logging:                                Bool = true

    private var videoRecordCountdownSeconds:    Double = 0.0
    private var videRecordCountdownTimer:       Timer!

    private var optionsMenu:                    CariocaMenu?
    private var cariocaMenuViewController:      CameraMenuContentController?

    //menu controllers here
    private var cameraOptionsViewController:    CameraOptionsViewController?
    private var cameraSecondaryOptions:         RightMenuSetViewController?
    private var cameraResolutionSideMenu:       ResolutionSideMenuViewController?
    private var cameraResolutionMenu:           ResolutionViewController?

    private var focusZoomView:                  FocusZoomViewController?

    private var gridManager:                    GridManager!

    //flag that determines if a user gave all required perms: photo library, video, microphone
    private var isAppUsable:                    Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        addCoreObservers()
        processUi()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        onDispose()
        exit(0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        optionsMenu?.addInView(self.view)
        if isAppUsable {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: {_ in
                self.optionsMenu?.showIndicator(.right, position: .bottom, offset: -50)
            })
            
        } else {
            optionsMenu?.showIndicator(.right, position: .bottom, offset: 50)
        }

        gridManager = GridManager.init(_gridView: gridHostView, _storyBoard: self.storyboard!, _parentViewDimentions: gridHostView.bounds)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }  

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }    

    /////////////////// Carioca Menu Overrides START

    func cariocaMenuDidSelect(_ menu:CariocaMenu, indexPath:IndexPath) {
        cariocaMenuViewController?.menuWillClose()

        hideActiveSetting() {_ in
            print("Done hiding from show")

            //todo -> switchcase for misc menu
            self.menuHostView.setActiveMenu(self.cameraOptionsViewController!, menuType: .cameraSliderMenu)

            self.menuHostView.setCameraSliderViewControllerForIndex(indexPath.row, callbackToOpenMenu: self.showActiveSetting)
            self.optionsMenu?.moveToTop()
        }
    }

    func cariocaMenuWillOpen(_ menu:CariocaMenu) {
        cariocaMenuViewController?.menuWillOpen()
        if logging {
            print("carioca MenuWillOpen \(menu)")
        }
    }

    func cariocaMenuDidOpen(_ menu:CariocaMenu){
        if logging {
            switch menu.openingEdge{
            case .left:
                print("carioca MenuDidOpen \(menu) left")
                break;
            default:
                print("carioca MenuDidOpen \(menu) right")
                break;
            }
        }
    }

    func cariocaMenuWillClose(_ menu:CariocaMenu) {
        cariocaMenuViewController?.menuWillClose()
        if logging {
            print("carioca MenuWillClose \(menu)")
        }
    }

    func cariocaMenuDidClose(_ menu:CariocaMenu){
        if logging {
            print("carioca MenuDidClose \(menu)")
        }
    }
    /////////////////// Carioca Menu Overrides END

    @IBAction func onDoPhotoTrigger(_ sender: AnyObject) {
        captureImage()
    }

    @IBAction func onDoVideo(_ sender: UIButton) {
        startStopRecording()
    }

    func captureImage() {
        if isAppUsable {
            if cameraSecondaryOptions?.timerScale != TimerScales.off  {
                if (cameraSecondaryOptions?.timerState != TimerStates.ticking) {
                    doPhotoBtn.isEnabled = false
                    doPhotoBtn.alpha = 0.4
                    cameraSecondaryOptions?.startTimerTick {
                        self.doPhotoBtn.isEnabled = true
                        self.doPhotoBtn.alpha = 1
                        self.captureSessionManager.captureImage()
                    }
                }
            } else {
                doPhotoBtn.alpha = 1
                doPhotoBtn.isEnabled = true
                self.captureSessionManager.captureImage()
            }
        }
    }

    func startStopRecording() {
        if isAppUsable {
            self.captureSessionManager.startStopRecording()
        }
    }

    func onAppBackgroundStateEnter() {
        onDispose()
    }

    func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if isAppUsable {
            var point: CGPoint = gestureRecognizer.location(in: gestureRecognizer.view)

            if (gestureRecognizer.state == .began) {
                if(self.focusZoomView == nil) {
                    self.focusZoomView = self.storyboard?.instantiateViewController(withIdentifier: "FocusZoomView") as? FocusZoomViewController
                }

                self.focusZoomView?.resetView()

                gestureRecognizer.view?.addSubview((self.focusZoomView?.view)!)

                self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)

                self.focusZoomView?.appear()
            }

            if (gestureRecognizer.state == .changed) {
                self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)
            }

            if (gestureRecognizer.state == .ended) {
                let centerDelta: CGFloat = 100.0
                if (point.x <= (gestureRecognizer.view?.bounds.width)!/2 + centerDelta &&
                    point.x >= (gestureRecognizer.view?.bounds.width)!/2 - centerDelta &&
                    point.y <= (gestureRecognizer.view?.bounds.height)!/2 + centerDelta &&
                    point.y >= (gestureRecognizer.view?.bounds.height)!/2 - centerDelta ) {

                    point = CGPoint.init(x: (gestureRecognizer.view?.bounds.width)!/2, y: (gestureRecognizer.view?.bounds.height)!/2)

                    self.focusZoomView?.disolveToRemove()
                } else {
                    self.focusZoomView?.disolve()
                }

                self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)

                self.captureSessionManager.setPointOfInterest(point)
            }
        }
    }

    func handlerCamViewTap(_ gestureRecognizer: UIGestureRecognizer) {
        if isAppUsable {
            if (menuHostView != nil && menuHostView.activeMenuType != .none) {
                if (menuHostView.activeMenuType == .cameraSliderMenu) {
                    cariocaMenuViewController?.menuToDefault()
                }
                hideActiveSetting() {_ in
                    print("Done hiding from tap")
                }
            } else {
                if(self.focusZoomView == nil) {
                    self.focusZoomView = self.storyboard?.instantiateViewController(withIdentifier: "FocusZoomView") as? FocusZoomViewController
                }

                self.focusZoomView?.resetView()

                gestureRecognizer.view?.addSubview((self.focusZoomView?.view)!)
                var point: CGPoint = gestureRecognizer.location(in: gestureRecognizer.view)
                let centerDelta: CGFloat = 100.0
                if (point.x <= (gestureRecognizer.view?.bounds.width)!/2 + centerDelta &&
                    point.x >= (gestureRecognizer.view?.bounds.width)!/2 - centerDelta &&
                    point.y <= (gestureRecognizer.view?.bounds.height)!/2 + centerDelta &&
                    point.y >= (gestureRecognizer.view?.bounds.height)!/2 - centerDelta ) {

                    point = CGPoint.init(x: (gestureRecognizer.view?.bounds.width)!/2, y: (gestureRecognizer.view?.bounds.height)!/2)

                    self.focusZoomView?.disolveToRemove()
                } else {
                    self.focusZoomView?.disolve()
                }

                self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)

                self.captureSessionManager.setPointOfInterest(point)
            }
        }
    }

    open func onShowResOptions() {
        if isAppUsable {
            if (menuHostView.activeMenuType != .resolutionMenu) {
                if (menuHostView.activeMenuType == .cameraSliderMenu) {
                    cariocaMenuViewController?.menuToDefault()
                }
                
                hideActiveSetting() { _ in
                    if(self.cameraResolutionMenu == nil) {
                        self.cameraResolutionMenu = self.storyboard?.instantiateViewController(withIdentifier: "CameraResolutionMenu") as? ResolutionViewController
                    }
                    
                    self.menuHostView.setActiveMenu(self.cameraResolutionMenu!, menuType: .resolutionMenu)
                    
                    self.showActiveSetting()
                }
            }
        }
    }

    func requestPhotoVideoAudioPerms() {
        let videoAuthState      = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        let audioAuthState      = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
        let libraryAuthState    = PHPhotoLibrary.authorizationStatus()
        var isVideoEnabled          = videoAuthState ==  AVAuthorizationStatus.authorized
        var isAudioEnabled          = audioAuthState ==  AVAuthorizationStatus.authorized
        var isPhotoLibraryEnabled   = libraryAuthState == PHAuthorizationStatus.authorized

        if  !isAudioEnabled {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: { (granted :Bool) -> Void in
                isAudioEnabled = granted
                if !isVideoEnabled {
                    AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                        isVideoEnabled = granted

                        if (!isPhotoLibraryEnabled) {
                            PHPhotoLibrary.requestAuthorization({ (authorizationStatus: PHAuthorizationStatus) -> Void in
                                isPhotoLibraryEnabled = authorizationStatus == PHAuthorizationStatus.authorized
                                self.isAppUsable = isVideoEnabled && isAudioEnabled && isPhotoLibraryEnabled
                            })
                        }
                    });
                }
            });
        }
        isAppUsable = isVideoEnabled && isAudioEnabled && isPhotoLibraryEnabled
        if (isAppUsable) {

            self.captureSessionManager.resetCaptureSession(camView: myCamView)

            enableUi()
        } else {
            let areAnyStatesNotDetermined = videoAuthState == AVAuthorizationStatus.notDetermined ||
                audioAuthState == AVAuthorizationStatus.notDetermined ||
                libraryAuthState == PHAuthorizationStatus.notDetermined
            disableUi(areAnyStatesNotDetermined)
        }
    }

    func startStopVideoCounter(start: Bool) {
        if start {
            //video countdown counter starts here
            
            UIView.animate(withDuration: self.VIDEO_RECORD_INTERVAL_COUNTDOWN/2, delay: 0, options: .curveEaseOut, animations: {
                self.videoRecordIndicator.alpha = 0.5
                self.videoCounterLabel.alpha = 1.0
                self.videoCounterLabel.text = String(format: "%02d:%02d:%02d", 0.0, 0.0, 0.0)
            }) { success in

                if (self.videRecordCountdownTimer != nil) {
                    self.videRecordCountdownTimer.invalidate()
                }

                self.videRecordCountdownTimer = Timer.scheduledTimer(withTimeInterval: self.VIDEO_RECORD_INTERVAL_COUNTDOWN/2, repeats: true, block: {timer in
                    let videoRecordCountdownSeconds = (self.captureSessionManager.captureVideoOut?.recordedDuration.seconds)!

                    let seconds: Int = Int(videoRecordCountdownSeconds) % 60
                    let minutes: Int = Int((videoRecordCountdownSeconds / 60)) % 60
                    let hours: Int = Int(videoRecordCountdownSeconds) / 3600

                    DispatchQueue.main.async {
                        self.videoCounterLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                    }

                    UIView.animate(withDuration: self.VIDEO_RECORD_INTERVAL_COUNTDOWN/3, delay: 0, options: .curveEaseOut, animations: {
                        self.videoRecordIndicator.alpha = self.videoRecordIndicator.alpha == 0.5 ? 0.1 : 0.5
                    })
                })
            }
        } else {
                videRecordCountdownTimer.invalidate()
                videRecordCountdownTimer = nil

                UIView.animate(withDuration: self.VIDEO_RECORD_INTERVAL_COUNTDOWN/2, delay: 0, options: .curveEaseOut, animations: {
                    self.videoRecordIndicator.alpha = 0.0
                    self.videoRecordCountdownSeconds = 0.0
                    self.videoCounterLabel.alpha = 0.0

                }) { (success:Bool) in
                    DispatchQueue.main.async {
                    self.videoCounterLabel.text = String()
                }
            }
        }
    }

    private func onDispose() {
        self.captureSessionManager.onSessionDispose()

        if let layers = myCamView.layer.sublayers as [CALayer]? {
            for layer in layers  {
                layer.removeFromSuperlayer()
            }
        }
    }

    private func addCoreObservers() {

        //each time you spawn application back -> this observer gonna be triggered
        NotificationCenter.default.addObserver(self, selector: #selector(FirstViewController.requestPhotoVideoAudioPerms), name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(FirstViewController.onAppBackgroundStateEnter), name: .UIApplicationDidEnterBackground, object: nil)

        captureSessionManager.cameraSettingsObservable.subscribe(onNext: { (newCameraSettings: CameraSessionSettings) in
            let isFlashAvailable = newCameraSettings.isFlashAvailable

            if self.cameraSecondaryOptions != nil {
                if  isFlashAvailable &&
                    self.captureSessionManager.recodringState != RecordingStates.on {

                    self.cameraSecondaryOptions?.isFlashAvailable = true
                    self.captureSessionManager.flashModeState = (self.cameraSecondaryOptions?.flashModeState)!
                } else {
                    self.cameraSecondaryOptions?.isFlashAvailable = false
                    self.captureSessionManager.flashModeState = AVCaptureFlashMode.off
                }

                let recordingState = newCameraSettings.recordingState
                switch recordingState {
                    case RecordingStates.on:
                        self.doVideoBtn.titleLabel?.textColor = UIColor.red

                        self.cameraSecondaryOptions?.isOrientationSwitchEnabled = false
                        self.cameraSecondaryOptions?.isFlashAvailable = false
                        self.captureSessionManager.flashModeState = AVCaptureFlashMode.off

                        if (self.videRecordCountdownTimer == nil) {
                            self.startStopVideoCounter(start: true)
                        }

                    case RecordingStates.off:
                        self.doVideoBtn.titleLabel?.textColor = UIColor.white

                        self.cameraSecondaryOptions?.isOrientationSwitchEnabled = true
                        self.cameraSecondaryOptions?.isFlashAvailable = true
                        self.captureSessionManager.flashModeState = (self.cameraSecondaryOptions?.flashModeState)!

                        if (self.videRecordCountdownTimer != nil) {
                            self.startStopVideoCounter(start: false)
                        }
                }
            }
        })
    }

    private func processUi() {
        //TODO: re-factor the method! it's too damn big
        
        let camViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.handlerCamViewTap))
        camViewTapRecognizer.numberOfTapsRequired = 1
        camViewTapRecognizer.numberOfTouchesRequired = 1

        let camViewDoubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.captureImage))
        camViewDoubleTapRecognizer.numberOfTapsRequired = 2
        camViewDoubleTapRecognizer.numberOfTouchesRequired = 1

        let camViewTrippleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.startStopRecording))

        camViewTrippleTapRecognizer.numberOfTapsRequired = 3
        camViewTrippleTapRecognizer.numberOfTouchesRequired = 1

        let camViewLongTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(FirstViewController.handleLongPress))

        myCamView.addGestureRecognizer(camViewTapRecognizer)
        myCamView.addGestureRecognizer(camViewDoubleTapRecognizer)
        myCamView.addGestureRecognizer(camViewTrippleTapRecognizer)
        myCamView.addGestureRecognizer(camViewLongTapRecognizer)

        //setting gesture priorities
        camViewTapRecognizer.require(toFail: camViewDoubleTapRecognizer)
        camViewTapRecognizer.require(toFail: camViewTrippleTapRecognizer)
        camViewDoubleTapRecognizer.require(toFail: camViewTrippleTapRecognizer)

        //todo: all settings processing should be moved in to a single unit
        cameraOptionsViewController = self.storyboard?.instantiateViewController(withIdentifier: "CameraOptionsSlider") as? CameraOptionsViewController

        setupCameraSettingsSwipeMenu()

        cameraSecondaryOptions = self.storyboard?.instantiateViewController(withIdentifier: "RightMenuViewController") as? RightMenuSetViewController

        view.addSubview((cameraSecondaryOptions?.view)!)

        cameraSecondaryOptions?.view.transform = CGAffineTransform.init(translationX: view.bounds.width-(cameraSecondaryOptions?.view.bounds.width)! + 5, y: view.bounds.height - (cameraSecondaryOptions?.view.bounds.height)! - 100)
        
        cameraResolutionSideMenu = self.storyboard?.instantiateViewController(withIdentifier: "ResolutionSideMenuViewController") as? ResolutionSideMenuViewController
        
        view.addSubview((cameraResolutionSideMenu?.view)!)

        cameraResolutionSideMenu?.view.transform = CGAffineTransform.init(translationX: -2, y: view.bounds.height - (cameraResolutionSideMenu?.view.bounds.height)! - 56)
        
        cameraResolutionSideMenu?.setTouchEndCb(cb: onShowResOptions)

        self.cameraSecondaryOptions?.addObserver(self, forKeyPath: "orientationRawState", options: NSKeyValueObservingOptions.new, context: nil)
        self.cameraSecondaryOptions?.addObserver(self, forKeyPath: "gridRawState", options: NSKeyValueObservingOptions.new, context: nil)
        self.cameraSecondaryOptions?.addObserver(self, forKeyPath: "flashModeRawState", options: NSKeyValueObservingOptions.new, context: nil)

        doPhotoBtn.processIcons();
        doVideoBtn.processIcons();
    }

    private func enableUi() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.doPhotoBtn.isEnabled = true
            self.doPhotoBtn.alpha = 1
            self.doVideoBtn.isEnabled = true
            self.doVideoBtn.alpha = 1
            self.cameraSecondaryOptions?.view.isHidden = false
            self.cameraResolutionSideMenu?.view.isHidden = false
            self.enablePermsView.isHidden = true

            if (self.optionsMenu?.hostView != nil) {
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false, block: {_ in
                    self.optionsMenu?.showIndicator(.right, position: .bottom, offset: -50)
                })
            }
            
            //todo -> reload UI method
            self.cameraResolutionSideMenu?.resModePicker.reloadComponent(0)
        })
    }

    private func disableUi(_ areAnyStatesNotDetermined: Bool = false) {
        doPhotoBtn.isEnabled = false
        doPhotoBtn.alpha = 0.4
        doVideoBtn.isEnabled = false
        doVideoBtn.alpha = 0.4
        cameraSecondaryOptions?.view.isHidden = true
        cameraResolutionSideMenu?.view.isHidden = true
        if (!areAnyStatesNotDetermined) {
            enablePermsView.isHidden = false
        }
        hideActiveSetting { (AnyObject) in
            print("done hiding")
        }
        if (optionsMenu?.hostView != nil) {
            optionsMenu?.showIndicator(.right, position: .bottom, offset: 50)
        }
    }

    private func setupCameraSettingsSwipeMenu() {
        cariocaMenuViewController = self.storyboard?.instantiateViewController(withIdentifier: "CameraMenu") as? CameraMenuContentController

        //Set the tableviewcontroller for the shared carioca menu
        optionsMenu = CariocaMenu(dataSource: cariocaMenuViewController!)
        optionsMenu?.selectedIndexPath = IndexPath(item: 0, section: 0)

        optionsMenu?.delegate = self
        optionsMenu?.boomerang = .verticalAndHorizontal

        optionsMenu?.selectedIndexPath = IndexPath(row: (cariocaMenuViewController?.iconNames.count)! - 1, section: 0)

        //reverse delegate for cell selection by tap :
        cariocaMenuViewController?.cariocaMenu = optionsMenu
    }

    private func showActiveSetting() {
        if isAppUsable {
            menuHostView.center.x = self.view.center.x

            var tBefore = CGAffineTransform.identity
            tBefore = tBefore.translatedBy(x: 0, y: self.view.bounds.height/2 + self.menuHostView.bounds.height + self.actionToolbar.bounds.height)
            tBefore = tBefore.scaledBy(x: 0.6, y: 1)
            
            menuHostView.transform = tBefore
            
            menuHostView.isHidden = false

            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                var tAfter = CGAffineTransform.identity
                tAfter = tAfter.translatedBy(x: 0, y: self.view.bounds.height/2 - self.menuHostView.bounds.height - self.actionToolbar.bounds.height/2)
                tAfter = tAfter.scaledBy(x: 1, y: 1)
                
                self.menuHostView.transform = tAfter
            })
        }
    }

    private func hideActiveSetting(_ completion: @escaping (_ result: AnyObject) -> Void) {
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            
            var t = CGAffineTransform.identity
            t = t.translatedBy(x: 0, y: self.view.bounds.height/2 + self.menuHostView.bounds.height + self.actionToolbar.bounds.height)
            t = t.scaledBy(x: 1.4, y: 1)
            
            self.menuHostView.transform = t
        }) { (success:Bool) in
            self.menuHostView.isHidden = true

            self.menuHostView.unsetActiveMenu()
            completion(success as AnyObject)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let _keyPath: String = keyPath == nil ? "" : keyPath!

        switch _keyPath {
            case "orientationRawState":
                self.captureSessionManager.onLockUnLockOrientation((self.cameraSecondaryOptions?.orientationState)! as OrientationStates)
            case "gridRawState":
                switch (self.cameraSecondaryOptions?.gridState)! as GridFactors {
                case .off:
                    gridManager.gridFactor = .off
                case .double:
                    gridManager.gridFactor = .double
                case .quad:
                    gridManager.gridFactor = .quad
                }
            case "flashModeRawState":
                captureSessionManager.flashModeState = (cameraSecondaryOptions?.flashModeState)!

            default:
                break
        }

    }
}

class SharedBlurView: UIVisualEffectView {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layer.masksToBounds    = true
        self.layer.cornerRadius     = 5
    }    
}

class SharedButtonView: UIButton {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                    self.transform = CGAffineTransform.init(scaleX: 0.9, y: 0.9)
                    self.transform = CGAffineTransform.init(translationX: 2, y: 0)
                    self.alpha = 0.5
                })
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        DispatchQueue.global(qos: .userInteractive).async {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                    self.transform = CGAffineTransform.init(scaleX: 1, y: 1)
                    self.transform = CGAffineTransform.init(translationX: -2, y: 0)
                    self.alpha = 1
                })
            }
        }
    }
}
