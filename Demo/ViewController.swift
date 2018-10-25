//
//  ViewController.swift
//  Demo
//
//  Created by WEI QIN on 2018/10/25.
//  Copyright © 2018 WEI QIN. All rights reserved.
//

import UIKit
import GPU_SIFT

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // load image
        let image = UIImage(contentsOfFile: Bundle.main.path(forResource: "Jobs2", ofType: "jpeg")!)
        guard let cgImage = image?.cgImage else {
            return
        }
        
        // get features point
        let sift = SIFT()
        sift.initWithWidth(Int32(cgImage.width), height: Int32(cgImage.height), octaves: 4)
        let keyPoints = sift.computeSift(on: cgImage)
        
        // draw feature point on image
        let width = cgImage.width
        let height = cgImage.height
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, UIScreen.main.scale)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(UIColor.yellow.cgColor)
        context.setLineWidth(0.4)
        for point in (keyPoints as! [KeyPoint]) {
            context.move(to: point.cgPoint())
            context.addArc(center: point.cgPoint(), radius: 2.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            context.closePath()
            context.strokePath()
        }
        guard let outputImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return
        }
        
        // render on screen
        let imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.image = outputImage
        view.addSubview(imageView)
    }


}

