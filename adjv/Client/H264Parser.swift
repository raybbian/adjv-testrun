//
//  H264Parser.swift
//  adjv
//
//  Created by Raymond Bian on 6/14/24.
//

import Foundation

class H264Parser {
    private var dataBuffer = Data()
//    private var dataBuffer = CircularDataBuffer(capacity: 2 << 27)
    private var searchIndex = 0
    
    private var parsingQueue = DispatchQueue.init(label: "parsing_queue",
                                                    qos: .userInteractive)
    
    var h264ExtractedCallback: ((H264Unit) -> Void)?
    
    func enqueue(_ data: Data) {
        parsingQueue.async { [self] in
            dataBuffer.append(data)
            
            while searchIndex < dataBuffer.count-3 {
                if dataBuffer[searchIndex] == 0x00 && dataBuffer[searchIndex+1] == 0x00 &&
                   dataBuffer[searchIndex+2] == 0x00 && dataBuffer[searchIndex+3] == 0x01 {
                    // if searchIndex is zero, that means there's nothing to extract cause
                    // we only care left side of searchIndex
                    if searchIndex != 0 {
                        let h264Unit = H264Unit(payload: dataBuffer[0 ..< searchIndex])
                        h264ExtractedCallback?(h264Unit)
                    }
                    dataBuffer.removeSubrange(0 ..< searchIndex + 3)
//                    dataBuffer.consume(searchIndex + 3)
                    searchIndex = 0
                } else if dataBuffer[searchIndex+3] != 0 {
                    searchIndex += 4
                } else { // dataStream[searchIndex+3] == 0
                    searchIndex += 1
                }
            }
        }
    }
}

