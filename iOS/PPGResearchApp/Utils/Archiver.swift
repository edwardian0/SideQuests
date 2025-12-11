//
//  Archiver.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 16/05/2025.
//

import Foundation
import Compression
import ZIPFoundation

struct Archiver {
    
    static func clearTempFolder(){
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            print("Temporary directory cleared.")
        } catch {
            print("Failed to clear temp directory: \(error)")
        }
    }
    
    static func createZip(with files: [(name: String, url: URL?)], zipFileURL: URL) throws {
        let archive = try Archive(url: zipFileURL, accessMode: .create)
        
        for file in files {
            if let url = file.url {
                try archive.addEntry(with: file.name, fileURL: url)
            }
        }
    }
}



