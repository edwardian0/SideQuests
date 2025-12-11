
struct CSVBuilder {
    private let recording: PPGRecording
    private let sortedData: [DataPoint]
    private var csvArray: [String]
    
    init(recording: PPGRecording) {
        self.recording = recording
        self.sortedData = SignalProcessing.sortData(data: recording.data)
        csvArray = [String](repeating: "", count: sortedData.count + 1)
    }
    
    mutating func addTime(){
        guard csvArray.count > 0 else { return }
        guard sortedData.count > 0 else { return }
        
        csvArray[0] += "time"
        let firstElement = sortedData[0]
        for dataPoint in sortedData.enumerated() {
            let timeInterval = dataPoint.element.time.timeIntervalSince(firstElement.time)
            let timeIntervalString = String(format: "%.2f", timeInterval)
            csvArray[dataPoint.offset + 1] += timeIntervalString
        }
    }
    
    mutating func addBrightness(){
        guard csvArray.count > 0 else { return }
        
        csvArray[0] += ",brightness"
        for dataPoint in sortedData.enumerated() {
            let brightness = "," + String(format: "%.8f", dataPoint.element.brightness)
            csvArray[dataPoint.offset + 1] += brightness
        }
    }
    
    mutating func addRGB(){
        guard csvArray.count > 0 else { return }
        
        csvArray[0] += ",r,g,b"
        for dataPoint in sortedData.enumerated() {
            let rgbString = ","
            + String(format: "%.8f", dataPoint.element.red) + ","
            + String(format: "%.8f", dataPoint.element.green) + ","
            + String(format: "%.8f", dataPoint.element.blue)
            csvArray[dataPoint.offset + 1] += rgbString
        }
    }
    
    func makeCSV() -> String {
        return csvArray.joined(separator: "\n")
    }
}
