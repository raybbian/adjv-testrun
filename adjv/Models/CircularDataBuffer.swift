//
//  CircularDataBuffer.swift
//  adjv
//
//  Created by Raymond Bian on 6/18/24.
//

import Foundation

class CircularDataBuffer {
    private var capacity: UInt
    private var bufferAddress: vm_address_t = 0
    private var virtualAddress: vm_address_t = 0
    private var dataBuffer: Data?
    private var _startIndex: Data.Index
    
    var count: Int
    var startIndex: Data.Index {
        return _startIndex % Int(capacity)
    }
    var endIndex: Data.Index {
        return startIndex + Int(count)
    }
    
    init(capacity: UInt) {
        self.capacity = capacity
        
        _startIndex = 0
        count = 0
        
        ///allocate 2x space
        var result = vm_allocate(mach_task_self_, &bufferAddress, capacity * 2, VM_FLAGS_ANYWHERE)
        
        guard result == KERN_SUCCESS else {
            preconditionFailure("Failed to create circular buffer")
        }
        
        ///deallocate back half to make way for virtual memory region
        result = vm_deallocate(mach_task_self_, bufferAddress + capacity, capacity)
        
        guard result == KERN_SUCCESS else {
            vm_deallocate(mach_task_self_, bufferAddress, capacity)
            preconditionFailure("Failed to deallocate second half")
        }
        
        virtualAddress = bufferAddress + capacity
        var cur_prot: vm_prot_t = 0
        var max_prot: vm_prot_t = 0
        result = vm_remap(mach_task_self_,
                          &virtualAddress, ///mirror target
                          capacity,        ///size of mirror
                          0,               ///auto alignment
                          0,               ///force remapping to virtual address
                          mach_task_self_, ///same task
                          bufferAddress,   ///mirror source
                          0,               ///map read-write, not copy
                          &cur_prot,
                          &max_prot,
                          VM_INHERIT_DEFAULT)
        
        guard result == KERN_SUCCESS else {
            vm_deallocate(mach_task_self_, bufferAddress, capacity)
            preconditionFailure("Failed to map memory: \(result)")
        }
        
        guard bufferAddress + capacity == virtualAddress else {
            vm_deallocate(mach_task_self_, virtualAddress, capacity)
            vm_deallocate(mach_task_self_, bufferAddress, capacity)
            preconditionFailure("Failed to create memory contiguously")
        }
        
        dataBuffer = Data(bytesNoCopy: UnsafeMutableRawPointer(bitPattern: bufferAddress)!, count: Int(capacity) * 2, deallocator: .none)
    }
    
    func append(_ data: Data) {
        precondition(count + data.count < capacity, "Circular buffer is full!")
        dataBuffer?.replaceSubrange(endIndex ..< endIndex + data.count, with: data)
        count += data.count
    }
    
    func consume(_ amount: Int) {
        precondition(count - amount >= 0, "Circular buffer would be empty!")
        _startIndex += Int(amount)
        count -= amount
    }
    
    subscript(key: Data.Index) -> UInt8 {
        get {
            return dataBuffer![self.startIndex + key]
        }
        set(byte) {
            dataBuffer![self.startIndex + key] = byte
        }
    }
    
    subscript(range: Range<Data.Index>) -> Data {
        get {
            return dataBuffer![startIndex + range.lowerBound ..< startIndex + range.upperBound]
        }
    }
    
    deinit {
        vm_deallocate(mach_task_self_, bufferAddress, capacity * 2)
    }
}
