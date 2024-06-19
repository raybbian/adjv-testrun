//
//  H264Converter.swift
//  adjv
//
//  Created by Raymond Bian on 6/14/24.
//

import Foundation
import AVFoundation
import VideoToolbox

//converts h264 NAL payloads into samplebuffers, commented code for debugging the decompressor
class H264Converter {
    private var sps: H264Unit?
    private var pps: H264Unit?
    private var description: CMVideoFormatDescription?
    
    private lazy var convertingQueue = DispatchQueue.init(label: "conversion_queue", qos: .userInteractive)
    
    private var decompressionSession: VTDecompressionSession?
    
//    private var pixelBufferOutputHandler: VTDecompressionOutputHandler?
    
    var sampleBufferCallback: ((CMSampleBuffer) -> Void)?
//    var pixelBufferCallback: ((CVPixelBuffer) -> Void)?
    

//    init() {
//        pixelBufferOutputHandler = {[self] (status: OSStatus,
//                                     infoFlags: VTDecodeInfoFlags,
//                                     imageBuffer: CVPixelBuffer?,
//                                     presentationTimeStamp: CMTime,
//                                     duration: CMTime) in
//            if imageBuffer != nil && status == noErr {
//                self.pixelBufferCallback?(imageBuffer!)
//            } else {
//                print("Failed to decompress. VT Error \(status)")
//            }
//        }
//    }
    
    private func buildDescription(with h264Format: H264Unit) -> Bool {
        if h264Format.type == .sps {
            sps = h264Format
        } else if h264Format.type == .pps {
            pps = h264Format
        }
        
        //return if dont have these
        guard let sps = sps, let pps = pps else {
            return false
        }
        
        let spsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: sps.data.count)
        sps.data.copyBytes(to: spsPointer, count: sps.data.count)
        
        let ppsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: pps.data.count)
        pps.data.copyBytes(to: ppsPointer, count: pps.data.count)
        
        let parameterSet = [UnsafePointer(spsPointer), UnsafePointer(ppsPointer)]
        let parameterSetSizes = [sps.data.count, pps.data.count]
        
        defer {
            parameterSet.forEach {
                $0.deallocate()
            }
        }
        
        let error = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                                        parameterSetCount: 2,
                                                                        parameterSetPointers: parameterSet,
                                                                        parameterSetSizes: parameterSetSizes,
                                                                        nalUnitHeaderLength: 4,
                                                                        formatDescriptionOut: &description)
        
        guard error == noErr else {
            print("Failed to create format description: \(error)")
            return false
        }
        
        return true
    }
    
//    private func createDecompressionSession() -> Bool {
//        guard let desc = description else {
//            print("Cannot create decompression session without format description")
//            return false
//        }
//        
//        if let session = decompressionSession {
//            VTDecompressionSessionInvalidate(session)
//            decompressionSession = nil
//        }
//        
//        let decoderParameters = NSMutableDictionary()
//        let destinationPixelBufferAttributes = NSMutableDictionary()
//        
//        let error = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
//                                                 formatDescription: desc,
//                                                 decoderSpecification: decoderParameters,
//                                                 imageBufferAttributes: destinationPixelBufferAttributes,
//                                                 outputCallback: nil,
//                                                 decompressionSessionOut: &decompressionSession)
//        
//        guard error == noErr else {
//            print("Failed to create decompression session with error \(error)")
//            return false
//        }
//        
//        return true
//    }

    private func createBlockBuffer(with h264Format: H264Unit) -> CMBlockBuffer? {
        assert(h264Format.type == .vcl)
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: h264Format.data.count)
        
        h264Format.data.copyBytes(to: pointer, count: h264Format.data.count)
        var blockBuffer: CMBlockBuffer?
        
        let error = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                       memoryBlock: pointer,
                                                       blockLength: h264Format.data.count,
                                                       blockAllocator: kCFAllocatorDefault,
                                                       customBlockSource: nil,
                                                       offsetToData: 0,
                                                       dataLength: h264Format.data.count,
                                                       flags: .zero,
                                                       blockBufferOut: &blockBuffer)
        
        guard error == kCMBlockBufferNoErr else {
            print("Failed to create block buffer")
            return nil
        }
        
        return blockBuffer
    }
    
    private func createSampleBuffer(with blockBuffer: CMBlockBuffer) -> CMSampleBuffer? {
        var sampleBuffer : CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: .invalid,
                                            presentationTimeStamp: .zero,
                                            decodeTimeStamp: .invalid)
        
        let error = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                              dataBuffer: blockBuffer,
                                              formatDescription: description,
                                              sampleCount: 1,
                                              sampleTimingEntryCount: 1,
                                              sampleTimingArray: &timingInfo,
                                              sampleSizeEntryCount: 0,
                                              sampleSizeArray: nil,
                                              sampleBufferOut: &sampleBuffer)
        
        guard error == noErr, let sampleBuffer = sampleBuffer else {
            print("Failed to create sample buffer")
            return nil
        }
        
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                     createIfNecessary: true) {
            let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                    to: CFMutableDictionary.self)

            CFDictionarySetValue(dic,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        
        return sampleBuffer
    }
    
//    private func enqueueCreatePixelBuffer(with sampleBuffer: CMSampleBuffer) -> Bool {
//        let flagIn = VTDecodeFrameFlags._EnableAsynchronousDecompression
//        var flagOut = VTDecodeInfoFlags(rawValue: 0)
//        
//        let error = VTDecompressionSessionDecodeFrame(decompressionSession!,
//                                                  sampleBuffer: sampleBuffer,
//                                                  flags: flagIn,
//                                                  infoFlagsOut: &flagOut,
//                                                  outputHandler: pixelBufferOutputHandler!)
//        
//        guard error == noErr else {
//            print("Failed to decompress frame with error \(error)")
//            return false
//        }
//        return true
//    }
    
    func convert(_ h264Unit: H264Unit) {
        convertingQueue.async { [self] in
            if h264Unit.type == .sps || h264Unit.type == .pps {
                description = nil
                //if we are finished building the description, create decompression session
                if buildDescription(with: h264Unit) {
                    print("Built description")
//                    let _ = createDecompressionSession()
                }
                return
            }
            
            sps = nil
            pps = nil
            
            guard let blockBuffer = createBlockBuffer(with: h264Unit) else {
                return
            }
            guard let sampleBuffer = createSampleBuffer(with: blockBuffer) else {
                return
            }
            sampleBufferCallback?(sampleBuffer)
//            let _ = enqueueCreatePixelBuffer(with: sampleBuffer)
        }
    }
}
