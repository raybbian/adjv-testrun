//
//  StreamView.swift
//  adjv
//
//  Created by Raymond Bian on 6/14/24.
//

import UIKit
import AVFoundation
import SwiftUI

class StreamViewController: UIViewController {
    let streamClient = H264StreamClient()
    let layer = AVSampleBufferDisplayLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        layer.frame = view.frame
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        view.backgroundColor = .systemPink
        
        do {
            try streamClient.start(on: 8080)
            streamClient.setSampleBufferCallback({[layer] sample in
                layer.sampleBufferRenderer.enqueue(sample)
            })
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct StreamView: UIViewControllerRepresentable {
    typealias UIViewControllerType = StreamViewController

    func makeUIViewController(context: Context) -> StreamViewController {
        let view = StreamViewController()
        return view
    }
   
    func updateUIViewController(_ uiViewController: StreamViewController, context: Context) {
        //
    }
}
