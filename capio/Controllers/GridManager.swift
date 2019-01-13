//
//  GridManager.swift
//  capio
//
//  Created by Roman on 2/27/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

enum GridFactor: Int {
//    cuz state incement goes as 0,1,2,.. +1
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
  
  var gridFactor: GridFactor = .off {
    
    willSet {
        switch newValue {
        case .off:
            _gridFactor = 0
        case .double:
            _gridFactor = 2
        case .quad:
            _gridFactor = 4
        }
    }
    
    didSet {
        calcGrid()
    }
  }
  
// we need this one cuz set is comming in 0,1,2..
// but calculation must be in 0,2,4..
  private var _gridFactor:        Int = 0
    
  private let gridView:           UIView!
  private let viewDimensions:     CGRect!
  private let storyBoard:         UIStoryboard!
  
  
  init(gridView: UIView, storyBoard: UIStoryboard ,parentViewDimensions: CGRect) {
    self.gridView = gridView
    viewDimensions = parentViewDimensions
    self.storyBoard = storyBoard
  }
  
  func calcGrid() {
    gridView.subviews.forEach {
      $0.removeFromSuperview()
    }
    
    if (gridFactor != .off) {
      let deltaH = viewDimensions.height/CGFloat(_gridFactor + 1)
      let deltaW = viewDimensions.width/CGFloat(_gridFactor + 1)
      
      let lineViewController = storyBoard?.instantiateViewController(withIdentifier: "GridLineItem")
      
      //horizontal
      for ind in 1..._gridFactor {
        
        if let verticalView = lineViewController?.view.copyView(),
          let horizontalView = lineViewController?.view.copyView() {
          
          horizontalView.frame = CGRect(x: 0,
                                        y: deltaH*CGFloat(ind),
                                        width: gridView.bounds.width,
                                        height: gridLineThikness)
          
          verticalView.frame = CGRect(x: deltaW*CGFloat(ind),
                                      y: 0,
                                      width: gridLineThikness,
                                      height: gridView.bounds.height)
          
          gridView.addSubview(verticalView)
          gridView.addSubview(horizontalView)
        }
      }
    }
  }
}
