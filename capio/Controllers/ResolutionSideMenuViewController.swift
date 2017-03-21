//
//  ResolutionSideMenuViewController.swift
//  capio
//
//  Created by Roman on 3/22/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

class ResolutionSideMenuViewController:
    UIViewController,
    UIPickerViewDelegate,
    UIPickerViewDataSource,
    UIGestureRecognizerDelegate {
    
    var captureSessionManager:                  CaptureSessionManager! = CaptureSessionManager.sharedInstance
    
    var onTouchEndCb:                           (() -> Void)?
    
    @IBOutlet var resModePicker: UIPickerView!
    @IBOutlet var resolutionBlurView: SharedBlurView!
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.captureSessionManager.resolutionFormatsArray.count
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        captureSessionManager.setResolution(captureSessionManager.resolutionFormatsArray[row])
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 80
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        
        var pickerCell = view as! ResPickerView!
        if pickerCell == nil {
            pickerCell = ResPickerView.init(frame: CGRect.init(x: 0, y: 0, width: 50, height: 80),
                                            _name: self.captureSessionManager.resolutionFormatsArray[row].name,
                                            _fps: String(self.captureSessionManager.resolutionFormatsArray[row].fpsRange.maxFrameRate),
                                            _isSlomo: self.captureSessionManager.resolutionFormatsArray[row].isSlomo
            )
        }
        
        return pickerCell!
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }    
    
    override func viewDidLoad() {
        processUi()
        let resTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(ResolutionSideMenuViewController.onShowResOptions))
        
        resTapRecognizer.numberOfTapsRequired = 1
        resTapRecognizer.numberOfTouchesRequired = 1
        resTapRecognizer.delegate = self
        
        resolutionBlurView.addGestureRecognizer(resTapRecognizer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        processSubscribers()
    }
    
    open func onShowResOptions(_ gestureRecognizer: UITapGestureRecognizer) {

        if (gestureRecognizer.state == .ended) {
            DispatchQueue.global(qos: .userInteractive).async {
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                        self.resolutionBlurView.transform = CGAffineTransform.init(scaleX: 0.9, y: 0.9)
                        self.resolutionBlurView.alpha = 0.5
                    }) {complete in
                        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                            self.resolutionBlurView.transform = CGAffineTransform.init(scaleX: 1, y: 1)
                            self.resolutionBlurView.alpha = 1
                        })
                    }
                }
            }
            if onTouchEndCb != nil {
                onTouchEndCb!()
            }
        }
    }
    
    //cuz ios would not allow two competeing touches to work at the same time
    func setTouchEndCb(cb: @escaping () -> Void) {
        onTouchEndCb = cb
    }
    
    private func processUi() {
    
        resolutionBlurView.layer.borderWidth = 1
        resolutionBlurView.layer.borderColor = UIColor.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.2).cgColor
    }
    
    private var currentBuffedFormat: ResolutionFormat!
    
    private func processSubscribers() {
        captureSessionManager.cameraSettingsObservable.subscribe(onNext: { (newCameraSettings: CameraSessionSettings) in
            if newCameraSettings.activeResFormat != nil && self.currentBuffedFormat != newCameraSettings.activeResFormat {
                let newFormat = newCameraSettings.activeResFormat!
                self.currentBuffedFormat = newCameraSettings.activeResFormat!
                //todo: figure a better way to pass the index right away here instead of lookup
                let rowIndex = self.captureSessionManager.resolutionFormatsArray.index { (format: ResolutionFormat) -> Bool in
                    return format.photoResolution.width == newFormat.photoResolution.width && format.videoResolution.height == newFormat.videoResolution.height && format.name == newFormat.name && format.fpsRange == newFormat.fpsRange && format.isSlomo == newFormat.isSlomo
                }
                
                self.resModePicker.selectRow(rowIndex!, inComponent: 0, animated: true)
            }
        })
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
        fpsLabel = UILabel.init(frame: CGRect.init(x: 0, y: 12, width: 50, height: 20))
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
        
        slomoLabel = UILabel.init(frame: CGRect.init(x: 0, y: 45, width: 50, height: 20))
        slomoLabel.textAlignment = .center
        slomoLabel.font = fpsLabel.font.withSize(9)
        slomoLabel.text = "SLO-MO"
        
        slomoLabel.alpha = isSlomo == true ? 1 : 0.4
        addSubview(slomoLabel)
    }
}
