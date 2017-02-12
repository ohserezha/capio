//
//  ResolutionViewController.swift
//  capio
//
//  Created by Roman on 2/12/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit
import AVFoundation


enum ResMenuType{
    case label, picker
}

class LabelCell: UITableViewCell{
    
    var videoResDimensions: CMVideoDimensions {
        set {
            videResLabel.text = String(newValue.width) + "x" + String(newValue.height)
        }
        get {
            return self.videoResDimensions
        }
    }
    
    var photoResDimensions: CMVideoDimensions {
        set {
            photoResLabel.text = String(newValue.width) + "x" + String(newValue.height)
        }
        get {
            return self.videoResDimensions
        }
    }
    
    @IBOutlet weak var videResLabel: UILabel!
    @IBOutlet weak var slomoLabel: UILabel!
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet weak var photoResLabel: UILabel!
}

class PickerCell: UITableViewCell {
    @IBOutlet weak var resPicker: UIPickerView!
}

class ResolutionViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITableViewDelegate, UITableViewDataSource {
    
    var menu:[ResMenuType] = [ResMenuType]()
    var resolutionFormatsArray: [ResolutionFormat] = [ResolutionFormat]()
    
    dynamic var selectedRowIndex: Int = 0
    
    var activeResolutionFormat: ResolutionFormat {
        set {
            
            let rowIndex = resolutionFormatsArray.index { (format: ResolutionFormat) -> Bool in
                return format.photoResolution.width == newValue.photoResolution.width && format.videoResolution.height == newValue.videoResolution.height && format.name == newValue.name
            }
            
            let cell = tableView.cellForRow(at: IndexPath.init(row: 1, section: 0)) as! PickerCell
            
            cell.resPicker.selectRow(rowIndex!, inComponent: 0, animated: true)
            onPickerRowSelected(rowIndex!)
        }
        get {
            return self.activeResolutionFormat
        }
    }
    
    @IBOutlet var tableView: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        menu = [ResMenuType]()
        
        menu.append(.label)
        menu.append(.picker)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return resolutionFormatsArray.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return resolutionFormatsArray[row].name
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        onPickerRowSelected(row)
    }
    
    private func onPickerRowSelected(_ row: Int) {
        let cell = tableView.cellForRow(at: IndexPath.init(row: 0, section: 0)) as! LabelCell
        
        cell.videoResDimensions = resolutionFormatsArray[row].videoResolution
        cell.photoResDimensions = resolutionFormatsArray[row].photoResolution
        
        cell.fpsLabel.text = String(Int(resolutionFormatsArray[row].fpsRange.maxFrameRate))
        cell.slomoLabel.alpha = resolutionFormatsArray[row].isSlomo == true ? 1 : 0.4
        
        selectedRowIndex = row
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell
        switch menu[(indexPath as NSIndexPath).item]{
        case .label:
            let labelCell = tableView.dequeueReusableCell(withIdentifier: "cell_label", for: indexPath) as! LabelCell

            cell = labelCell
        case .picker:
            let pickerCell  = tableView.dequeueReusableCell(withIdentifier: "cell_picker", for: indexPath) as! PickerCell
            
            pickerCell.resPicker.dataSource = self
            pickerCell.resPicker.delegate = self

            cell = pickerCell
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menu.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch menu[(indexPath as NSIndexPath).item]{
        case .label:
            return 70
        case .picker:
            return 60
        }
    }
}
