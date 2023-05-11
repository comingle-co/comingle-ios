//
//  Session.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import Foundation

struct Session: Identifiable, Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String
    let name: String
    let speakers: [Person]
    let startTime: Date
    let endTime: Date
    let stage: String
    let description: String
}
