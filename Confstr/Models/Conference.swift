//
//  Conference.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import Foundation

struct Conference: Hashable {
    let name: String
    let startDate: Date
    let endDate: Date
    let location: String
    let timeZone: TimeZone
    let sessions: [Session]
    let organizers: [Person]
}
