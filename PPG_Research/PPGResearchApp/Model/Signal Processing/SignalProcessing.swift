//
//  SignalProcessing.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 10/05/2025.
//
import Foundation

struct SignalProcessing {
    static func normalizeData(input: [SimpleDataPoint]) -> [SimpleDataPoint]{
        let min = input.min {
            $0.value < $1.value
        }?.value ?? 0
        let max = input.max {
            $0.value < $1.value
        }?.value ?? 1
        
        let normalizedData = input.map {
            let dataPoint = SimpleDataPoint(time: $0.time, value: ($0.value - min) * (1 / (max - min)))
            return dataPoint
        }
        
        return normalizedData
    }
    
    static func sortData(data: [DataPoint]) -> [DataPoint] {
        return data.sorted(by: {$0.time < $1.time})
    }
    
    static func sortData(data: [SimpleDataPoint]) -> [SimpleDataPoint] {
        return data.sorted(by: {$0.time < $1.time})
    }
    
    static func interpolateSignal(raw: [DataPoint], fs: Double = 100.0) -> ([DataPoint]) {
        // Step 1: Create uniform time axis
        let dt = 1.0 / fs
        guard let tMin = raw.first?.time.timeIntervalSince1970, let tMax = raw.last?.time.timeIntervalSince1970 else {
            return ([DataPoint]())
        }

        var tUniform: [Double] = []
        var t = tMin
        
        while t < tMax {
            //round t
            t = (t * 100).rounded() / 100
            tUniform.append(t)
            
            t += dt
        }

        // Step 2: Manual linear interpolation
        var dataUniform: [DataPoint] = []
        var j = 0

        for t in tUniform {
            // Find surrounding points
            while j < raw.count - 2 && t > raw[j + 1].time.timeIntervalSince1970 {
                j += 1
            }

            let t0 = raw[j].time.timeIntervalSince1970
            let t1 = raw[j + 1].time.timeIntervalSince1970
            let yR0 = raw[j].red
            let yR1 = raw[j + 1].red
            let yG0 = raw[j].green
            let yG1 = raw[j + 1].green
            let yB0 = raw[j].blue
            let yB1 = raw[j + 1].blue
            let yW0 = raw[j].brightness
            let yW1 = raw[j + 1].brightness

            if t1 == t0 {
                dataUniform
                    .append(
                        DataPoint(time: Date(timeIntervalSince1970:t0), brightness: yW0, red: yR0, green: yG0, blue: yB0)
                    )
            } else {
                let alpha = (t - t0) / (t1 - t0)
                let yR = yR0 + alpha * (yR1 - yR0)
                let yG = yG0 + alpha * (yG1 - yG0)
                let yB = yB0 + alpha * (yB1 - yB0)
                let yW = yW0 + alpha * (yW1 - yW0)
                dataUniform.append(
                    DataPoint(time: Date(timeIntervalSince1970:t), brightness: yW, red: yR, green: yG, blue: yB)
                )
            }
        }

        return dataUniform
    }
}
