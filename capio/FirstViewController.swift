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

class FirstViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var captureSession:                     AVCaptureSession?
    var captureStillImageOut:               AVCaptureStillImageOutput?
    var previewLayer:                       AVCaptureVideoPreviewLayer?
    
    var audioSession:                       AVAudioSession?
    
    var captureDevice :                     AVCaptureDevice?
        
    var flashLightMode:                     String!
    
    @IBOutlet var myCamView:                UIView!
    @IBOutlet var makePhotoButton:          UIButton!    
    
    var transition = ElasticTransition()    
    
    @IBAction func onDoPhotoTrigger(sender: AnyObject) {
        captureImage()
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
        

//        
//        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert , .Sound, .Badge], categories: nil))
//        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
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
    func onImageSaved(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo:UnsafePointer<Void>) {
        if error == nil {
            
            print("SUCCESSS0000")
            
            let notification = UILocalNotification()
            
            notification.alertBody = "Photo Saved!"
            notification.soundName = UILocalNotificationDefaultSoundName
            notification.fireDate = NSDate(timeIntervalSinceNow: 0)
            notification.timeZone = NSTimeZone.defaultTimeZone()
            notification.userInfo = ["title": "capioPhoto", "UUID": "capioPhotoUUID"]
            UIApplication.sharedApplication().presentLocalNotificationNow(notification)
            
            print("SUCCESSS111")
        } else {
            let ac = UIAlertController(title: "Save error", message: error?.localizedDescription, preferredStyle: .Alert)
            ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            presentViewController(ac, animated: true, completion: nil)
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

