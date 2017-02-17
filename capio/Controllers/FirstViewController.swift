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
import BRYXBanner
import JQSwiftIcon

import Photos

import ScalePicker

import CariocaMenu

enum SettingMenuTypes {
    case none, cameraSliderMenu, resolutionMenu, flashMenu, allStatsMenu, miscMenu
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
    
    @IBOutlet var menuHostView:               MenuHostView!
    
    @IBOutlet var resolutionBlurView:           UIVisualEffectView!
    @IBOutlet var FPSLabel:                     UILabel!
    @IBOutlet var sloMoIndicatorLabel:          UILabel!
    @IBOutlet var resolutionChangeBtn:          UIButton!
    
    @IBOutlet var videoCounterLabel:            UILabel!
    @IBOutlet var videoRecordIndicator:         UIImageView!

    private var videoRecordCountdownSeconds:    Double = 0.0
    private var videRecordCountdownTimer:       Timer!
    
    @IBOutlet var resModePicker: UIPickerView!
    private var optionsMenu:                    CariocaMenu?
    private var cariocaMenuViewController:      CameraMenuContentController?
    
    //menu controllers here
    private var cameraOptionsViewController:    CameraOptionsViewController?
    private var cameraResolutionMenu:           ResolutionViewController?
    
    private var focusZoomView:                  FocusZoomViewController?
    
    private var resolutionFormatsArray: [ResolutionFormat] = [ResolutionFormat]()
    private var activeResolutionFormat: ResolutionFormat!
        
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
        optionsMenu?.showIndicator(.right, position: .bottom, offset: -50)
        
        optionsMenu?.addGestureHelperViews([.left,.right], width:30)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return resolutionFormatsArray.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        setResolution(resolutionFormatsArray[row])
        self.cameraResolutionMenu?.activeResolutionFormat = self.activeResolutionFormat        
    }
    
    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 80
    }
    
    public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {

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
    
    fileprivate func processUi() {
        
        resolutionBlurView.layer.masksToBounds    = true
        resolutionBlurView.layer.cornerRadius     = 5
        
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
        
        menuHostView.layer.masksToBounds    = true
        menuHostView.layer.cornerRadius     = 5
        
        setupCameraSettingsSwipeMenu()
        
        resModePicker.dataSource = self
        resModePicker.delegate = self
        
        let resTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.onShowResOptions))
        resTapRecognizer.numberOfTapsRequired = 1
        resTapRecognizer.numberOfTouchesRequired = 1
        resTapRecognizer.delegate = self
        
        resModePicker.addGestureRecognizer(resTapRecognizer)
        
        doPhotoBtn.processIcons();
        doVideoBtn.processIcons();
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
    
    func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point: CGPoint = gestureRecognizer.location(in: gestureRecognizer.view)
        
        if (gestureRecognizer.state == .began) {
            if(self.focusZoomView == nil) {
                self.focusZoomView = self.storyboard?.instantiateViewController(withIdentifier: "FocusZoomView") as? FocusZoomViewController
            }
            
            self.focusZoomView?.resetView()
            
            gestureRecognizer.view?.addSubview((self.focusZoomView?.view)!)

            self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)
            
            self.focusZoomView?.scaleToAppear()
        }
        
        if (gestureRecognizer.state == .changed) {
            self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)
        }
        
        if (gestureRecognizer.state == .ended) {
            
            self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)            
            
            self.focusZoomView?.scaleToDisolve()
            
            setPointOfInterest(point)
        }
    }
    
    func handlerCamViewTap(_ gestureRecognizer: UIGestureRecognizer) {
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
                self.focusZoomView?.scaleToDisolve()
                
                gestureRecognizer.view?.addSubview((self.focusZoomView?.view)!)
                let point: CGPoint = gestureRecognizer.location(in: gestureRecognizer.view)
                
                self.focusZoomView?.view.transform = CGAffineTransform.init(translationX: point.x - (focusZoomView?.view.bounds.width)!/2, y: point.y - (focusZoomView?.view.bounds.height)!/2)
            
                setPointOfInterest(point)
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
    
    fileprivate func showActiveSetting() {
        
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
    
    private func hideActiveSetting(_ completion: @escaping (_ result: AnyObject) -> Void) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.menuHostView.transform = CGAffineTransform.init(translationX: 0, y: self.view.bounds.height/2 + self.menuHostView.bounds.height + self.actionToolbar.bounds.height
            )
        }) { (success:Bool) in
            self.menuHostView.isHidden = true
            
            if(self.menuHostView.activeMenuType == .resolutionMenu) {
                self.cameraResolutionMenu?.removeObserver(self, forKeyPath: "selectedRowIndex")
            }
            
            self.menuHostView.unsetActiveMenu()
            completion(success as AnyObject)
        }
    }
    
    @IBAction func onDoPhotoTrigger(_ sender: AnyObject) {
        captureImage()
    }
    
    @IBAction func onResolutionButtonTrigger(_ sender: UIButton) {
        onShowResOptions()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "selectedRowIndex"{
            let row = change?[NSKeyValueChangeKey.newKey] as! Int
            if (activeResolutionFormat != self.resolutionFormatsArray[row]) {
                self.resModePicker.selectRow(row, inComponent: 0, animated: true)
                self.setResolution(self.resolutionFormatsArray[row])
            }
        }
    }

    @IBAction func onDoVideo(_ sender: UIButton) {
        startStopRecording()
    }
    
    open func onShowResOptions() {
        AudioServicesPlaySystemSound(1519)
        
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
    
    func startStopRecording() {
        if (!(captureVideoOut?.isRecording)!) {
            doVideoBtn.titleLabel?.textColor = UIColor.red
            self.startRecording()
        } else if(captureVideoOut?.isRecording)! {
            doVideoBtn.titleLabel?.textColor = UIColor.white
            self.stopRecording()
        }
    }
    
    ///`Optional` Called when a menu item was selected
    ///- parameters:
    ///  - menu: The menu object
    ///  - indexPath: The selected indexPath
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
    
    ///`Optional` Called when the menu is about to open
    ///- parameters:
    ///  - menu: The opening menu object
    func cariocaMenuWillOpen(_ menu:CariocaMenu) {
        cariocaMenuViewController?.menuWillOpen()
        if(logging){
            print("carioca MenuWillOpen \(menu)")
        }
    }
    
    ///`Optional` Called when the menu just opened
    ///- parameters:
    ///  - menu: The opening menu object
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
    
    ///`Optional` Called when the menu is about to be dismissed
    ///- parameters:
    ///  - menu: The disappearing menu object
    func cariocaMenuWillClose(_ menu:CariocaMenu) {
        cariocaMenuViewController?.menuWillClose()
        if(logging){
            print("carioca MenuWillClose \(menu)")
        }
    }
    
    ///`Optional` Called when the menu is dismissed
    ///- parameters:
    ///  - menu: The disappearing menu object
    func cariocaMenuDidClose(_ menu:CariocaMenu){
        if(logging){
            print("carioca MenuDidClose \(menu)")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    fileprivate func setCaptureSession() {
        
        captureSession = AVCaptureSession()
        // in case you have music plaing in your phone
        // it will not get muted thanks to that AND! setAudioSession
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        // todo -> write getter for Preset (device based)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        
        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        setAudioSession()
        startCaptureSession()
        
        //each time you spawn application back -> this observer gonna be triggered
        NotificationCenter.default.addObserver(self, selector: #selector(FirstViewController.setAudioSession), name: .UIApplicationDidBecomeActive, object: nil)
    }
    
    func setAudioSession() {
        do {
            //todo -> do audioSession set/unset on video record start/stop
            audioSession = AVAudioSession.sharedInstance()
            // in case you have music plaing in your phone
            // it will not get muted thanks to that AND! automaticallyConfiguresApplicationAudioSession
            try audioSession?.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .mixWithOthers)
            let currentPortName = ((audioSession?.currentRoute as AVAudioSessionRouteDescription!).outputs[0] as AVAudioSessionPortDescription!).portName
            if (currentPortName == AVAudioSessionPortBuiltInSpeaker || currentPortName == AVAudioSessionPortBuiltInReceiver) {
                try audioSession?.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
            }
            
            try audioSession!.setActive(true)
        } catch {
            print(error)
        }
    }

    fileprivate func startCaptureSession() {
       var videoDeviceInput: AVCaptureInput!

        do {
            //setting video
            try videoDeviceInput = AVCaptureDeviceInput(device: captureDevice!)
        } catch {
            fatalError()
        }
        
        if (captureSession?.canAddInput(videoDeviceInput) != nil) {
            captureSession?.addInput(videoDeviceInput)
        } else {
            fatalError()
        }
        
        do {
            //setting audio
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            
            let audioDeviceInput: AVCaptureDeviceInput
            
            do {
                audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            }
        catch {
            fatalError("[startCaptureSession]Could not create AVCaptureDeviceInput instance with error: \(error).")
        }
            guard (captureSession?.canAddInput(audioDeviceInput))! else {
                fatalError()
            }
            captureSession?.addInput(audioDeviceInput as AVCaptureInput)
        }
        
        //setting photo and video outputs
        captureStillImageOut = AVCapturePhotoOutput()

        if (captureSession?.canAddOutput(captureStillImageOut) != nil) {
            captureSession?.addOutput(captureStillImageOut)
                
            captureStillImageOut?.isHighResolutionCaptureEnabled = true

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                
            myCamView.layer.addSublayer((previewLayer)!)

        } else {
            doPhotoBtn.isEnabled = false
            fatalError()
        }
            
        let audioDataOutput = AVCaptureAudioDataOutput()
        let queue = DispatchQueue(label: "com.shu223.audiosamplequeue")
        audioDataOutput.setSampleBufferDelegate(self, queue: queue)
        guard (captureSession?.canAddOutput(audioDataOutput))! else {
            fatalError()
        }
                    
        captureSession?.addOutput(audioDataOutput)

        captureVideoOut = AVCaptureMovieFileOutput()

        if(captureSession?.canAddOutput(captureVideoOut) != nil) {
                  // todo: consider to be a setting?
//                let preferredTimeScale:Int32 = 30
//                let totalSeconds:Int64 = Int64(Int(7) * Int(preferredTimeScale)) // after 7 sec video recording stop automatically
//                let maxDuration:CMTime = CMTimeMake(totalSeconds, preferredTimeScale)
//                captureVideoOut?.maxRecordedDuration = maxDuration
            captureVideoOut?.minFreeDiskSpaceLimit = 1024 * 1024
            captureVideoOut?.movieFragmentInterval = kCMTimeInvalid

            captureSession?.addOutput(captureVideoOut)
        } else {
            doVideoBtn.isEnabled = false
            fatalError()
        }

        if (self.captureDevice!.activeVideoMaxFrameDuration.timescale != 6) {
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
        }
        setResolution(resolutionFormatsArray.first!)
        captureSession?.startRunning()
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
        settings.previewPhotoFormat = previewFormat
        settings.isHighResolutionPhotoEnabled = true
        
        //todo: make a wait_promt here, cuz on higher resolution sampleBuffer might take pretty long
        // specifically on night images
        
        captureStillImageOut!.capturePhoto(with: settings, delegate: self)
    }
    
    private func onDispose() {
        captureSession?.stopRunning()
        do {
            try audioSession?.setActive(false)
            audioSession?.removeObserver(self, forKeyPath: "outputVolume")
        } catch {
            print(error)
        }
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
    //starts video recording
    func startRecording(){
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
        
        //videou countdown counter starts here
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

    func stopRecording(){
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

        PHPhotoLibrary.requestAuthorization({ (authorizationStatus: PHAuthorizationStatus) -> Void in
            // check if user authorized access photos for your app
            if authorizationStatus == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)}) { completed, error in
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
        })

    }
}

