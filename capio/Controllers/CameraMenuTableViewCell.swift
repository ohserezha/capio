
import UIKit

class CameraMenuTableViewCell:UITableViewCell {
    
    fileprivate let textColorNormal = UIColor.lightGray
    fileprivate let textColorHighlighted = UIColor(red:0.46, green:0.82, blue:0.89, alpha:1)
    fileprivate let textColorSelected = UIColor(red:0.07, green:0.73, blue:0.86, alpha:1)
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func draw(_ rect: CGRect) {

    }
    
    func applyStyleNormal(){
        titleLabel.textColor = textColorNormal
    }
    
    func applyStyleHighlighted(){
        titleLabel.textColor = textColorHighlighted
    }
    
    func applyStyleSelected(){
        titleLabel.textColor = textColorSelected
    }
}
