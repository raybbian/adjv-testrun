//
//  H264Unit.swift
//  adjv
//
//  Created by Raymond Bian on 6/14/24.
//

import Foundation


struct H264Unit {
    enum NALUType {
        case sps
        case pps
        case vcl
        case ignore
    }
    
    let type: NALUType
    
    private let payload: Data
       
    /// 4 bytes data represents NAL Unit's length
    private var lengthData: Data?
       
    /// it could be
    /// - pure NALU data(if SPS or PPS)
    /// - 4 bytes length data + NALU data(if not SPS or PPS)
    var data: Data {
        if type == .vcl {
            return lengthData! + payload
        } else {
            return payload
        }
    }
    
    /// - paramter payload: pure NALU data(no length data or start code)
    init(payload: Data) {
        let typeNumber = payload[0] & 0x1F
           
        if typeNumber == 7 {
            self.type = .sps
        } else if typeNumber == 8 {
            self.type = .pps
        } else if typeNumber == 1 || typeNumber == 5 {
            self.type = .vcl
            var naluLength = UInt32(payload.count)
            naluLength = CFSwapInt32HostToBig(naluLength)
            self.lengthData = Data(bytes: &naluLength, count: 4)
        } else {
            self.type = .ignore
        }
        self.payload = payload
    }
}

let naluTypesStrings : [String] = [
    "0: Unspecified (non-VCL)",
    "1: Coded slice of a non-IDR picture (VCL)",    // P frame
    "2: Coded slice data partition A (VCL)",
    "3: Coded slice data partition B (VCL)",
    "4: Coded slice data partition C (VCL)",
    "5: Coded slice of an IDR picture (VCL)",      // I frame
    "6: Supplemental enhancement information (SEI) (non-VCL)",
    "7: Sequence parameter set (non-VCL)",         // SPS parameter
    "8: Picture parameter set (non-VCL)",          // PPS parameter
    "9: Access unit delimiter (non-VCL)",
    "10: End of sequence (non-VCL)",
    "11: End of stream (non-VCL)",
    "12: Filler data (non-VCL)",
    "13: Sequence parameter set extension (non-VCL)",
    "14: Prefix NAL unit (non-VCL)",
    "15: Subset sequence parameter set (non-VCL)",
    "16: Reserved (non-VCL)",
    "17: Reserved (non-VCL)",
    "18: Reserved (non-VCL)",
    "19: Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    "20: Coded slice extension (non-VCL)",
    "21: Coded slice extension for depth view components (non-VCL)",
    "22: Reserved (non-VCL)",
    "23: Reserved (non-VCL)",
    "24: STAP-A Single-time aggregation packet (non-VCL)",
    "25: STAP-B Single-time aggregation packet (non-VCL)",
    "26: MTAP16 Multi-time aggregation packet (non-VCL)",
    "27: MTAP24 Multi-time aggregation packet (non-VCL)",
    "28: FU-A Fragmentation unit (non-VCL)",
    "29: FU-B Fragmentation unit (non-VCL)",
    "30: Unspecified (non-VCL)",
    "31: Unspecified (non-VCL)",
]
