//
//  GridManager.swift
//  capio
//
//  Created by Roman on 2/27/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

enum GridFactor: Int {
  case off = 0
  case double = 2
  case quad = 4
}

class GridManager {
  
  let gridLineThikness: CGFloat = 1.0
  
  var gridFactor: GridFactor {
    didSet {
      calcGrid()
    }
  }
  
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
      let deltaH = viewDimensions.height/CGFloat(gridFactor.rawValue + 1)
      let deltaW = viewDimensions.width/CGFloat(gridFactor.rawValue + 1)
      
      let lineViewController = storyBoard?.instantiateViewController(withIdentifier: "GridLineItem")
      
      //horizontal
      for ind in 1...gridFactor.rawValue {
        
        if let verticalView = lineViewController?.view.copy() as? UIView,
          let horizontalView = lineViewController?.view.copy() as? UIView {
          
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
