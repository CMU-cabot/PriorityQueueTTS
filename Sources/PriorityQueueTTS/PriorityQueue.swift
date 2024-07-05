/*******************************************************************************
 * Copyright (c) 2024  Carnegie Mellon University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Foundation

struct PriorityQueue<T: Comparable> {
    private var heap: [T] = []

    var isEmpty: Bool {
        return heap.isEmpty
    }

    var count: Int {
        return heap.count
    }

    mutating func insert(_ element: T) {
        heap.append(element)
        siftUp(heap.count - 1)
    }

    mutating func extractMax() -> T? {
        guard !heap.isEmpty else { return nil }
        if heap.count == 1 {
            return heap.removeLast()
        } else {
            let value = heap[0]
            heap[0] = heap.removeLast()
            siftDown(0)
            return value
        }
    }

    private mutating func siftUp(_ index: Int) {
        var child = index
        var parent = (child - 1) / 2

        while child > 0 && heap[child] > heap[parent] {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(_ index: Int) {
        var parent = index
        let count = heap.count

        while true {
            let leftChild = 2 * parent + 1
            let rightChild = 2 * parent + 2
            var candidate = parent

            if leftChild < count && heap[leftChild] > heap[candidate] {
                candidate = leftChild
            }
            if rightChild < count && heap[rightChild] > heap[candidate] {
                candidate = rightChild
            }
            if candidate == parent {
                return
            }

            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}
