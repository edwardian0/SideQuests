//
//  StringExtensions.swift
//  PPGResearchApp
//
//  Created by Bartosz Pietyra on 21/03/2025.
//

import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
