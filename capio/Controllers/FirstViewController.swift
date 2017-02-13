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

class FirstViewController:
    UIViewController,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    AVCaptureFileOutputRecordingDelegate,
    AVCapturePhotoCaptureDelegate,
    UIGestureRecognizerDelegate,
    CariocaMenuDelegate {
    
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
    
    private var optionsMenu:                    CariocaMenu?
    private var cariocaMenuViewController:      CameraMenuContentController?
    
    //menu controllers here
    private var cameraOptionsViewController:    CameraOptionsViewController?
    private var cameraResolutionMenu:           ResolutionViewController?
    
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
    
    fileprivate func processUi() {
        
        resolutionBlurView.layer.masksToBounds    = true
        resolutionBlurView.layer.cornerRadius     = 5
        
        let camViewTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.handlerCamViewTap(_:)))
        camViewTapRecognizer.numberOfTapsRequired = 1
        camViewTapRecognizer.numberOfTouchesRequired = 1
        
        let camViewDoubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.captureImage))
        camViewDoubleTapRecognizer.numberOfTapsRequired = 2
        camViewDoubleTapRecognizer.numberOfTouchesRequired = 1
        
        let camViewTrippleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(FirstViewController.startStopRecording))
        
        camViewTrippleTapRecognizer.numberOfTapsRequired = 3
        camViewTrippleTapRecognizer.numberOfTouchesRequired = 1
        
        myCamView.addGestureRecognizer(camViewTapRecognizer)
        myCamView.addGestureRecognizer(camViewDoubleTapRecognizer)
        myCamView.addGestureRecognizer(camViewTrippleTapRecognizer)
        
        //setting gesture priorities
        camViewTapRecognizer.require(toFail: camViewDoubleTapRecognizer)
        camViewTapRecognizer.require(toFail: camViewTrippleTapRecognizer)
        camViewDoubleTapRecognizer.require(toFail: camViewTrippleTapRecognizer)
        
        //todo: all settings processing should be moved in to a single unit
        cameraOptionsViewController = self.storyboard?.instantiateViewController(withIdentifier: "CameraOptionsSlider") as? CameraOptionsViewController
        cameraOptionsViewController?.setActiveDevice(captureDevice!)
        
        menuHostView.layer.masksToBounds    = true
        menuHostView.layer.cornerRadius     = 5
        menuHostView.setActiveMenu(cameraOptionsViewController!, menuType: .cameraSliderMenu)
        
        setupCameraSettingsSwipeMenu()
        
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
    
    func handlerCamViewTap(_ gestureRecognizer: UIGestureRecognizer) {
        if (menuHostView != nil) {
            if (menuHostView.activeMenuType == .cameraSliderMenu) {
                cariocaMenuViewController?.menuToDefault()
            }
            hideActiveSetting() {_ in
                print("Done hiding from tap")
            }
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
    
    func didChangeScaleValue(_ picker: ScalePicker, value: CGFloat) {
        //todo?
    }
    
    @IBAction func onDoPhotoTrigger(_ sender: AnyObject) {
        captureImage()
    }
    
    @IBAction func onResolutionButtonTrigger(_ sender: UIButton) {
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "selectedRowIndex"{
            let row = change?[NSKeyValueChangeKey.newKey] as! Int
            if (activeResolutionFormat != self.resolutionFormatsArray[row]) {
                self.setResolution(self.resolutionFormatsArray[row])
            }
        }
    }

    @IBAction func onDoVideo(_ sender: UIButton) {
        startStopRecording()
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
        // it will not get muted thanks to that
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        // todo -> write getter for Preset (device based)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        
        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
//        listenVolumeButton()
        startCaptureSession()
    }

    fileprivate func startCaptureSession() {
       var input: AVCaptureInput!

        do {
            try input = AVCaptureDeviceInput(device: captureDevice!)
        } catch {
            print(error)
        }

        if (captureSession?.canAddInput(input) != nil) {
            captureSession?.addInput(input)

            captureStillImageOut = AVCapturePhotoOutput()

            if (captureSession?.canAddOutput(captureStillImageOut) != nil) {
                captureSession?.addOutput(captureStillImageOut)
                
                captureStillImageOut?.isHighResolutionCaptureEnabled = true

                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
                
                myCamView.layer.addSublayer((previewLayer)!)

            } else {
                doPhotoBtn.isEnabled = false
            }

            captureVideoOut = AVCaptureMovieFileOutput()

            if(captureSession?.canAddOutput(captureVideoOut) != nil) {
                  // todo: consider to be a setting?
//                let preferredTimeScale:Int32 = 30
//                let totalSeconds:Int64 = Int64(Int(7) * Int(preferredTimeScale)) // after 7 sec video recording stop automatically
//                let maxDuration:CMTime = CMTimeMake(totalSeconds, preferredTimeScale)
//                captureVideoOut?.maxRecordedDuration = maxDuration
                captureVideoOut?.minFreeDiskSpaceLimit = 1024 * 1024

                captureSession?.addOutput(captureVideoOut)
            } else {
                doVideoBtn.isEnabled = false
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
    }
    
    private func setResolution(_ newResolutionFormat: ResolutionFormat) {
        activeResolutionFormat = newResolutionFormat
        
        do {
            try self.captureDevice?.lockForConfiguration()
            
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
        
        FPSLabel.text = "FPS" + String(Int(activeResolutionFormat.fpsRange.maxFrameRate))
        sloMoIndicatorLabel.alpha = activeResolutionFormat.isSlomo == true ? 1.0 : 0.4
        resolutionChangeBtn.setTitle(activeResolutionFormat.name, for: .normal)
    }

    func captureImage() {
        AudioServicesPlaySystemSound(1519)
        let settings = AVCapturePhotoSettings()
        
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160,
                             ]
        settings.previewPhotoFormat = previewFormat
        settings.isHighResolutionPhotoEnabled = true
        
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
            print("width: " + String(describing: UIImage(data: dataImage)?.size.width))
            print("heighth: " + String(describing: UIImage(data: dataImage)?.size.height))
            
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
            
            self.videRecordCountdownTimer = Timer.scheduledTimer(withTimeInterval: self.VIDEO_RECORD_INTERVAL_COUNTDOWN, repeats: true, block: {timer in
                let videoRecordCountdownSeconds = (self.captureVideoOut?.recordedDuration.seconds)!
                
                let seconds: Int = Int(videoRecordCountdownSeconds) % 60
                let minutes: Int = Int((videoRecordCountdownSeconds / 60)) % 60
                let hours: Int = Int(videoRecordCountdownSeconds) / 3600
                
                DispatchQueue.main.async {
                    self.videoCounterLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                }
                
                UIView.animate(withDuration: self.VIDEO_RECORD_INTERVAL_COUNTDOWN/2, delay: 0, options: .curveEaseOut, animations: {
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
    
    //don't remove all this bellow yet -> get it back later once 
    // the active photo/video source is being figured
//    func listenVolumeButton(){
//            NotificationCenter.default.addObserver(self, selector: #selector(FirstViewController.applicationIsActive), name: .UIApplicationDidBecomeActive, object: nil)
//    }
//
//    func applicationIsActive() {
//        do {
//            audioSession = AVAudioSession.sharedInstance()
//            // in case you have music plaing in your phone
//            // it will not get muted thanks to that
//            try audioSession?.setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
//            try audioSession!.setActive(true)
//            audioSession!.addObserver(self, forKeyPath: "outputVolume",
//                                      options: NSKeyValueObservingOptions.new, context: nil)
//        } catch {
//            print(error)
//        }
//    }
//    
//    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//        if keyPath == "outputVolume"{
//            captureImage()
//        }
//    }
}

