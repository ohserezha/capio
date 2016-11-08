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
import ElasticTransition
import BRYXBanner
import JQSwiftIcon

import Photos

class FirstViewController:
    UIViewController,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    AVCaptureFileOutputRecordingDelegate,
    AVCapturePhotoCaptureDelegate {
    
    var captureSession:                     AVCaptureSession?
    var captureStillImageOut:               AVCapturePhotoOutput?
    var captureVideoOut:                    AVCaptureMovieFileOutput?
    var previewLayer:                       AVCaptureVideoPreviewLayer?

    var audioSession:                       AVAudioSession?

    var captureDevice :                     AVCaptureDevice?

    var flashLightMode:                     String!

    @IBOutlet var myCamView:                UIView!
    @IBOutlet var settingsBtn:              UIButton!
    @IBOutlet var doPhotoBtn:               UIButton!
    @IBOutlet var doVideoBtn:               UIButton!

    var transition = ElasticTransition()

    @IBAction func onDoPhotoTrigger(_ sender: AnyObject) {
        captureImage()
    }

    @IBAction func onShowOptionsPress(_ sender: UIButton) {
        transition.edge = .bottom
        transition.startingPoint = sender.center
        performSegue(withIdentifier: "CameraOptionsView", sender: self)
    }

    @IBAction func onDoPhotoTrigger(sender: AnyObject) {
        captureImage()
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

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination
        vc.transitioningDelegate = transition
        vc.modalPresentationStyle = .custom

        if (segue.identifier == "CameraOptionsView") {
            let cmvc = segue.destination as! CameraOptionsViewController;
            cmvc.captureDevice = self.captureDevice
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        settingsBtn.processIcons();
        doPhotoBtn.processIcons();
        doVideoBtn.processIcons();

        // customization
        transition.sticky = true
        transition.showShadow = false
        transition.panThreshold = 0.3
        transition.transformType = .translateMid
        transition.containerColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.0)
        transition.overlayColor = UIColor(white: 0, alpha: 0)
        transition.shadowColor = UIColor(white: 0, alpha: 0)
        transition.frontViewBackgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        transition.transformType = ElasticTransitionBackgroundTransform.subtle
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        onDispose()
        exit(0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = myCamView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        captureSession = AVCaptureSession()
        // in case you have music plaing in your phone
        // it will not get muted thanks to that
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        // todo -> write getter for Preset (device based)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080

        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        listenVolumeButton()
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
            //captureStillImageOut?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]

            if (captureSession?.canAddOutput(captureStillImageOut) != nil) {
                captureSession?.addOutput(captureStillImageOut)

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

            // 1
            if (self.captureDevice!.activeVideoMaxFrameDuration.timescale != 6) {
                do {
                    
                    try self.captureDevice?.lockForConfiguration()
                    
                    for vFormat in self.captureDevice!.formats {
                        
                        // 2
                        let ranges = (vFormat as AnyObject).videoSupportedFrameRateRanges as! [AVFrameRateRange]
                        let frameRates = ranges[0]
                        
                        // 3
                        if frameRates.maxFrameRate == 240 {
                            
                            // 4
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

    fileprivate func captureImage() {
        let settings = AVCapturePhotoSettings()
        
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160,
                             ]
        settings.previewPhotoFormat = previewFormat
        
        captureStillImageOut!.capturePhoto(with: settings, delegate: self)
    }
    
    fileprivate func onDispose() {
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
            //print(image: UIImage(data: dataImage)?.size)
            
            UIImageWriteToSavedPhotosAlbum(UIImage(data: dataImage)!,
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
    
    //starts vide recording
    func startRecording(){

        let outputUrl = NSURL(fileURLWithPath: NSTemporaryDirectory() + "temp.mp4")
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
                            print(error?.localizedDescription)
                            
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

    func listenVolumeButton(){
        do {
            audioSession = AVAudioSession.sharedInstance()
            // in case you have music plaing in your phone
            // it will not get muted thanks to that
            try audioSession?.setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
            try audioSession!.setActive(true)
            audioSession!.addObserver(self, forKeyPath: "outputVolume",
                                     options: NSKeyValueObservingOptions.new, context: nil)
        } catch {
            print(error)
        }

    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume"{
            captureImage()
        }
    }
}

