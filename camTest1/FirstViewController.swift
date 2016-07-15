//
//  FirstViewController.swift
//  camTest1
//
//  Created by Roman on 7/10/16.
//  Copyright © 2016 theroman. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation

class FirstViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var captureSession: AVCaptureSession?
    var captureStillImageOut: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var audioSession: AVAudioSession?
    
    var captureDevice : AVCaptureDevice?
    
    var exposureDuration: CMTime!
    var focusDistance: Float = 0
    var isoValue: Float = 100
//    var whiteBalance: Float = 100
    
    var flashLightMode: String!
//    var lightValue?
    
    // Some default settings
    let EXPOSURE_DURATION_POWER:Float = 4.0 //the exposure slider gain
    let EXPOSURE_MINIMUM_DURATION:Float64 = 1.0/2000.0
    
    
    @IBOutlet var makePhotoButton: UIButton!
    @IBOutlet var focusSlider: UISlider!
    @IBOutlet var myCamView: UIView!
    
    @IBOutlet var shutterValueLabel: UILabel!
    @IBOutlet var isoLabel: UILabel!

    @IBOutlet var isoSlider: UISlider!
    
    @IBOutlet var shutterSlider: UISlider!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        focusDistance = focusSlider.value
        isoValue = isoSlider.value
        isoLabel.text = String(isoValue)
    }
    
    @IBAction func onFocusSlideDrag(sender: UISlider) {
        focusDistance = sender.value
        configureCamera()
    }
    
    @IBAction func onShutterSliderChange(sender: UISlider) {
        setExposureDuration()
        configureCamera()
    }
    
    @IBAction func onDoPhotoTrigger(sender: AnyObject) {
        captureImage()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer?.frame = myCamView.bounds
    }
    
    override func viewWillDisappear(animated: Bool) {
        // I hope i'm releasing it right...        
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
        do {
            try audioSession?.removeObserver(self, forKeyPath: "outputVolume")
            try audioSession?.setActive(false)
        } catch {
            print(error)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        shutterValueLabel.text = String(shutterSlider.value)
        
        captureSession = AVCaptureSession()
        // in case you have music plaing in your phone
        // it will not get muted thanks to that
        captureSession?.automaticallyConfiguresApplicationAudioSession = false
        captureSession?.sessionPreset = AVCaptureSessionPreset1920x1080
        
        captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        var input: AVCaptureInput!
        
        setExposureDuration()
        listenVolumeButton()
        configureCamera()
        
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
    
    func captureImage() {
        if let videoConnection = captureStillImageOut!.connectionWithMediaType(AVMediaTypeVideo) {
            captureStillImageOut!.captureStillImageAsynchronouslyFromConnection(videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData)!,
                                               self,
                                               #selector(FirstViewController.image(_:didFinishSavingWithError:contextInfo:)),
                                               nil
                )
            }
        }
    }
    
    @IBAction func onIsoSliderChange(sender: UISlider) {
        isoValue = sender.value
        isoLabel.text = String(isoValue)
        configureCamera()
    }
    func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo:UnsafePointer<Void>) {
        if error == nil {
            let ac = UIAlertController(title: "Saved!", message: "Your altered image has been saved to your photos.", preferredStyle: .Alert)
            ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            presentViewController(ac, animated: true, completion: nil)
        } else {
            let ac = UIAlertController(title: "Save error", message: error?.localizedDescription, preferredStyle: .Alert)
            ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
            presentViewController(ac, animated: true, completion: nil)
        }
    }
    
    func setExposureDuration() {
        let p: Double = Double(pow( shutterSlider.value, EXPOSURE_DURATION_POWER )); // Apply power function to expand slider's low-end range
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        let newSecondsAmount = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds
        exposureDuration = CMTimeMakeWithSeconds(Float64(newSecondsAmount), 1000*1000*1000); // Scale from 0-1 slider range to actual duration
        
        shutterValueLabel.text = "1/\(Int(1.0 / newSecondsAmount))"
    }
    
    func configureCamera() {
        
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                device.focusMode = .Locked
                device.setFocusModeLockedWithLensPosition(focusDistance, completionHandler: { (time) -> Void in })
                device.setExposureModeCustomWithDuration(exposureDuration, ISO: isoValue, completionHandler: { (time) -> Void in })
//                device.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(AVCaptureWhiteBalanceGains(redGain: 1,greenGain: 1,blueGain: 1), completionHandler: <#T##((CMTime) -> Void)!##((CMTime) -> Void)!##(CMTime) -> Void#>)
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
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

