//
//  H264StreamClient.swift
//  adjv
//
//  Created by Raymond Bian on 6/14/24.
//

import Foundation
import Network
import AVFoundation

class H264StreamClient {
    private let networkListener = NetworkListener()
    private let h264Parser = H264Parser()
    private let h264Converter = H264Converter()
    
    func start(on port: NWEndpoint.Port) throws {
        networkListener.start(port: port)
        networkListener.dataRecievedCallback = { [h264Parser] data in
            h264Parser.enqueue(data)
        }
        h264Parser.h264ExtractedCallback = { [h264Converter] h264Unit in
            guard h264Unit.type != .ignore else {
                return
            }
            h264Converter.convert(h264Unit)
        }
    }
    
    func setSampleBufferCallback(_ callback: @escaping (CMSampleBuffer) -> Void) {
        h264Converter.sampleBufferCallback = callback
    }
    
//    func setPixelBufferCallback(_ callback: @escaping (CVPixelBuffer) -> Void) {
//        h264Converter.pixelBufferCallback = callback
//    }
}
