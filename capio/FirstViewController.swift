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

class FirstViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureFileOutputRecordingDelegate {

    var captureSession:                     AVCaptureSession?
    var captureStillImageOut:               AVCaptureStillImageOutput?
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

    @IBAction func onDoPhotoTrigger(sender: AnyObject) {
        captureImage()
    }

    @IBAction func onDoVideo(sender: AnyObject) {
        print("Loool")
    }

    @IBAction func onShowOptionsPress(sender: UIButton) {
        transition.edge = .Bottom
        transition.startingPoint = sender.center
        performSegueWithIdentifier("CameraOptionsView", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let vc = segue.destinationViewController
        vc.transitioningDelegate = transition
        vc.modalPresentationStyle = .Custom

        if (segue.identifier == "CameraOptionsView") {
            let cmvc = segue.destinationViewController as! CameraOptionsViewController;
            cmvc.captureDevice = captureDevice
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        settingsBtn.processIcons();
        doPhotoBtn.processIcons();

        // customization
        transition.sticky = true
        transition.showShadow = true
        transition.panThreshold = 0.3
        transition.transformType = .TranslateMid
        transition.containerColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        transition.overlayColor = UIColor(white: 0, alpha: 0)
        transition.shadowColor = UIColor(white: 0, alpha: 0)
        transition.frontViewBackgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        transition.transformType = ElasticTransitionBackgroundTransform.Subtle
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        onDispose()
        exit(0)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = myCamView.bounds
    }

    override func viewWillDisappear(animated: Bool) {
        // I hope i'm releasing it right...
        super.viewWillDisappear(animated)
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        captureSession = AVCaptureSession()
        // in case you have music plaing in your phone
        // it will not get muted thanks to that
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        // todo -> write getter for Preset (device based)
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080

        captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)

        listenVolumeButton()
        startCaptureSession()
    }

    private func startCaptureSession() {
        var input: AVCaptureInput!

        do {
            try input = AVCaptureDeviceInput(device: captureDevice!)
        } catch {
            print(error)
        }

        if (captureSession?.canAddInput(input) != nil) {
            captureSession?.addInput(input)

            captureStillImageOut = AVCaptureStillImageOutput()
            captureStillImageOut?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]

            if (captureSession?.canAddOutput(captureStillImageOut) != nil) {
                captureSession?.addOutput(captureStillImageOut)

                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect

                myCamView.layer.addSublayer((previewLayer)!)

                captureSession?.startRunning()
            } else {
                //@todo: disable videobutton here if not available
            }
            
            
            captureVideoOut = AVCaptureMovieFileOutput()
            
            if(captureSession?.canAddOutput(captureVideoOut) != nil) {
                let preferredTimeScale:Int32 = 30
                let totalSeconds:Int64 = Int64(Int(7) * Int(preferredTimeScale)) // after 7 sec video recording stop automatically
                let maxDuration:CMTime = CMTimeMake(totalSeconds, preferredTimeScale)
                captureVideoOut?.maxRecordedDuration = maxDuration
                
                captureVideoOut?.minFreeDiskSpaceLimit = 1024 * 1024

            } else {
                //@todo: disable videobutton here if not available
            }
        }
    }

    private func captureImage() {
        if let videoConnection = captureStillImageOut!.connectionWithMediaType(AVMediaTypeVideo) {
            captureStillImageOut!.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData)!,
                                               self,
                                               #selector(FirstViewController.onImageSaved(_:didFinishSavingWithError:contextInfo:)),
                                               nil)
            }
        }
    }

    func startRecording(){
        let outputUrl = NSURL(fileURLWithPath: NSTemporaryDirectory() + "test.mp4")
        captureVideoOut?.startRecordingToOutputFileURL(outputUrl, recordingDelegate: self)
    }
    
    func stopRecording(){
        captureVideoOut?.stopRecording()
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!){
        print("Finish recording")
//        let success:Bool = false
        if error != 0 && error != nil{
            print("error")
//            let value: AnyObject? = error.userInfo?[AVErrorRecordingSuccessfullyFinishedKey]
//            if value == nil{
//                success = true
//            }else{
//                success = false
//            }
        }
//        if success == true{
        self.stopRecording()
//        }
    }
    
    private func captureVideo() {
        

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

    // photo success/fail save
    func onImageSaved(savedImage: UIImage, didFinishSavingWithError error: NSError?, contextInfo:UnsafePointer<Void>) {
        if error == nil {

            let banner = Banner(
                title: "Awesome!",
                subtitle: "You made a picture!",
                // todo
                // image: savedImage,
                backgroundColor: UIColor(red:13.00/255.0, green:13.0/255.0, blue:13.5/255.0, alpha:0.500))
            banner.dismissesOnTap = true
            banner.show(duration: 1.0)

        } else {
            let errorBanner = Banner(
                title: "Shoot!",
                subtitle: "something went terrebly wrong :(",
                backgroundColor: UIColor(red:188.00/255.0, green:16.0/255.0, blue:16.5/255.0, alpha:0.500))
            errorBanner.dismissesOnTap = true
            errorBanner.show(duration: 1.5)
        }
    }

    func listenVolumeButton(){
        do {
            audioSession = AVAudioSession.sharedInstance()
            // in case you have music plaing in your phone
            // it will not get muted thanks to that
            try audioSession?.setCategory(AVAudioSessionCategoryPlayback, withOptions: .MixWithOthers)
            try audioSession!.setActive(true)
            audioSession!.addObserver(self, forKeyPath: "outputVolume",
                                     options: NSKeyValueObservingOptions.New, context: nil)
        } catch {
            print(error)
        }

    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume"{
            captureImage()
        }
    }
}

