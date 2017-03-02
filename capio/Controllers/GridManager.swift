//
//  GridManager.swift
//  capio
//
//  Created by Roman on 2/27/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

enum GridFactors: Int {
    case off, double, quad
}

extension UIView
{
    func copyView() -> UIView?
    {
        return NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self)) as? UIView
    }
}

class GridManager {
    
    let gridLineThikness: CGFloat = 1.0
    
    var gridFactor: GridFactors {
        set {
            switch newValue {
            case .off:
                _gridFactor = 0
            case .double:
                _gridFactor = 2
            case .quad:
                _gridFactor = 4
            }
            _gridFactorRaw = newValue
            calcGrid()
        }
        get {
            return _gridFactorRaw
        }
    }
    private var _gridFactorRaw:     GridFactors = .off
    private var _gridFactor:        Int = 0
    
    private let gridView:           UIView!
    private let viewDimensions:     CGRect!
    private let storyBoard:         UIStoryboard!
    
    
    init(_gridView: UIView, _storyBoard: UIStoryboard ,_parentViewDimentions: CGRect) {
        gridView        = _gridView
        viewDimensions  = _parentViewDimentions
        storyBoard      = _storyBoard
    }
    
    func calcGrid() {
        gridView.subviews.forEach({ (view) in
            view.removeFromSuperview()
        })
        
        if (gridFactor != GridFactors.off) {
            let deltaH = viewDimensions.height/CGFloat(_gridFactor + 1)
            let deltaW = viewDimensions.width/CGFloat(_gridFactor + 1)
            
            let lineViewController = storyBoard?.instantiateViewController(withIdentifier: "GridLineItem")
            
            //horizontal
            for ind in 1..._gridFactor {
                
                let view = lineViewController?.view.copyView()
                
                gridView.addSubview(view!)
                
                view?.frame = CGRect.init(x: 0, y: deltaH*CGFloat(ind), width: gridView.bounds.width, height: gridLineThikness)
            }
            
            //vertical
            for ind in 1..._gridFactor {
                
                let view = lineViewController?.view.copyView()
                
                gridView.addSubview(view!)
                
                view?.frame = CGRect.init(x: deltaW*CGFloat(ind), y: 0, width: gridLineThikness, height: gridView.bounds.height)
            }
        }
    }
}
