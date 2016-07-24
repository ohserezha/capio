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

class FirstViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Some default settings
    let EXPOSURE_DURATION_POWER:            Float       = 4.0 //the exposure slider gain
    let EXPOSURE_MINIMUM_DURATION:          Float64     = 1.0/2000.0
    
    var captureSession:                     AVCaptureSession?
    var captureStillImageOut:               AVCaptureStillImageOutput?
    var previewLayer:                       AVCaptureVideoPreviewLayer?
    
    var audioSession:                       AVAudioSession?
    
    var captureDevice :                     AVCaptureDevice?
    
    var exposureDuration:                   CMTime!
    var focusDistance:                      Float       = 0
    var isoValue:                           Float       = 100
    
    var temperatureValue:                   Float!
    
    var currentColorTemperature:            AVCaptureWhiteBalanceTemperatureAndTintValues!
    var currentColorGains:                  AVCaptureWhiteBalanceGains!
    
    var flashLightMode:                     String!
    
    @IBOutlet var myCamView:                UIView!
    @IBOutlet var makePhotoButton:          UIButton!

    @IBOutlet var focusSlider:              UISlider!
    
    @IBOutlet var shutterValueLabel:        UILabel!
    @IBOutlet var shutterSlider:            UISlider!

    @IBOutlet var isoLabel:                 UILabel!
    @IBOutlet var isoSlider:                UISlider!
    
    @IBOutlet var temperatureSlider:        UISlider!
    @IBOutlet var temperatureValueLabel:    UILabel!
    
    @IBAction func onTemperatureSliderChange(sender: UISlider) {
        temperatureValue = sender.value
        temperatureValueLabel.text = String(temperatureValue)
        
        changeTemperatureRaw(sender.value)
        configureCamera()
    }
    
    @IBAction func onIsoSliderChange(sender: UISlider) {
        isoValue = sender.value
        isoLabel.text = String(isoValue)
        configureCamera()
    }
    
    @IBAction func onShutterSliderChange(sender: UISlider) {
        setExposureDuration()
        configureCamera()
    }
    
    @IBAction func onFocusSlideDrag(sender: UISlider) {
        focusDistance = sender.value
        configureCamera()
    }
    
    @IBAction func onDoPhotoTrigger(sender: AnyObject) {
        captureImage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        focusDistance = focusSlider.value
        isoValue = isoSlider.value
        isoLabel.text = String(isoValue)
        
        UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Alert , .Sound, .Badge], categories: nil))
        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
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
        onDispose()
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
        
        currentColorGains = captureDevice?.deviceWhiteBalanceGains
        
        setCurrentDefaultCameraSettings()
        configureCamera()
        startCaptureSession()
    }
    
    private func setCurrentDefaultCameraSettings() {
        shutterValueLabel.text = String(shutterSlider.value)
        isoValue = isoSlider.value
        temperatureValueLabel.text = String(temperatureSlider.value)
        changeTemperatureRaw(temperatureSlider.value)
        
        setExposureDuration()
        listenVolumeButton()
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
    
    func captureImage() {
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
    
    func onDispose() {
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
    
    func setExposureDuration() {
        let p: Double = Double(pow( shutterSlider.value, EXPOSURE_DURATION_POWER )); // Apply power function to expand slider's low-end range
        let minDurationSeconds: Double  = max(CMTimeGetSeconds(captureDevice!.activeFormat.minExposureDuration), EXPOSURE_MINIMUM_DURATION);
        let maxDurationSeconds: Double = CMTimeGetSeconds(captureDevice!.activeFormat.maxExposureDuration);
        let newSecondsAmount = p * ( maxDurationSeconds - minDurationSeconds ) + minDurationSeconds
        exposureDuration = CMTimeMakeWithSeconds(Float64(newSecondsAmount), 1000*1000*1000); // Scale from 0-1 slider range to actual duration
        
        shutterValueLabel.text = "1/\(Int(1.0 / newSecondsAmount))"
    }
    
    //Take the actual temperature value
    func changeTemperatureRaw(temperature: Float) {
        self.currentColorTemperature = AVCaptureWhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0.0)
            currentColorGains = captureDevice!.deviceWhiteBalanceGainsForTemperatureAndTintValues(self.currentColorTemperature)
    }
    
    // Normalize the gain so it does not exceed
    func normalizedGains(gains: AVCaptureWhiteBalanceGains) -> AVCaptureWhiteBalanceGains {
        var g = gains;
        g.redGain = max(1.0, g.redGain);
        g.greenGain = max(1.0, g.greenGain);
        g.blueGain = max(1.0, g.blueGain);
        
        g.redGain = min(captureDevice!.maxWhiteBalanceGain, g.redGain);
        g.greenGain = min(captureDevice!.maxWhiteBalanceGain, g.greenGain);
        g.blueGain = min(captureDevice!.maxWhiteBalanceGain, g.blueGain);
        
        return g;
    }
    
    func configureCamera() {
        
        if let device = captureDevice {
            do {
                try device.lockForConfiguration()
                device.focusMode = .Locked
                device.setFocusModeLockedWithLensPosition(focusDistance, completionHandler: { (time) -> Void in })
                device.setExposureModeCustomWithDuration(exposureDuration, ISO: isoValue, completionHandler: { (time) -> Void in })
                device.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(normalizedGains(currentColorGains), completionHandler: { (time) -> Void in })
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

