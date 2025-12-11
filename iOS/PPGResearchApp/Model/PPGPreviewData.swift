//
//  PreviewData.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 03/04/2025.
//

import Foundation

@Observable
class PPGPreviewData{
    
    let previewTimespanInSeconds = 5.0
    
    var recentMaxValue = 1.0
    var recentMinValue = 0.0
    var values = [SimpleDataPoint]()

    private let recentHistoryTimespanInSeconds = 2.0
    
    private var inputBuffer = [SimpleDataPoint]()
    
    func addDataPoint(_ dataPoint: DataPoint) {
        
        let simpleDataPoint = SimpleDataPoint(
            time: dataPoint.time,
            value: dataPoint
                .brightness)
        
        //use buffer to reduce UI update rate
        if inputBuffer.count < 2 {
            inputBuffer.append(simpleDataPoint)
            return
        }else {
            values.append(contentsOf: inputBuffer)
            
            inputBuffer.removeAll()
            
            calculateRecentMinMaxValues()
            
            removeOldValues()
        }
    }
    
    private func calculateRecentMinMaxValues(){
        let recentHistory = values.filter {
            $0.time > Date()
                .addingTimeInterval(-recentHistoryTimespanInSeconds)
        }
        
        recentMaxValue = recentHistory.max {
            $0.value < $1.value
        }?.value ?? 1
        
        recentMinValue = recentHistory.min {
            $0.value < $1.value
        }?.value ?? 0
        
        if recentMinValue > recentMaxValue {
            recentMinValue = 0.0
            recentMaxValue = 1.0
        }
    }
    
    private func removeOldValues(){
        
        values = values.filter {
            $0.time > Date().addingTimeInterval(-previewTimespanInSeconds)
        }
    }
    
    func clear(){
        self.values.removeAll()
    }
}
