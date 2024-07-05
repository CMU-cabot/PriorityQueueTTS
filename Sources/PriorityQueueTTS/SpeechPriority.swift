//
//  File.swift
//
//
//  Created by Daisuke Sato on 7/5/24.
//

import Foundation

enum SpeechPriority: Int8 {
    typealias RawValue = Int8

    case Low = -10
    case Normal = 0
    case High = 10
    case Required = 50
}
