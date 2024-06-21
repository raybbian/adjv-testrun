//
//  StreamView.swift
//  adjv-native
//
//  Created by Raymond Bian on 6/16/24.
//

import Foundation
import MetalKit
import SwiftUI
import Network

let streamWidth = 1280
let streamHeight = 800

class MTKViewController: UIViewController, MTKViewDelegate {
    
    /// Metal texture to be drawn whenever the view controller is asked to render its view.
    
    private var metalView: MTKView!
    private var device = MTLCreateSystemDefaultDevice()
    private var commandQueue: MTLCommandQueue?
    private var renderPipelineState: MTLRenderPipelineState?
    private var texture: MTLTexture?

    private var networkListener: NetworkListener!
    private var textureGenerator: TextureGenerator!

    override public func loadView() {
        super.loadView()
        assert(device != nil, "Failed creating a default system Metal device. Please, make sure Metal is available on your hardware.")
        
        initializeMetalView()
        initializeRenderPipelineState()
        
        networkListener = NetworkListener()
        textureGenerator = TextureGenerator(width: streamWidth, height: streamHeight, bytesPerPixel: 4, rowsPerPacket: 8, device: device!)
        
        networkListener.start(port: NWEndpoint.Port(8080))
        networkListener.dataRecievedCallback = { data in
            self.textureGenerator.process(data: data)
        }
        
        textureGenerator.onTextureBuiltCallback = {
            self.draw(in: self.metalView)
        }
        self.texture = textureGenerator.texture
        
        commandQueue = device?.makeCommandQueue()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// need implement?
    }
    
    public func draw(in view: MTKView) {
        guard let texture = texture, let _ = device else {
            return
        }
    
        let commandBuffer = commandQueue!.makeCommandBuffer()!
        guard let currentRenderPassDescriptor = view.currentRenderPassDescriptor,
              let currentDrawable = view.currentDrawable,
              let renderPipelineState = renderPipelineState else {
            return
        }
        
        currentRenderPassDescriptor.renderTargetWidth = streamWidth
        currentRenderPassDescriptor.renderTargetHeight = streamHeight
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)!
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }

    private func initializeMetalView() {
        metalView = MTKView(frame: CGRect(x: 0, y: 0, width: streamWidth, height: streamWidth), device: device)
        metalView.delegate = self
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.contentScaleFactor = UIScreen.main.scale
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = false
        view.insertSubview(metalView, at: 0)
    }
    
    /// initializes render pipeline state with a default vertex function mapping texture to the view's frame and a simple fragment function returning texture pixel's value.
    private func initializeRenderPipelineState() {
        guard let device = device, let library = device.makeDefaultLibrary() else {
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.rasterSampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        /// Vertex function to map the texture to the view controller's view
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        /// Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
    }
}

struct StreamView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MTKViewController

    func makeUIViewController(context: Context) -> MTKViewController {
        let view = MTKViewController()
        return view
    }
   
    func updateUIViewController(_ uiViewController: MTKViewController, context: Context) {
        //
    }
}
