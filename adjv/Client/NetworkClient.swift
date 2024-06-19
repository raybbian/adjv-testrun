//
//  StreamClient.swift
//  adjv
//
//  Created by Raymond Bian on 6/13/24.
//

import Foundation
import Network

class NetworkListener {
    private var listener: NWListener?
    private var connection: NWConnection?
    private var queue = DispatchQueue.init(label: "connection_queue", qos: .userInteractive)
    private var acceptingData: Bool = false
    
    var dataRecievedCallback: ((Data) -> Void)?
    
    func start(port: NWEndpoint.Port) {
        listener?.cancel()
        
        do {
            listener = try NWListener.init(using: .udp, on: port)
        } catch {
            print("Failed to create listener")
            return
        }
        
        listener?.stateUpdateHandler = { update in
            switch update {
            case .ready:
                print("Listener ready on port \(port)")
            case .failed, .cancelled:
                print("Listener disconnected from port \(port)")
            default:
                print("Listener connecting to port \(port)")
            }
        }
        
        listener?.newConnectionHandler = { connection in
            if self.connection != nil{
                print("Listener already connected to host, overriding connection")
                self.connection?.cancel()
                self.connection = nil
            } else {
                print("Listener handling new connection")
            }
            self.establishConnection(connection)
        }
        
        listener?.start(queue: .main)
    }
    
    private func establishConnection(_ connection: NWConnection) {
        self.connection = connection
        self.connection?.stateUpdateHandler = { update in
            switch update {
            case .ready:
                print("Listener ready to receive message")
                self.acceptingData = true
                self.receiveData()
            case .failed, .cancelled:
                print("Listener failed to receive message")
                self.acceptingData = false
            default:
                print("Listener waiting to receive message")
            }
        }
        
        self.connection?.start(queue: queue)
    }
    
    private func receiveData() {
        self.connection?.receive(minimumIncompleteLength: 1, maximumLength: 65507) { data, context, isComplete, error in
            guard error == nil else {
                print("Error when receiving message \(String(describing: error))")
                return
            }
            guard let data = data, !data.isEmpty else {
                print("Received nil data")
                return
            }
            
            self.dataRecievedCallback?(data)
            if self.acceptingData {
                self.receiveData()
            }
        }
    }
}
