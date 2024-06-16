//
//  StreamClient.swift
//  adjv
//
//  Created by Raymond Bian on 6/13/24.
//

import Foundation
import Network

class TCPClient {
    private var listener: NWListener?
    
    private lazy var listeningQueue = DispatchQueue.init(label: "tcp_server_queue")
    private lazy var connectionQueue = DispatchQueue.init(label: "connection_queue")
    
    var receivedDataCallback : ((Data) -> Void)?
    
    func start(port: NWEndpoint.Port) throws {
        listener?.cancel()
        
        listener = try NWListener.init(using: .tcp, on: port)
                
        listener?.stateUpdateHandler = { (state) in
            switch(state) {
            case .ready:
                print("Listener ready on port \(port)")
            case .failed(let error):
                print("Listener failed with error: \(error)")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { (connection) in
            print("Connection requested from \(connection.endpoint)")
            connection.stateUpdateHandler = { (state) in
                if state == .ready {
                    self.receiveData(on: connection)
                }
            }
            connection.start(queue: self.connectionQueue)
        }
        
        listener?.start(queue: listeningQueue)
    }
    
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32768) { (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                self.receivedDataCallback?(data)
            } else if let error = error {
                print("Connection error: \(error)")
            }
            
            if isComplete {
                connection.cancel()
            } else {
                self.receiveData(on: connection)
            }
        }
    }
}
