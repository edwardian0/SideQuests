import Foundation
import os.log

extension Data {
    func toFile(filename: String) -> URL?{
        let path = documentsDirectory().appendingPathComponent(filename)
        
        do {
            try self.write(to: path)
            return path
        }catch {
            logger.error("failed to convert data into file - filename: \(filename)")
        }
        
        return nil
    }
    
    private func documentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

fileprivate let logger = Logger(subsystem: "PPG Research App", category: "Data Extension")
