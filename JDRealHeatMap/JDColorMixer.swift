//
//  JDColorMixer.swift
//  JDRealHeatMap
//
//  Created by 郭介騵 on 2017/6/30.
//  Copyright © 2017年 james12345. All rights reserved.
//

import UIKit

public enum ColorMixerMode
{
    case BlurryMode
    case DistinctMode
}


struct BytesRGB
{
    var redRow:UTF8Char = 0
    var greenRow:UTF8Char = 0
    var BlueRow:UTF8Char = 0
    var alpha:UTF8Char = 255
}

class JDHeatColorMixer:NSObject
{
    var colorArray:[UIColor]  = []
    var devideLevel:Int
    var mixerMode:ColorMixerMode = .DistinctMode
    
    init(array:[UIColor],level:Int)
    {
        devideLevel = level
        if(devideLevel == 0) {fatalError("devide level should not be 0")}
        if(devideLevel == 1) { colorArray = array
            return}
        for index in 0..<array.count
        {
            if(index == array.count-1) {break}
            
            if let rgb = array[index].rgb(),let rgb2 = array[index+1].rgb()
            {
                let greenDiff = (rgb2.green - rgb.green) / Float(devideLevel-1)
                let redDiff = (rgb2.red - rgb.red) / Float(devideLevel-1)
                let blueDiff = (rgb2.blue - rgb.blue) / Float(devideLevel-1)
                //
                for color1toColor2 in 0..<devideLevel
                {
                    let step:Float = Float(color1toColor2)
                    let red = CGFloat(rgb.red + (redDiff * step)) / 255.0
                    let green = CGFloat(rgb.green + (greenDiff * step)) / 255.0
                    let blue = CGFloat(rgb.blue + (blueDiff * step)) / 255.0
                    let color = UIColor(red:red, green: green, blue: blue, alpha: 1.0)
                    colorArray.append(color)
                }
            }
        }
    }
    
    func getDestinyColorRGB(inDestiny D:Float)->BytesRGB
    {
        func getClearify(inDestiny D:Float)->BytesRGB
        {
            if(D == 0) //Only Radius Data Type will Have 0 destiny
            {
                let rgb:BytesRGB = BytesRGB(redRow: 0,
                                            greenRow: 0,
                                            BlueRow: 0,
                                            alpha: 0)
                return rgb
            }
            //
            let colorCount = colorArray.count
            if(colorCount < 2)
            {
                colorArray.append(UIColor.clear)
            }
            
            var TargetColor:UIColor = colorArray.last!
            let AverageWeight:Float = 1.0 / Float(colorCount)
            var counter:Float = 0.0
            for color in colorArray
            {
                let next = counter + AverageWeight
                if((counter < D) && D<next)
                {
                    TargetColor = color
                    break
                }
                else if(D == next)
                {
                    TargetColor = UIColor.brown
                    break
                }
                else
                {
                    counter = next
                }
            }
            //
            let rgb = TargetColor.rgb()
            let redRow:UTF8Char = UTF8Char(Int((rgb?.red)!))
            let GreenRow:UTF8Char = UTF8Char(Int((rgb?.green)!))
            let BlueRow:UTF8Char = UTF8Char(Int((rgb?.blue)!))
            
            let Crgb:BytesRGB = BytesRGB(redRow: redRow,
                                         greenRow: GreenRow,
                                         BlueRow: BlueRow,
                                         alpha: 255)
            return Crgb
        }
        
        func getBlurryRGB(inDestiny D:Float)->BytesRGB
        {
            if(D == 0)
            {
                let rgb:BytesRGB = BytesRGB(redRow: 0,
                                            greenRow: 0,
                                            BlueRow: 0,
                                            alpha: 0)
                return rgb
            }
            
            let colorCount = colorArray.count
            if(colorCount < 2)
            {
                colorArray.append(UIColor.clear)
            }
            
            var TargetColor:[UIColor] = []
            let AverageWeight:Float = 1.0 / Float(colorCount-1)
            var counter:Float = 0.0
            var RDiff:Float = 0.0
            for color in colorArray
            {
                counter  += AverageWeight
                if(D < counter) //The Target is between this two color
                {
                    TargetColor.append(color)
                    if(TargetColor.count == 2)
                    {
                        break
                    }
                    let more = (counter - D)
                    RDiff = AverageWeight - more //
                }
                else if(counter == D)
                {
                    TargetColor = [color,color]
                    break
                }
                
            }
            let LDiff = 1.0 - RDiff
            //
            func caculateRGB()->BytesRGB
            {
                if(TargetColor.count != 2) {fatalError("Color Mixer Problem")}
                let LCGColor = TargetColor[0].rgb()
                let LRed:Float = (LCGColor?.red)!
                let LGreen:Float = (LCGColor?.green)!
                let LBlue:Float = (LCGColor?.blue)!
                let RCGColor = TargetColor[1].rgb()
                let RRed:Float = (RCGColor?.red)!
                let RGreen:Float = (RCGColor?.green)!
                let RBlue:Float = (RCGColor?.blue)!
                
                //
                let redRow:UTF8Char = UTF8Char(Int(LRed * LDiff + RRed * RDiff))
                let GreenRow:UTF8Char = UTF8Char(Int(LGreen * LDiff + RGreen * RDiff))
                let BlueRow:UTF8Char = UTF8Char(Int(LBlue * LDiff + RBlue * RDiff))
                return BytesRGB(redRow: redRow,
                                            greenRow: GreenRow,
                                            BlueRow: BlueRow,
                                            alpha: 255)
            }
            return caculateRGB()
        }
        
        if(mixerMode == .BlurryMode)
        {
            return getBlurryRGB(inDestiny: D)
        }
        else if(mixerMode == .DistinctMode)
        {
            return getClearify(inDestiny: D)
        }
        return BytesRGB(redRow: 0,
                        greenRow: 0,
                        BlueRow: 0,
                        alpha: 0)
    }
}

extension UIColor {
    
    func rgb() -> (red:Float, green:Float, blue:Float, alpha:Float)? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iRed = Float(fRed * 255.0)
            let iGreen = Float(fGreen * 255.0)
            let iBlue = Float(fBlue * 255.0)
            let iAlpha = Float(fAlpha * 255.0)
            
            return (red:iRed, green:iGreen, blue:iBlue, alpha:iAlpha)
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
}
