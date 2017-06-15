//
//  JDOverlay.swift
//  JDRealHeatMap
//
//  Created by 郭介騵 on 2017/6/14.
//  Copyright © 2017年 james12345. All rights reserved.
//

import UIKit
import MapKit

/**
    這個類別只需要知道MapRect層面，不需要知道CGRect層面的事
 */

class JDHeatOverlay:NSObject, MKOverlay
{
    var HeatPointsArray:[JDHeatPoint] = []
    var NewHeatPointBuffer:[JDHeatPoint] = []
    var CaculatedMapRect:MKMapRect?
    /* 
        Set to true when a new heatPoint Insert
        Tell the overlay render to recaculate the row data.
    */
    var HeatPointNeedupdate:Bool = false
    
    var coordinate: CLLocationCoordinate2D
    {
        return HeatPointsArray[0].coordinate
    }
    /*
     If you project the curved surface of the globe onto a flat surface, what you get is a two-dimensional version of a map where longitude lines appear to be parallel. Such maps are often used to show the entire surface of the globe all at once. An MKMapRect data structure represents a rectangular area as seen on this two-dimensional map.
     **/
    var boundingMapRect: MKMapRect
    {
        guard let BeenCaculatedMapRect = CaculatedMapRect else {
            return MKMapRect()
        }
        return BeenCaculatedMapRect
    }
    /**
        有新的點加進來 ->
        重新計算這個Overlay的涵蓋
     */
    func caculateMaprect(newPoint:JDHeatPoint)
    {
        var MaxX:Double = 0
        var MaxY:Double = 0
        var MinX:Double = 99999999999999
        var MinY:Double = 99999999999999
        if let BeenCaculatedMapRect = CaculatedMapRect
        {
            //Not the First Time
            MaxX = MKMapRectGetMaxX(BeenCaculatedMapRect)
            MaxY = MKMapRectGetMaxY(BeenCaculatedMapRect)
            MinX = MKMapRectGetMinX(BeenCaculatedMapRect)
            MinY = MKMapRectGetMinY(BeenCaculatedMapRect)
            //
            let heatmaprect = newPoint.MapRect
            let tMaxX = MKMapRectGetMaxX(heatmaprect)
            let tMaxY = MKMapRectGetMaxY(heatmaprect)
            let tMinX = MKMapRectGetMinX(heatmaprect)
            let tMinY = MKMapRectGetMinY(heatmaprect)
            MaxX = (tMaxX > MaxX) ? tMaxX : MaxX
            MaxY = (tMaxY > MaxY) ? tMaxY : MaxY
            MinX = (tMinX < MinX) ? tMinX : MinX
            MinY = (tMinY < MinY) ? tMinY : MinY
        }
        else
        {
            //First Time Caculate Fitst Point Only
            let heatmaprect = newPoint.MapRect
            MaxX = MKMapRectGetMaxX(heatmaprect)
            MaxY = MKMapRectGetMaxY(heatmaprect)
            MinX = MKMapRectGetMinX(heatmaprect)
            MinY = MKMapRectGetMinY(heatmaprect)
        }
        let rect = MKMapRectMake(MinX, MinY, MaxX - MinX, MaxY - MinY)
        CaculatedMapRect = rect
    }

    init(first Heatpoint:JDHeatPoint)
    {
        super.init()
        print(#function)
        caculateMaprect(newPoint: Heatpoint)
        HeatPointsArray.append(Heatpoint)
    }
    /**
        新的點進來先放在Buffer裡，等CluseOverlay結束一並計算
    */
    func insertHeatpoint(input:JDHeatPoint)
    {
        NewHeatPointBuffer.append(input)
    }
    /**
        一個Refresh，執行一次，
        這樣不用讓Render裡的caculateRowFormData執行多次
    */
    func lauchBuffer()
    {
        print(#function)
        for newpoint in NewHeatPointBuffer
        {
            caculateMaprect(newPoint: newpoint)
            HeatPointsArray.append(newpoint)
        }
        NewHeatPointBuffer = []
        HeatPointNeedupdate = true
    }
    
}

/**
    這個類別只需要知道畫圖相關的，不用記住任何點Data
    只要交給Producer製造還給他一個RowData
 */
class JDHeatOverlayRender:MKOverlayRenderer
{
    /*
        RowData計算器
     */
    var rawdataproducer:JDRowDataProducer?
    
    var tempimage:CGImage?
    
    var transferCGRect:CGRect{
        return rect(for: overlay.boundingMapRect)
    }
    
    init(heat overlay: JDHeatOverlay) {
        super.init(overlay: overlay)
        self.alpha = 0.7
        //
        caculateRowFormData()
    }
    
    func caculateRowFormData()
    {
        guard let overlay = overlay as? JDHeatOverlay else {
            return
        }
        overlay.HeatPointNeedupdate = false
        print(#function + "\(overlay.HeatPointsArray.count)")
        var rowformArr:[RowFormHeatData] = []
        //Caculate Max heat
        var maxHeat = overlay.HeatPointsArray[0].HeatLevel
        for heatpoint in overlay.HeatPointsArray
        {
            if(heatpoint.HeatLevel > maxHeat)
            {
                maxHeat = heatpoint.HeatLevel
            }
        }
        //
        for heatpoint in overlay.HeatPointsArray
        {
            let mkmappoint = MKMapPointForCoordinate(heatpoint.coordinate)
            let GlobalCGpoint:CGPoint = self.point(for: mkmappoint)
            let localX = GlobalCGpoint.x - (transferCGRect.origin.x)
            let localY = GlobalCGpoint.y - (transferCGRect.origin.y)
            let loaclCGPoint = CGPoint(x: localX, y: localY)
            //
            let radiusinMKDistanse:Double = heatpoint.radiusInMKDistance
            let radiusmaprect = MKMapRect(origin: MKMapPoint.init(), size: MKMapSize(width: radiusinMKDistanse, height: radiusinMKDistanse))
            let radiusCGDistance = rect(for: radiusmaprect).width
            //
            let newRow:RowFormHeatData = RowFormHeatData(heatInfluence: Float(heatpoint.HeatLevel) / Float(maxHeat), localCGpoint: loaclCGPoint, radius: radiusCGDistance)
            rowformArr.append(newRow)
        }
        let cgsize = rect(for: overlay.boundingMapRect)
        rawdataproducer = JDRowDataProducer(size: cgsize.size, rowHeatData: rowformArr)
    }
    
    /**
     drawMapRect is the real meat of this class; it defines how MapKit should render this view when given a specific MKMapRect, MKZoomScale, and the CGContextRef
     */
    
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        
        guard let overlay = overlay as? JDHeatOverlay else {
            return
        }
        if(overlay.HeatPointNeedupdate)
        {
            caculateRowFormData()
        }
        
        let mapCGRect = transferCGRect
        let midPoint:CGPoint = CGPoint(x: mapCGRect.midX, y: mapCGRect.midY)
        context.saveGState()
        context.setBlendMode(CGBlendMode.exclusion)
        
        func getGrediantContextImage()->CGImage?
        {
            //More Detail
            func CreateContextOldWay()->CGImage?
            {
                guard let producer = rawdataproducer else {
                    return nil
                }
                
                let tempBuffer = malloc(producer.cgsize.width * producer.cgsize.height * 4)
                memcpy(tempBuffer, &self.rawdataproducer!.RowData, producer.BytesPerRow * producer.cgsize.height)
                defer {
                    free(tempBuffer)
                }
                
                
                let rgbColorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
                let alphabitmapinfo = CGImageAlphaInfo.premultipliedLast.rawValue
                if let contextlayer:CGContext = CGContext(data: tempBuffer, width: producer.cgsize.width, height: producer.cgsize.height, bitsPerComponent: 8, bytesPerRow: producer.BytesPerRow, space: rgbColorSpace, bitmapInfo: alphabitmapinfo)
                {
                    return contextlayer.makeImage()
                }
                
            
                print("alpha fail")
                return nil
            }
            if let oldWayCGimage = CreateContextOldWay()
            {
                UIGraphicsPopContext()
                return oldWayCGimage
            }
            return nil
        }
        
        tempimage = getGrediantContextImage()
        context.draw(tempimage!, in: mapCGRect)
    }
    
}

