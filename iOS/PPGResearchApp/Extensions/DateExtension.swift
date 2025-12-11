import Foundation
import os.log

extension Date {
    func toWebServiceFormat() -> String{
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let output = formatter.string(from:self)
        return output
    }
}
