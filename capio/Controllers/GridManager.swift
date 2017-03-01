//
//  GridManager.swift
//  capio
//
//  Created by Roman on 2/27/17.
//  Copyright © 2017 theroman. All rights reserved.
//

import UIKit

enum GridFactors: Int {
    case off, double, tripple
}

class GridManager {
    
    var gridFactor: GridFactors = .off
    private let gridView: UIView!
    private let viewDimensions: Dimension!
    
    init(_gridView: UIView, _parentViewDimentions: Dimension) {
        gridView        = _gridView
        viewDimensions  = _parentViewDimentions
    }
    
    func calcGrid() {
    
    }
}
