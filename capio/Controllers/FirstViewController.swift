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

class FirstViewController:
    UIViewController,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    AVCaptureFileOutputRecordingDelegate,
    AVCapturePhotoCaptureDelegate,
    UIGestureRecognizerDelegate,
    CariocaMenuDelegate {
    
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
    
    @IBOutlet var sliderHostView:               UIView!
    
    @IBOutlet var resolutionBlurView:           UIVisualEffectView!
    @IBOutlet var FPSLabel: UILabel!    
    @IBOutlet var sloMoIndicatorLaber: UILabel!
    
    @IBOutlet var resolutionChangeBtn: UIButton!
    private var optionsMenu:                    CariocaMenu?
    private var cariocaMenuViewController:      CameraMenuContentController?
    private var cameraOptionsViewController:    CameraOptionsViewController?
    
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
        
        myCamView.addGestureRecognizer(camViewTapRecognizer)
        
        cameraOptionsViewController = self.storyboard?.instantiateViewController(withIdentifier: "CameraOptionsSlider") as? CameraOptionsViewController
        
        sliderHostView.addSubview((cameraOptionsViewController?.view)!)
        cameraOptionsViewController?.setActiveDevice(captureDevice!)
        
        setupMenu()
        
        doPhotoBtn.processIcons();
        doVideoBtn.processIcons();
    }
    
    private func setupMenu() {
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
        if (sliderHostView != nil) {
            self.cariocaMenuViewController?.menuToDefault()
            hideActiveSetting() {_ in
                print("Done hiding from tap")
            }
        }
    }
    
    fileprivate func showActiveSetting() {
        
        sliderHostView.center.x = self.view.center.x
        
        sliderHostView.transform = CGAffineTransform.init(translationX: 0, y: view.bounds.height/2 + self.sliderHostView.bounds.height + self.actionToolbar.bounds.height
        )
        sliderHostView.isHidden = false
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.sliderHostView.transform = CGAffineTransform.init(translationX: 0, y:
                self.view.bounds.height/2 - self.sliderHostView.bounds.height - self.actionToolbar.bounds.height/2
            )
        })
    }
    
    private func hideActiveSetting(_ completion: @escaping (_ result: AnyObject) -> Void) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.sliderHostView.transform = CGAffineTransform.init(translationX: 0, y: self.view.bounds.height/2 + self.sliderHostView.bounds.height + self.actionToolbar.bounds.height
                //- self.sliderHostView.frame.origin.y
            )
        }) { (success:Bool) in
            self.sliderHostView.isHidden = true
            self.cameraOptionsViewController?.unsetActiveslider()
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
    }

    @IBAction func onDoVideo(_ sender: UIButton) {
        if (!(captureVideoOut?.isRecording)!) {
            sender.titleLabel?.textColor = UIColor.red
            self.startRecording()
        } else if(captureVideoOut?.isRecording)! {
            sender.titleLabel?.textColor = UIColor.white
            self.stopRecording()
        }
    }
    
    func showDemoControllerForIndex(_ index:Int){
        
        hideActiveSetting() {_ in
            print("Done hiding from show")
            
            switch index {
                
            case 0:
                self.cameraOptionsViewController?.setActiveSlider(CameraOptionsViewController.CameraOptionsTypes.focus)
                self.showActiveSetting();
                break
            case 1:
                self.cameraOptionsViewController?.setActiveSlider(CameraOptionsViewController.CameraOptionsTypes.shutter)
                self.showActiveSetting();
                break
            case 2:
                self.cameraOptionsViewController?.setActiveSlider(CameraOptionsViewController.CameraOptionsTypes.iso)
                self.showActiveSetting();
                break
            case 3:
                self.cameraOptionsViewController?.setActiveSlider(CameraOptionsViewController.CameraOptionsTypes.temperature)
                self.showActiveSetting();
                break
            default:
                break
            }
            
            self.optionsMenu?.moveToTop()
        }
    }
    
    ///`Optional` Called when a menu item was selected
    ///- parameters:
    ///  - menu: The menu object
    ///  - indexPath: The selected indexPath
    func cariocaMenuDidSelect(_ menu:CariocaMenu, indexPath:IndexPath) {
        cariocaMenuViewController?.menuWillClose()
        showDemoControllerForIndex(indexPath.row)
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
                //todo: disable videobutton here if not available
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
                //todo: disable videobutton here if not available
            }

            if (self.captureDevice!.activeVideoMaxFrameDuration.timescale != 6) {
                do {
                    
                    try self.captureDevice?.lockForConfiguration()
                    
                    for vFormat in self.captureDevice!.formats {
                        
                        let ranges = (vFormat as AnyObject).videoSupportedFrameRateRanges as! [AVFrameRateRange]
                        let frameRates = ranges[0]
                        
                        //there are also 30/60/120
                        //todo: make an opton to switch between
                        if frameRates.maxFrameRate == 60 {
                            
                            self.captureDevice!.activeFormat = vFormat as! AVCaptureDeviceFormat
                            self.captureDevice!.activeVideoMinFrameDuration = frameRates.minFrameDuration
                            self.captureDevice!.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                        }
                    }
                    self.captureDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
            
            captureSession?.startRunning()            
        }
    }

    private func captureImage() {
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

        let outputUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "temp.mp4")
        if(FileManager().fileExists(atPath: NSTemporaryDirectory() + "temp.mp4")) {
            print("how-howhow")
            do {
                try FileManager().removeItem(atPath: NSTemporaryDirectory() + "temp.mp4")
            } catch {
                print(error)
            }
        }

        captureVideoOut?.startRecording(toOutputFileURL: outputUrl as URL!, recordingDelegate: self)
    }

    func stopRecording(){
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

