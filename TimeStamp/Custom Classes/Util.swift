//
//  File.swift
//  TimeStamp
//
//  Created by Jacky He on 2019-05-23.
//  Copyright © 2019 Baker Jackson. All rights reserved.
//

import Foundation
import UIKit


//This class is for random static methods that might be commonly used
class Util
{
    //Prints all the available fonts in the system to the console
    static func printFonts ()
    {
        for family: String in UIFont.familyNames
        {
            print("\(family)")
            for names: String in UIFont.fontNames(forFamilyName: family)
            {
                print("== \(names)")
            }
        }
    }
    
    //The function returns the nearest Sunday from now
    static func nextSunday () -> NSDate
    {
        //gets the current user calendar
        let calendar = Calendar.current;
        
        //gets today's date
        var today: Date = Date();
        
        //initialize weekday
        var weekday = -1;
        
        //loop until the weekday variable says 1, which indicates a Sunday
        while (weekday != 1)
        {
            //Adds one day to "today"'s date
            today = calendar.date(byAdding: .day, value: 1, to: today)!
            
            //The week day value is set to the weekday component of the Date Object with name "today"
            weekday = calendar.component (.weekday, from: today);
        }
        
        //Calling start of day makes the Date referring to the midnight of the current date
        today = calendar.startOfDay(for: today);
        
        //returns the value as NSDate because Core Data hates Date
        return today as NSDate
    }
    
    static func nextDay () -> NSDate
    {
        //gets the current user calendar
        let calendar = Calendar.current;
        
        //gets today's date
        var today: Date = Date();
        
        //add one to today's date
        today = calendar.date (byAdding: .day, value: 1, to: today)!
        
        //set the date to the start of that day
        today = calendar.startOfDay (for: today);
        return today as NSDate;
    }
    
    static func next (days: Int) -> NSDate
    {
        //ges the current user calendar
        let calendar = Calendar.current;
        
        //gets today's date
        var today: Date = Date();
        
        //add days to today's date
        today = calendar.date(byAdding: .day, value: days, to: today)!
        
        //set the date to the start of that day
        today = calendar.startOfDay(for: today);
        return today as NSDate;
    }
}

protocol KeyboardShiftingDelegate: class
{
    func didReceiveData (_ data: CGPoint);
}

protocol EventPressedDelegate: class
{
    func eventPressed (startTime: Date, endTime: Date, title: String?, detail: String?, xpos: CGFloat, ypos: CGFloat);
}


extension UIImage {
    
    public class func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("image doesn't exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(source)
    }
    
    public class func gifImageWithURL(_ gifUrl:String) -> UIImage? {
        guard let bundleURL:URL = URL(string: gifUrl)
            else {
                print("image named \"\(gifUrl)\" doesn't exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("image named \"\(gifUrl)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    public class func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main
            .url(forResource: name, withExtension: "gif") else {
                print("SwiftGif: This image named \"\(name)\" does not exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)
        
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as! Double
        
        if delay < 0.1 {
            delay = 0.1
        }
        
        return delay
    }
    
    class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        if a! < b! {
            let c = a
            a = b
            b = c
        }
        
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b!
            } else {
                a = b
                b = rest
            }
        }
    }
    
    class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()
        
        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }
            
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            source: source)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }
        
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[Int(i)])
            frameCount = Int(delays[Int(i)] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)
        
        return animation
    }
}

extension UIView
{
    func addConstraintsWithFormat (_ format: String, views: UIView...)
    {
        var viewsDictionary = [String: UIView]();
        for (index, view) in views.enumerated()
        {
            let key = "v\(index)";
            view.translatesAutoresizingMaskIntoConstraints = false;
            viewsDictionary [key] = view;
        }
        addConstraints (NSLayoutConstraint.constraints(withVisualFormat: format, options: NSLayoutConstraint.FormatOptions(), metrics: nil, views: viewsDictionary))
    }
    
    //this creates a drop shadow given that the corner radius has already been set
    func dropShadow ()
    {
        layer.shadowColor = UIColor.black.cgColor;
        layer.shadowOpacity = 0.5
        layer.masksToBounds = false;
        layer.shadowRadius = 2;
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath;
        layer.shadowOffset = CGSize(width: 0.0, height: 1.0);
    }
    
    func pushTransition (_ duration: CFTimeInterval)
    {
        let animation = CATransition ()
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.type = .push
        animation.subtype = .fromTop
        animation.duration = duration;
        animation.isRemovedOnCompletion = false;
        self.layer.add (animation, forKey: "transition");
    }
}

extension UIColor
{
    static func getColor (_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor
    {
        return UIColor (red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: 1);
    }
}

extension UIImage {
    
    convenience init?(imageName: String) {
        self.init(named: imageName)
        accessibilityIdentifier = imageName
    }
    
    func imageWithColor (newColor: UIColor?) -> UIImage? {
        
        if let newColor = newColor {
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            
            let context = UIGraphicsGetCurrentContext()!
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.setBlendMode(.normal)
            
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            context.clip(to: rect, mask: cgImage!)
            
            newColor.setFill()
            context.fill(rect)
            
            let newImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            newImage.accessibilityIdentifier = accessibilityIdentifier
            return newImage
        }
        
        if let accessibilityIdentifier = accessibilityIdentifier {
            return UIImage(imageName: accessibilityIdentifier)
        }
        
        return self
    }
}
