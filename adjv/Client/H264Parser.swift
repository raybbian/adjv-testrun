//
//  H264Parser.swift
//  adjv
//
//  Created by Raymond Bian on 6/14/24.
//

import Foundation

private let bufSize : Int = 65536

class H264Parser {
    //circular array
//    private var dataStream = Data(count: bufSize)
//    
//    private var startIndex = 0
//    private var endIndex = 0
//    private var searchIndex = 0
//    
//    private lazy var parsingQueue = DispatchQueue.init(label: "parsing_queue",
//                                                        qos: .userInteractive)
//    
//    var h264ExtractedCallback: ((H264Unit) -> Void)?
//    
//    func enqueue(_ data: Data) {
//        parsingQueue.async { [self] in
//            appendData(data)
//            
//            while searchIndex < endIndex - 3 {
//                let fourByteHeader = dataStream[searchIndex % bufSize] | dataStream[(searchIndex + 1) % bufSize] |
//                                     dataStream[(searchIndex + 2) % bufSize] | dataStream[(searchIndex + 3) % bufSize]
//                if fourByteHeader == 1 { //this is a start code
//                    if searchIndex > startIndex { //if not the first start code, extract the NALU
//                        let l = startIndex % bufSize
//                        let r = searchIndex % bufSize
//                        
//                        var h264Unit : H264Unit
//                        if l > r {
//                            let first = dataStream[l ..< bufSize]
//                            let second = dataStream[0 ..< r]
//                            h264Unit = H264Unit(payload: first + second)
//                        } else {
//                            h264Unit = H264Unit(payload: dataStream[l ..< r])
//                        }
//                        h264ExtractedCallback?(h264Unit)
//                        //remove the NALU
//                        startIndex = searchIndex
//                    }
//                    //remove the start code
//                    startIndex += 4
//                    searchIndex += 4
//                } else if dataStream[(searchIndex + 3) % bufSize] != 0 {
//                    searchIndex += 4
//                } else {
//                    searchIndex += 1
//                }
//            }
//        }
//    }
//    
//    private func appendData(_ data: Data) {
//        let l = endIndex % bufSize
//        let r = endIndex % bufSize + data.count
//        
//        if r >= bufSize { //packet will wrap around
//            let m = bufSize - l
//            dataStream.replaceSubrange(l ..< bufSize, with: data[data.startIndex ..< data.startIndex + m])
//            dataStream.replaceSubrange(0 ..< r - bufSize, with: data[data.startIndex + m ..< data.endIndex])
//        } else { //packet does not wrap around
//            dataStream.replaceSubrange(l ..< r, with: data)
//        }
//        endIndex += data.count
//    }
    
    private var dataStream = Data()
        
    private var searchIndex = 0
    
    private lazy var parsingQueue = DispatchQueue.init(label: "parsing.queue",
                                                    qos: .userInteractive)
    
    var h264ExtractedCallback: ((H264Unit) -> Void)?
    
    func enqueue(_ data: Data) {
        parsingQueue.async { [self] in
            dataStream.append(data)
            
            while searchIndex < dataStream.endIndex-3 {
                if dataStream[searchIndex] == 0x00 && dataStream[searchIndex+1] == 0x00 &&
                   dataStream[searchIndex+2] == 0x00 && dataStream[searchIndex+3] == 0x01 {
                    // if searchIndex is zero, that means there's nothing to extract cause
                    // we only care left side of searchIndex
                    if searchIndex != 0 {
                        let h264Unit = H264Unit(payload: dataStream[0..<searchIndex])
                        h264ExtractedCallback?(h264Unit)
                    }
                    
                    // We excute O(n) complexity operation here which is terribly inefficent.
                    // I hope you to refactor this part with more efficent way like a circular buffer.
                    dataStream.removeSubrange(0...searchIndex+3)
                    searchIndex = 0
                } else if dataStream[searchIndex+3] != 0 {
                    searchIndex += 4
                } else { // dataStream[searchIndex+3] == 0
                    searchIndex += 1
                }
            }
        }
    }
}

