//
//  NostrEventValueTransformer.swift
//  Comingle
//
//  Created by Terry Yiu on 7/23/24.
//

import Foundation
import NostrSDK

class NostrEventValueTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NostrEvent.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let nostrEvent = value as? NostrEvent else {
            return nil
        }

        return try? JSONEncoder().encode(nostrEvent)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            return nil
        }

        let jsonDecoder = JSONDecoder()
        guard let nostrEvent = try? jsonDecoder.decode(NostrEvent.self, from: data) else {
            return nil
        }

        // FIXME: Figure out how to decode the JSON to the appropriate subclass of NostrEvent without needing to decode twice.
        return try? jsonDecoder.decode(nostrEvent.kind.classForKind, from: data)
    }

    static func register() {
        ValueTransformer.setValueTransformer(NostrEventValueTransformer(), forName: .init("NostrEventValueTransformer"))
    }
}
