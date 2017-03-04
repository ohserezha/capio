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

import BRYXBanner
import JQSwiftIcon

import Photos

import ScalePicker
import CariocaMenu

enum SettingMenuTypes {
    case none, cameraSliderMenu, resolutionMenu, flashMenu, allStatsMenu, miscMenu
}

class FirstViewController:
    UIViewController,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    AVCaptureFileOutputRecordingDelegate,
    AVCapturePhotoCaptureDelegate,
    UIGestureRecognizerDelegate,
    CariocaMenuDelegate,
    UIPickerViewDelegate,
    UIPickerViewDataSource,
    AVCaptureAudioDataOutputSampleBufferDelegate {

    let SUPPORTED_ASPECT_RATIO:                 Double = 1280/720
    let VIDEO_RECORD_INTERVAL_COUNTDOWN:        Double = 1

    var captureSession:                         AVCaptureSession?
    var captureStillImageOut:                   AVCapturePhotoOutput?
    var captureVideoOut:                        AVCaptureMovieFileOutput?
    var previewLayer:                           AVCaptureVideoPreviewLayer?

    var audioSession:                           AVAudioSession?

    var captureDevice :                         AVCaptureDevice?

    var flashLightMode:                         String!

    var logging:                                Bool = true

    @IBOutlet var myCamView:                    UIView!
    @IBOutlet var doPhotoBtn:                   UIButton!
    @IBOutlet var doVideoBtn:                   UIButton!

    @IBOutlet var actionToolbar:                UIToolbar!

    @IBOutlet var menuHostView:                 MenuHostView!

    @IBOutlet var resolutionBlurView:           UIVisualEffectView!
    @IBOutlet var FPSLabel:                     UILabel!
    @IBOutlet var sloMoIndicatorLabel:          UILabel!
    @IBOutlet var resolutionChangeBtn:          UIButton!

    @IBOutlet var videoCounterLabel:            UILabel!
    @IBOutlet var videoRecordIndicator:         UIImageView!

    private var videoRecordCountdownSeconds:    Double = 0.0
    private var videRecordCountdownTimer:       Timer!

    @IBOutlet var resModePicker:                UIPickerView!
    private var optionsMenu:                    CariocaMenuOverride?
    private var cariocaMenuViewController:      CameraMenuContentController?

    @IBOutlet var resolutionHostBlurView:       SharedBlurView!
    @IBOutlet var enablePermsView:              SharedBlurView!
    //menu controllers here
    private var cameraOptionsViewController:    CameraOptionsViewController?
    private var cameraSecondaryOptions:         RightMenuSetViewController?
    private var cameraResolutionMenu:           ResolutionViewController?

    private var focusZoomView:                  FocusZoomViewController?

    private var motionManager:                  CMMotionManager!

    private var resolutionFormatsArray: [ResolutionFormat] = [ResolutionFormat]()
    private var activeResolutionFormat: ResolutionFormat!

    @IBOutlet var gridHostView:                 UIView!
    private var gridManager:                    GridManager!

    //flag that determines if a user gave all required perms: photo library, video, microphone
    private var isAppUsable:                    Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setCaptureSession()
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
        previewLayer?.frame = myCamView.bounds


        optionsMenu?.addInView(self.view)
        if isAppUsable {
            optionsMenu?.showIndicator(.right, position: .bottom, offset: -50)
        } else {
            optionsMenu?.showIndicator(.right, position: .bottom, offset: 50)
        }

        gridManager = GridManager.init(_gridView: gridHostView, _storyBoard: self.storyboard!, _parentViewDimentions: gridHostView.bounds)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return resolutionFormatsArray.count
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        setResolution(resolutionFormatsArray[row])
        self.cameraResolutionMenu?.activeResolutionFormat = self.activeResolutionFormat
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 80
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {

        var pickerCell = view as! ResPickerView!
        if pickerCell == nil {
            pickerCell = ResPickerView.init(frame: CGRect.init(x: 0, y: 0, width: 50, height: 80),
                _name: resolutionFormatsArray[row].name,
                _fps: String(resolutionFormatsArray[row].fpsRange.maxFrameRate),
                _isSlomo: resolutionFormatsArray[row].isSlomo
            )
        }

        return pickerCell!
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
        if(logging){
            print("carioca MenuWillOpen \(menu)")
        }
    }

    func cariocaMenuDidOpen(_ menu:CariocaMenu){
        if(logging){
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
        if(logging){
            print("carioca MenuWillClose \(menu)")
        }
    }

    func cariocaMenuDidClose(_ menu:CariocaMenu){
        if(logging){
            print("carioca MenuDidClose \(menu)")
        }
    }
    /////////////////// Carioca Menu Overrides END

    @IBAction func onDoPhotoTrigger(_ sender: AnyObject) {
        captureImage()
    }

    @IBAction func onResolutionButtonTrigger(_ sender: UIButton) {
        onShowResOptions()
    }

    @IBAction func onDoVideo(_ sender: UIButton) {
        startStopRecording()
    }

    private func onDispose() {
        captureSession?.stopRunning()
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
        if let layers = myCamView.layer.sublayers as [CALayer]? {
            for layer in layers  {
                layer.removeFromSuperlayer()
            }
        }

        do {
            try audioSession?.setActive(false)
        } catch {
            print(error)
        }
    }

    private func processUi() {

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
        cameraOptionsViewController?.setActiveDevice(captureDevice!)

        setupCameraSettingsSwipeMenu()

        resModePicker.dataSource = self
        resModePicker.delegate = self

        let resTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.onShowResOptions))
        resTapRecognizer.numberOfTapsRequired = 1
        resTapRecognizer.numberOfTouchesRequired = 1
        resTapRecognizer.delegate = self

        resModePicker.addGestureRecognizer(resTapRecognizer)

        cameraSecondaryOptions = self.storyboard?.instantiateViewController(withIdentifier: "RightMenuViewController") as? RightMenuSetViewController

        if !(captureDevice?.isFlashAvailable)! {
            cameraSecondaryOptions?.isFlashAvailable = false
        } else {
            cameraSecondaryOptions?.isFlashAvailable = true
        }

        view.addSubview((cameraSecondaryOptions?.view)!)

        cameraSecondaryOptions?.view.transform = CGAffineTransform.init(translationX: view.bounds.width-(cameraSecondaryOptions?.view.bounds.width)! + 5, y: view.bounds.height - (cameraSecondaryOptions?.view.bounds.height)! - 100)

        self.cameraSecondaryOptions?.addObserver(self, forKeyPath: "orientationRawState", options: NSKeyValueObservingOptions.new, context: nil)
        self.cameraSecondaryOptions?.addObserver(self, forKeyPath: "gridRawState", options: NSKeyValueObservingOptions.new, context: nil)

        doPhotoBtn.processIcons();
        doVideoBtn.processIcons();
    }

    private func setupCameraSettingsSwipeMenu() {
        cariocaMenuViewController = self.storyboard?.instantiateViewController(withIdentifier: "CameraMenu") as? CameraMenuContentController

        //Set the tableviewcontroller for the shared carioca menu
        optionsMenu = CariocaMenuOverride(dataSource: cariocaMenuViewController!)
        optionsMenu?.selectedIndexPath = IndexPath(item: 0, section: 0)

        optionsMenu?.delegate = self
        optionsMenu?.boomerang = .verticalAndHorizontal

        optionsMenu?.selectedIndexPath = IndexPath(row: (cariocaMenuViewController?.iconNames.count)! - 1, section: 0)

        //reverse delegate for cell selection by tap :
        cariocaMenuViewController?.cariocaMenu = optionsMenu
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

                setPointOfInterest(point)
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

                setPointOfInterest(point)
            }
        }
    }

    private func setPointOfInterest(_ point: CGPoint) {
        let focusPoint = CGPoint(x: point.y / myCamView.bounds.height, y: 1.0 - point.x / myCamView.bounds.width)

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

    private func showActiveSetting() {
        if isAppUsable {
            menuHostView.center.x = self.view.center.x

            menuHostView.transform = CGAffineTransform.init(translationX: 0, y: view.bounds.height/2 + self.menuHostView.bounds.height + self.actionToolbar.bounds.height
            )
            menuHostView.isHidden = false

            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                self.menuHostView.transform = CGAffineTransform.init(translationX: 0, y:
                    self.view.bounds.height/2 - self.menuHostView.bounds.height - self.actionToolbar.bounds.height/2
                )
            })
        }
    }

    private func hideActiveSetting(_ completion: @escaping (_ result: AnyObject) -> Void) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.menuHostView.transform = CGAffineTransform.init(translationX: 0, y: self.view.bounds.height/2 + self.menuHostView.bounds.height + self.actionToolbar.bounds.height
            )
        }) { (success:Bool) in
            self.menuHostView.isHidden = true

            if(self.menuHostView.activeMenuType == .resolutionMenu) {
                do {
                    try self.cameraResolutionMenu?.removeObserver(self, forKeyPath: "selectedRowIndex")
                } catch {
                    print("[hideActiveSetting] " + String(error.localizedDescription))
                }

            }

            self.menuHostView.unsetActiveMenu()
            completion(success as AnyObject)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "selectedRowIndex"{
            let row = change?[NSKeyValueChangeKey.newKey] as! Int
            if (activeResolutionFormat != self.resolutionFormatsArray[row]) {
                self.resModePicker.selectRow(row, inComponent: 0, animated: true)
                self.setResolution(self.resolutionFormatsArray[row])
            }
        }
        if keyPath == "orientationRawState" {
            switch (self.cameraSecondaryOptions?.orientationState)! as OrientationStates {
                case .landscapeLocked:
                    self.setPreviewLayerOrientation(UIInterfaceOrientation.landscapeLeft)
                case .portraitLocked:
                    self.setPreviewLayerOrientation(UIInterfaceOrientation.portrait)
                default:
                    break
            }
        }
        if keyPath == "gridRawState" {
            switch (self.cameraSecondaryOptions?.gridState)! as GridFactors {
            case .off:
                gridManager.gridFactor = .off
            case .double:
                gridManager.gridFactor = .double
            case .quad:
                gridManager.gridFactor = .quad
            default:
                break
            }
        }
    }

    open func onShowResOptions() {
        AudioServicesPlaySystemSound(1519)
        if isAppUsable {
        if (menuHostView.activeMenuType == .cameraSliderMenu) {
            cariocaMenuViewController?.menuToDefault()
        }

        hideActiveSetting() { _ in
            if(self.cameraResolutionMenu == nil) {
                self.cameraResolutionMenu = self.storyboard?.instantiateViewController(withIdentifier: "CameraResolutionMenu") as? ResolutionViewController
            }

            self.cameraResolutionMenu?.resolutionFormatsArray = self.resolutionFormatsArray

            self.menuHostView.setActiveMenu(self.cameraResolutionMenu!, menuType: .resolutionMenu)

            self.cameraResolutionMenu?.activeResolutionFormat = self.activeResolutionFormat

            self.showActiveSetting()

            //todo -> figureout a better way of propagating back to parent
            self.cameraResolutionMenu?.addObserver(self, forKeyPath: "selectedRowIndex", options: NSKeyValueObservingOptions.new, context: nil)
        }
        }
    }

    private func setCaptureSession() {

        captureSession = AVCaptureSession()
        // in case you have music plaing in your phone
        // it will not get muted thanks to that AND! setAudioSession
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        // todo -> write getter for Preset (device based)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080

        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)

        //each time you spawn application back -> this observer gonna be triggered
        NotificationCenter.default.addObserver(self, selector: #selector(FirstViewController.requestPhotoVideoAudioPerms), name: .UIApplicationDidBecomeActive, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(FirstViewController.onBackgroundEnter), name: .UIApplicationDidEnterBackground, object: nil)
    }

    func onBackgroundEnter() {
        onDispose()
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

            self.setAudioSession()
            self.startCaptureSession()

            self.initMotionManager()

            enableUi()
        } else {
            let areAnyStatesNotDetermined = videoAuthState == AVAuthorizationStatus.notDetermined ||
                audioAuthState == AVAuthorizationStatus.notDetermined ||
                libraryAuthState == PHAuthorizationStatus.notDetermined
            disableUi(areAnyStatesNotDetermined)
        }

    }

    private func enableUi() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.doPhotoBtn.isEnabled = true
            self.doPhotoBtn.alpha = 1
            self.doVideoBtn.isEnabled = true
            self.doVideoBtn.alpha = 1
            self.cameraSecondaryOptions?.view.isHidden = false
            self.resolutionHostBlurView?.isHidden = false
            self.enablePermsView.isHidden = true
            if (self.optionsMenu?.hostView != nil) {
                self.optionsMenu?.showIndicator(.right, position: .bottom, offset: -50)
            }

            self.resModePicker.reloadComponent(0)
        })
    }

    private func disableUi(_ areAnyStatesNotDetermined: Bool = false) {
        doPhotoBtn.isEnabled = false
        doPhotoBtn.alpha = 0.4
        doVideoBtn.isEnabled = false
        doVideoBtn.alpha = 0.4
        cameraSecondaryOptions?.view.isHidden = true
        resolutionHostBlurView?.isHidden = true
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

    private func initMotionManager() {

        motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.2

        motionManager.startAccelerometerUpdates()
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { (timer) in
                if let accelerometerData = self.motionManager.accelerometerData {
                    self.onAccelerationData(accelerometerData.acceleration)
            }
        }
    }

    private var currentOrientation: UIInterfaceOrientation!
    private var currentPreviewLayerOrientation: AVCaptureVideoOrientation!

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
                if (cameraSecondaryOptions?.orientationState != OrientationStates.portraitLocked) {
                    currentPreviewLayerOrientation = AVCaptureVideoOrientation.landscapeLeft
                }
                break
            case .landscapeRight:
                if (cameraSecondaryOptions?.orientationState != OrientationStates.portraitLocked) {
                    currentPreviewLayerOrientation = AVCaptureVideoOrientation.landscapeRight
                }
                break
            case .portrait:
                if (cameraSecondaryOptions?.orientationState != OrientationStates.landscapeLocked) {
                    currentPreviewLayerOrientation = AVCaptureVideoOrientation.portrait
                }
                break
            case .portraitUpsideDown:
                if (cameraSecondaryOptions?.orientationState != OrientationStates.landscapeLocked) {
                    currentPreviewLayerOrientation = AVCaptureVideoOrientation.portraitUpsideDown
                }
                break

            default:
                break
            }

            self.captureVideoOut?.connection(withMediaType: AVMediaTypeVideo).videoOrientation = self.currentPreviewLayerOrientation
            self.captureStillImageOut?.connection(withMediaType: AVMediaTypeVideo).videoOrientation = self.currentPreviewLayerOrientation
        }
    }

    func setAudioSession() {
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

    private func startCaptureSession() {
        if !(captureSession?.isRunning)! {
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
                doPhotoBtn.isEnabled = false
                fatalError()
            }
            
            captureSession?.addOutput(captureStillImageOut)
            
            captureStillImageOut?.isHighResolutionCaptureEnabled = true
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
            previewLayer?.frame = myCamView.bounds
            
            myCamView.layer.addSublayer((previewLayer)!)
            

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
                doVideoBtn.isEnabled = false
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

            setResolution(resolutionFormatsArray.first!)
            captureSession?.startRunning()
        }
    }

    private func setResolution(_ newResolutionFormat: ResolutionFormat) {
        if (newResolutionFormat != activeResolutionFormat) {
            activeResolutionFormat = newResolutionFormat

            if (self.captureVideoOut?.isRecording)! {
                doVideoBtn.titleLabel?.textColor = UIColor.white
                self.stopRecording()
            }

            do {
                try self.captureDevice?.lockForConfiguration()
                self.captureDevice!.focusMode = .continuousAutoFocus
                self.captureDevice!.exposureMode = .continuousAutoExposure
                self.captureDevice!.whiteBalanceMode = .continuousAutoWhiteBalance
                self.cameraOptionsViewController?.isIsoLocked = false
                self.cameraOptionsViewController?.isShutterLocked = false

                self.captureDevice!.activeFormat = activeResolutionFormat.format
                self.captureDevice!.activeVideoMinFrameDuration = activeResolutionFormat.fpsRange.minFrameDuration
                self.captureDevice!.activeVideoMaxFrameDuration = activeResolutionFormat.fpsRange.maxFrameDuration

                self.captureDevice?.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
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
                    self._captureImage()
                }
            }
        } else {
            doPhotoBtn.alpha = 1
            doPhotoBtn.isEnabled = true
            _captureImage()
        }
        }
    }

    func _captureImage() {
        //currently any vibration won'e work due to "by design" bug on apple's side
        //https://github.com/lionheart/openradar-mirror/issues/5479
        //https://developer.apple.com/reference/audiotoolbox/1405202-audioservicesplayalertsound
        AudioServicesPlaySystemSound(1519)

        let settings = AVCapturePhotoSettings()

        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160,
                             ]

        if !(captureDevice?.isFlashAvailable)! || (captureVideoOut?.isRecording)! {
            //todo: do a better watching over captureDevice?.isFlashAvailable
            cameraSecondaryOptions?.isFlashAvailable = false
            settings.flashMode = AVCaptureFlashMode.off
        } else {
            cameraSecondaryOptions?.isFlashAvailable = true
            settings.flashMode = (cameraSecondaryOptions?.flashModeState)!
        }

        settings.previewPhotoFormat = previewFormat
        settings.isHighResolutionPhotoEnabled = true

        //todo: make a wait_promt here, cuz on higher resolution sampleBuffer might take pretty long
        // specifically on night images

        captureStillImageOut!.capturePhoto(with: settings, delegate: self)
    }

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
                                               #selector(FirstViewController.onImageSaved(_:didFinishSavingWithError:contextInfo:)),
                                               nil)
        } else {
            print("Error on saving the image")
        }
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

    func startStopVideoCounter() {
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
                let videoRecordCountdownSeconds = (self.captureVideoOut?.recordedDuration.seconds)!

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
    }

    func startStopRecording() {
        if isAppUsable {
            if (!(captureVideoOut?.isRecording)!) {
                doVideoBtn.titleLabel?.textColor = UIColor.red
                self.startRecording()
            } else if(captureVideoOut?.isRecording)! {
                doVideoBtn.titleLabel?.textColor = UIColor.white
                self.stopRecording()
            }
        }
    }

    //starts video recording
    func startRecording(){
        cameraSecondaryOptions?.isOrientationSwitchEnabled = false
        cameraSecondaryOptions?.isFlashAvailable = false
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

        startStopVideoCounter()
    }

    func stopRecording() {
        cameraSecondaryOptions?.isOrientationSwitchEnabled = true
        cameraSecondaryOptions?.isFlashAvailable = true

        videRecordCountdownTimer.invalidate()
        UIView.animate(withDuration: self.VIDEO_RECORD_INTERVAL_COUNTDOWN/2, delay: 0, options: .curveEaseOut, animations: {
            self.videoRecordIndicator.alpha = 0.0
            self.videoRecordCountdownSeconds = 0.0
            self.videoCounterLabel.alpha = 0.0

        }) { (success:Bool) in
            DispatchQueue.main.async {
                self.videoCounterLabel.text = String()
            }
        }

        captureVideoOut?.stopRecording()
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
}

class CariocaMenuOverride: CariocaMenu {
    override func prepareGestureHelperView(_ edgeAttribute:NSLayoutAttribute, width:CGFloat)->UIView{
        let view = UIView()
        return view
    }
}

class SharedBlurView: UIVisualEffectView {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layer.masksToBounds    = true
        self.layer.cornerRadius     = 5
    }
}

class ResolutionFormat: NSObject {
    let photoResolution:  CMVideoDimensions!
    let videoResolution:  CMVideoDimensions!
    let fpsRange:         AVFrameRateRange!
    let isSlomo:          Bool!
    var isActive:         Bool    = false
    let format:           AVCaptureDeviceFormat!
    let name:             String!

    init(_format: AVCaptureDeviceFormat, _frameRateObj: AVFrameRateRange) {
        videoResolution   = CMVideoFormatDescriptionGetDimensions(_format.formatDescription)
        photoResolution   = _format.highResolutionStillImageDimensions
        fpsRange          = _frameRateObj
        isSlomo           = _frameRateObj.maxFrameRate >= 120.0 //well technically it's 104.0
        format            = _format
        name              = String(Double(videoResolution.width)/1000.0) + "K"
    }
}

class ResPickerView: UIView {

    var name: String!
    var fps:    String!
    var isSlomo: Bool = false

    private var fpsLabel: UILabel!
    private var nameLabel: UILabel!
    private var slomoLabel: UILabel!

    init(
        frame: CGRect,
        _name: String,
        _fps:  String,
        _isSlomo: Bool = false) {

        super.init(frame: frame)

        name    = _name
        fps     =   _fps
        isSlomo = _isSlomo

        createFpsLabelView()
        createNameView()
        createSloMoView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func createFpsLabelView() {
        fpsLabel = UILabel.init(frame: CGRect.init(x: 0, y: 8, width: 50, height: 20))
        fpsLabel.textAlignment = .center
        fpsLabel.font = fpsLabel.font.withSize(9)
        fpsLabel.text = "FPS" + fps
        addSubview(fpsLabel)
    }

    func createNameView() {
        nameLabel = UILabel.init(frame: CGRect.init(x: 0, y: 28, width: 50, height: 20))
        nameLabel.textAlignment = .center
        nameLabel.text = name

        addSubview(nameLabel)
    }

    func createSloMoView() {

        slomoLabel = UILabel.init(frame: CGRect.init(x: 0, y: 50, width: 50, height: 20))
        slomoLabel.textAlignment = .center
        slomoLabel.font = fpsLabel.font.withSize(9)
        slomoLabel.text = "SLO-MO"

        slomoLabel.alpha = isSlomo == true ? 1 : 0.4
        addSubview(slomoLabel)
    }
}
