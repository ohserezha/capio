//
//  FocusZoomViewController.swift
//  capio
//
//  Created by Roman on 2/17/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

class FocusZoomViewController: UIViewController {
    
    @IBOutlet var blurView: UIVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
    }
    
    override func viewDidAppear(_ animated: Bool) {
    }
    
    override func viewWillDisappear(_ animated: Bool) {
       
    }
    
    func scaleToAppear() {
        self.view.alpha = 0
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut, animations: {
            self.view.alpha = 1
        })
    }
    
    func scaleToDisolve() {
        UIView.animate(withDuration: 0.6, delay: 0.2, options: .curveEaseInOut, animations: {
            self.view.alpha = 0            
        }) { _ in
            self.resetView()
        }
    }
    
    func resetView() {
        self.view.removeFromSuperview()
        self.view.alpha = 1
    }
}
