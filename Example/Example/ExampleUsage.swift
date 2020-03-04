//
//  ExampleUsage.swift
//  Example
//
//  Created by Cyrus Ingraham on 3/2/20.
//  Copyright © 2020 Jamf. All rights reserved.
//

import Foundation
import Subprocess

class ExampleUsage {
    
    func getIsSIPEnabled() throws -> Bool {
        return try Shell(["/usr/bin/csrutil", "status"]).exec(encoding: .utf8) {
            $0.value.components(separatedBy: .newlines).first(where: {
                $0.contains("System Integrity Protection status")
            })?.contains("enabled") ?? false
        }
        
    }
}
