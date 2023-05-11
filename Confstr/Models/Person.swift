//
//  Person.swift
//  Confstr
//
//  Created by Terry Yiu on 5/10/23.
//

import Foundation

struct Person: Identifiable, Hashable {
    var id: String { self.nostrPublicKey }
    let nostrPublicKey: String
    let name: String
    let description: String
    let picture: String
}
