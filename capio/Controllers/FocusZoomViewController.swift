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
    
    var bounceTimer: Timer!
    
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
    
    func appear() {
        self.view.alpha = 0
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut, animations: {
            self.view.alpha = 1
        })
    }

    func disolveToRemove() {
        UIView.animate(withDuration: 0.6, delay: 0.2, options: .curveEaseInOut, animations: {
            self.view.alpha = 0.1
        }) { _ in
            self.resetView()
        }
    }
    
    func disolve() {
        bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { (timer) in
            UIView.animate(withDuration: 0.2, delay: 0.2, options: .curveEaseInOut, animations: {
                if self.view != nil {
                    self.view.alpha = floor(10*self.view.alpha) == 2 ? 0.45 : 0.2;
                }
            })
        })
    }
    
    func resetView() {
        if (bounceTimer != nil) {
            bounceTimer.invalidate()
            bounceTimer = nil
        }

        self.view.removeFromSuperview()
        self.view.alpha = 1
    }
}
