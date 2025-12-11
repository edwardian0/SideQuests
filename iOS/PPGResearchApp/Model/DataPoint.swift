
import Foundation
import SwiftUI
import SwiftData

struct DataPoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Date
    var brightness: Double
    var red: Double
    var green: Double
    var blue: Double
    
    init(
        time: Date,
        brightness: Double,
        red: Double,
        green: Double,
        blue: Double,
        quality: Double = 0.0
    ) {
        self.time = time
        self.brightness = brightness
        self.red = red
        self.green = green
        self.blue = blue
    }
    
    init(simpleDataPoint: SimpleDataPoint){
        self.time = simpleDataPoint.time
        self.brightness = simpleDataPoint.value
        self.red = 0.0
        self.green = 0.0
        self.blue = 0.0
    }
}

struct SimpleDataPoint: Codable, Identifiable, Hashable{
    var id = UUID()
    var time: Date
    var value: Double
    
    init(time: Date, value: Double) {
        self.time = time
        self.value = value
    }
    
    init(value: Double) {
        self.time = Date()
        self.value = value
    }
    
    init(dataPoint: DataPoint){
        self.time = dataPoint.time
        self.value = dataPoint.brightness
    }
}
