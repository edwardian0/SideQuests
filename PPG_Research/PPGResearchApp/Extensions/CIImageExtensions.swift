//
//  CIImageExtensions.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 25/02/2025.
//

import Foundation
import SwiftUI
import CoreImage

extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
