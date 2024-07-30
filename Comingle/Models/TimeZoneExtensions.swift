//
//  TimeZoneExtensions.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

import Foundation

extension TimeZone {
    private func gmtOffset(for date: Date) -> String {
        let secondsFromGMT = secondsFromGMT(for: date)
        let hours = secondsFromGMT / 3600
        let minutes = abs(secondsFromGMT % 3600 / 60)

        if minutes == 0 {
            return String(format: "GMT%+0d", hours)
        }

        return String(format: "GMT%+0d:%02d", hours, minutes)
    }

    func displayName(for date: Date) -> String {
        "(\(gmtOffset(for: date))) \(identifier)"
    }
}
