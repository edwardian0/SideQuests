//
//  PPGRecording.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 27/02/2025.
//

import Foundation

    class PPGRecording: Identifiable{
        var id = UUID()
        var timestamp: Date
        var duration: Double
        var lightIntensity: Double
        var subjectID: String
        var isFavorite: Bool
        var notes = [Note]()
        var events = [Date]()
        var data = [DataPoint]()
        var uploadStatusRaw: Int = UploadStatus.waiting.rawValue
        var age: Int?
        var gender: String = ""
        var height: Int?
        var weight: Int?
        
        var uploadStatus: UploadStatus {
            get { .init(rawValue: uploadStatusRaw) ?? .waiting }
            set { uploadStatusRaw = newValue.rawValue }
        }
        
        init(
            id: UUID = UUID(),
            timestamp: Date,
            duration: Double,
            lightIntensity: Double,
            subjectID: String,
            data: [DataPoint] = [DataPoint](),
            notes: [Note] = [Note](),
            isFavorite: Bool = false,
            uploadStatusRaw: Int = UploadStatus.waiting.rawValue,
            age: Int? = nil,
            gender: String = "",
            height: Int? = nil,
            weight: Int? = nil,
            events: [Date] = []
        ) {
            self.id = id
            self.timestamp = timestamp
            self.duration = duration
            self.lightIntensity = lightIntensity
            self.data = data
            self.notes = notes
            self.subjectID = subjectID
            self.isFavorite = isFavorite
            self.uploadStatusRaw = uploadStatusRaw
            self.age = age
            self.gender = gender
            self.height = height
            self.weight = weight
            self.events = events
        }
    }


extension PPGRecording {
    
    func exportCSV() -> String {
        var builder = CSVBuilder(recording: self)
        
        builder.addTime()
        builder.addBrightness()
        builder.addRGB()
        
        return builder.makeCSV()
    }
    
    func exportFile() -> URL? {
        if let csvUrl = exportCSV().data(using: .utf8)?.toFile(filename: csvFileName()) {
            return csvUrl
        }
        return nil
    }
    
    func csvFileName() -> String {
        return fileName() + ".csv"
    }
    
    func fileName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let formattedDate = dateFormatter.string(from: timestamp)
        let id = subjectID.isEmpty ? "" : "\(subjectID)_"
        
        let fileName = "PPG_\(id)\(formattedDate)"
        return fileName
    }
}

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var value: String
}

enum UploadStatus: Int, Codable {
    case waiting
    case success
    case inProgress
    case failure
}
