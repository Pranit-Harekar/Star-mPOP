//
//  Adapted from Communication.swift
//  Swift SDK
//
//  Created by Yuji on 2015/**/**.
//  Copyright © 2015年 Star Micronics. All rights reserved.
//

import Foundation

typealias SendCompletionHandler = (_ communicationResult: CommunicationResult) -> Void

class CommunicationResult {
    var result: Result
    var code: Int
    
    init(_ result: Result, _ code: Int) {
        self.result = result
        self.code = code
    }
}

enum Result {
    case success
    case errorOpenPort
    case errorBeginCheckedBlock
    case errorEndCheckedBlock
    case errorWritePort
    case errorReadPort
    case errorUnknown
}

let sm_true:  UInt32 = 1     // SM_TRUE
let sm_false: UInt32 = 0     // SM_FALSE

class StarCommunicationUtils {
    static func sendCommands(_ commands: Data!, port: SMPort!, _ completionHandler: SendCompletionHandler?) -> Bool {
        var result: Result = .errorOpenPort
        var code: Int = SMStarIOResultCodeFailedError
        
        var commandsArray: [UInt8] = [UInt8](repeating: 0, count: commands.count)
        
        commands.copyBytes(to: &commandsArray, count: commands.count)
        
        while true {
            do {
                if port == nil {
                    break
                }
                
                var printerStatus: StarPrinterStatus_2 = StarPrinterStatus_2()
                
                result = .errorBeginCheckedBlock
                
                try port.beginCheckedBlock(starPrinterStatus: &printerStatus, level: 2)
                
                if printerStatus.offline == sm_true {
                    break
                }
                
                result = .errorWritePort
                
                let startDate: Date = Date()
                
                var total: UInt32 = 0
                
                while total < UInt32(commands.count) {
                    var written: UInt32 = 0
                    
                    try port.write(writeBuffer: commandsArray, offset: total, size: UInt32(commands.count) - total, numberOfBytesWritten: &written)
                    
                    total += written
                    
                    if Date().timeIntervalSince(startDate) >= 30.0 {     // 30000mS!!!
                        break
                    }
                }
                
                if total < UInt32(commands.count) {
                    break
                }
                
                port.endCheckedBlockTimeoutMillis = 30000     // 30000mS!!!
                
                result = .errorEndCheckedBlock
                
                try port.endCheckedBlock(starPrinterStatus: &printerStatus, level: 2)
                
                if printerStatus.offline == sm_true {
                    break
                }
                
                result = .success
                code = SMStarIOResultCodeSuccess
                
                break
            }
            catch let error as NSError {
                code = error.code
                break
            }
        }
        
        if completionHandler != nil {
            completionHandler!(CommunicationResult(result, code))
        }
        
        return result == .success
    }
}

