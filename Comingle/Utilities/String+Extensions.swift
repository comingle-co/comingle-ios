//
//  String+Extensions.swift
//  Comingle
//
//  Created by Terry Yiu on 8/3/24.
//

import Foundation

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
