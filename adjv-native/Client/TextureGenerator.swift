//
//  MTLTextureGenerator.swift
//  adjv-native
//
//  Created by Raymond Bian on 6/16/24.
//

import Foundation
import MetalKit

class TextureGenerator {
    private var imageWidth: Int
    private var imageHeight: Int
    private var bytesPerPixel: Int
    private var rowsPerPacket: Int
    
    private var device: MTLDevice
    private var textureDescriptor: MTLTextureDescriptor
    private var lastRowProcessed: Int
    private var builderQueue = DispatchQueue.init(label: "buider_queue", qos: .userInitiated)
    
    var texture: MTLTexture
    var onTextureBuiltCallback: (() -> Void)?
    
    init(width: Int, height: Int, bytesPerPixel: Int, rowsPerPacket: Int, device: MTLDevice) {
        imageWidth = width
        imageHeight = height
        self.bytesPerPixel = bytesPerPixel
        self.device = device
        self.rowsPerPacket = rowsPerPacket
        lastRowProcessed = -rowsPerPacket
        
        textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                     width: imageWidth,
                                                                     height: imageHeight,
                                                                     mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        texture = device.makeTexture(descriptor: textureDescriptor)!
    }
    
    func process(data: Data) {
        ///first two bytes are row number identifier
        let row = Int(data[0]) | (Int(data[1]) << 8)
        
        ///draw texture if finished building
        if lastRowProcessed > row {
            onTextureBuiltCallback?()
        } else if lastRowProcessed != row - rowsPerPacket {
            print("Missed rows \(lastRowProcessed + rowsPerPacket) to \(row - 1)")
        }
        
        builderQueue.async { [self] in
            data[2 ..< data.count].withUnsafeBytes { pointer in
                texture.replace(region: MTLRegionMake2D(0, row, imageWidth, rowsPerPacket),
                                mipmapLevel: 0,
                                withBytes: pointer.baseAddress!,
                                bytesPerRow: imageWidth * bytesPerPixel)
            }
        }
        
        lastRowProcessed = row
    }
}
