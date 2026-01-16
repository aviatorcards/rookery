// DataStructures.swift
// Common Swift Data Structures and Algorithms

import Foundation

// MARK: - Stack Implementation

/// Generic stack using copy-on-write semantics
struct Stack<Element> {
    private var elements: [Element] = []

    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }
    var top: Element? { elements.last }

    mutating func push(_ element: Element) {
        elements.append(element)
    }

    @discardableResult
    mutating func pop() -> Element? {
        elements.popLast()
    }

    func peek() -> Element? {
        elements.last
    }
}

extension Stack: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Element...) {
        self.elements = elements
    }
}

extension Stack: Sequence {
    func makeIterator() -> AnyIterator<Element> {
        var index = elements.count - 1
        return AnyIterator {
            guard index >= 0 else { return nil }
            defer { index -= 1 }
            return self.elements[index]
        }
    }
}

// MARK: - Queue Implementation

/// Generic queue with O(1) enqueue and amortized O(1) dequeue
struct Queue<Element> {
    private var inbox: [Element] = []
    private var outbox: [Element] = []

    var isEmpty: Bool { inbox.isEmpty && outbox.isEmpty }
    var count: Int { inbox.count + outbox.count }

    var front: Element? {
        outbox.last ?? inbox.first
    }

    mutating func enqueue(_ element: Element) {
        inbox.append(element)
    }

    @discardableResult
    mutating func dequeue() -> Element? {
        if outbox.isEmpty {
            outbox = inbox.reversed()
            inbox.removeAll()
        }
        return outbox.popLast()
    }
}

extension Queue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Element...) {
        inbox = elements
    }
}

// MARK: - Linked List

/// Doubly linked list implementation
final class LinkedList<Element> {
    final class Node {
        var value: Element
        var next: Node?
        weak var previous: Node?

        init(_ value: Element) {
            self.value = value
        }
    }

    private(set) var head: Node?
    private(set) var tail: Node?
    private(set) var count: Int = 0

    var isEmpty: Bool { head == nil }
    var first: Element? { head?.value }
    var last: Element? { tail?.value }

    func append(_ value: Element) {
        let node = Node(value)
        if let tail = tail {
            tail.next = node
            node.previous = tail
            self.tail = node
        } else {
            head = node
            tail = node
        }
        count += 1
    }

    func prepend(_ value: Element) {
        let node = Node(value)
        if let head = head {
            head.previous = node
            node.next = head
            self.head = node
        } else {
            head = node
            tail = node
        }
        count += 1
    }

    func remove(_ node: Node) -> Element {
        let prev = node.previous
        let next = node.next

        if let prev = prev {
            prev.next = next
        } else {
            head = next
        }

        if let next = next {
            next.previous = prev
        } else {
            tail = prev
        }

        node.previous = nil
        node.next = nil
        count -= 1

        return node.value
    }

    @discardableResult
    func removeFirst() -> Element? {
        guard let head = head else { return nil }
        return remove(head)
    }

    @discardableResult
    func removeLast() -> Element? {
        guard let tail = tail else { return nil }
        return remove(tail)
    }
}

extension LinkedList: Sequence {
    func makeIterator() -> AnyIterator<Element> {
        var current = head
        return AnyIterator {
            defer { current = current?.next }
            return current?.value
        }
    }
}

// MARK: - Binary Heap (Priority Queue)

/// Min-heap implementation for priority queue
struct Heap<Element> {
    private var elements: [Element] = []
    private let comparator: (Element, Element) -> Bool

    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }
    var peek: Element? { elements.first }

    init(comparator: @escaping (Element, Element) -> Bool) {
        self.comparator = comparator
    }

    mutating func insert(_ element: Element) {
        elements.append(element)
        siftUp(from: elements.count - 1)
    }

    @discardableResult
    mutating func extract() -> Element? {
        guard !elements.isEmpty else { return nil }

        if elements.count == 1 {
            return elements.removeLast()
        }

        let root = elements[0]
        elements[0] = elements.removeLast()
        siftDown(from: 0)
        return root
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2

        while child > 0 && comparator(elements[child], elements[parent]) {
            elements.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index

        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent

            if left < elements.count && comparator(elements[left], elements[candidate]) {
                candidate = left
            }

            if right < elements.count && comparator(elements[right], elements[candidate]) {
                candidate = right
            }

            if candidate == parent { return }

            elements.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

extension Heap where Element: Comparable {
    /// Create a min-heap
    static func minHeap() -> Heap<Element> {
        Heap { $0 < $1 }
    }

    /// Create a max-heap
    static func maxHeap() -> Heap<Element> {
        Heap { $0 > $1 }
    }
}

// MARK: - LRU Cache

/// Least Recently Used cache with O(1) operations
final class LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var cache: [Key: LinkedList<(Key, Value)>.Node] = [:]
    private let list = LinkedList<(Key, Value)>()

    init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be positive")
        self.capacity = capacity
    }

    subscript(key: Key) -> Value? {
        get { get(key) }
        set {
            if let value = newValue {
                set(key, value: value)
            } else {
                remove(key)
            }
        }
    }

    func get(_ key: Key) -> Value? {
        guard let node = cache[key] else { return nil }

        // Move to front (most recently used)
        let value = list.remove(node)
        list.prepend(value)
        cache[key] = list.head

        return value.1
    }

    func set(_ key: Key, value: Value) {
        if let node = cache[key] {
            // Update existing
            _ = list.remove(node)
        } else if cache.count >= capacity {
            // Evict least recently used
            if let lru = list.tail {
                cache.removeValue(forKey: lru.value.0)
                _ = list.removeLast()
            }
        }

        list.prepend((key, value))
        cache[key] = list.head
    }

    func remove(_ key: Key) {
        guard let node = cache[key] else { return }
        _ = list.remove(node)
        cache.removeValue(forKey: key)
    }

    var count: Int { cache.count }
}

// MARK: - Trie (Prefix Tree)

/// Trie for efficient string prefix operations
final class Trie {
    final class Node {
        var children: [Character: Node] = [:]
        var isEndOfWord = false
        var count = 0  // Number of words with this prefix
    }

    private let root = Node()

    func insert(_ word: String) {
        var current = root
        for char in word {
            if current.children[char] == nil {
                current.children[char] = Node()
            }
            current = current.children[char]!
            current.count += 1
        }
        current.isEndOfWord = true
    }

    func contains(_ word: String) -> Bool {
        guard let node = findNode(word) else { return false }
        return node.isEndOfWord
    }

    func hasPrefix(_ prefix: String) -> Bool {
        findNode(prefix) != nil
    }

    func wordsWithPrefix(_ prefix: String) -> [String] {
        guard let node = findNode(prefix) else { return [] }
        var results: [String] = []
        collectWords(from: node, prefix: prefix, results: &results)
        return results
    }

    func countWithPrefix(_ prefix: String) -> Int {
        findNode(prefix)?.count ?? 0
    }

    private func findNode(_ prefix: String) -> Node? {
        var current = root
        for char in prefix {
            guard let next = current.children[char] else { return nil }
            current = next
        }
        return current
    }

    private func collectWords(from node: Node, prefix: String, results: inout [String]) {
        if node.isEndOfWord {
            results.append(prefix)
        }
        for (char, child) in node.children {
            collectWords(from: child, prefix: prefix + String(char), results: &results)
        }
    }
}

// MARK: - Graph

/// Adjacency list graph implementation
struct Graph<Vertex: Hashable> {
    private var adjacencyList: [Vertex: Set<Vertex>] = [:]

    var vertices: Set<Vertex> {
        Set(adjacencyList.keys)
    }

    mutating func addVertex(_ vertex: Vertex) {
        if adjacencyList[vertex] == nil {
            adjacencyList[vertex] = []
        }
    }

    mutating func addEdge(from source: Vertex, to destination: Vertex) {
        addVertex(source)
        addVertex(destination)
        adjacencyList[source]?.insert(destination)
    }

    func neighbors(of vertex: Vertex) -> Set<Vertex> {
        adjacencyList[vertex] ?? []
    }

    /// Breadth-first search
    func bfs(from start: Vertex, visit: (Vertex) -> Void) {
        var visited: Set<Vertex> = []
        var queue = Queue<Vertex>()
        queue.enqueue(start)
        visited.insert(start)

        while let vertex = queue.dequeue() {
            visit(vertex)
            for neighbor in neighbors(of: vertex) {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.enqueue(neighbor)
                }
            }
        }
    }

    /// Depth-first search
    func dfs(from start: Vertex, visit: (Vertex) -> Void) {
        var visited: Set<Vertex> = []

        func dfsHelper(_ vertex: Vertex) {
            visited.insert(vertex)
            visit(vertex)
            for neighbor in neighbors(of: vertex) {
                if !visited.contains(neighbor) {
                    dfsHelper(neighbor)
                }
            }
        }

        dfsHelper(start)
    }

    /// Find shortest path using BFS
    func shortestPath(from start: Vertex, to end: Vertex) -> [Vertex]? {
        var visited: Set<Vertex> = [start]
        var queue = Queue<Vertex>()
        var parent: [Vertex: Vertex] = [:]

        queue.enqueue(start)

        while let vertex = queue.dequeue() {
            if vertex == end {
                // Reconstruct path
                var path: [Vertex] = [end]
                var current = end
                while let prev = parent[current] {
                    path.append(prev)
                    current = prev
                }
                return path.reversed()
            }

            for neighbor in neighbors(of: vertex) {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    parent[neighbor] = vertex
                    queue.enqueue(neighbor)
                }
            }
        }

        return nil
    }
}

// MARK: - Usage Examples

func dataStructureExamples() {
    // Stack example
    var stack: Stack<Int> = [1, 2, 3]
    stack.push(4)
    print("Stack top: \(stack.pop() ?? -1)")  // 4

    // Queue example
    var queue: Queue<String> = ["first", "second"]
    queue.enqueue("third")
    print("Queue front: \(queue.dequeue() ?? "")")  // first

    // Heap example
    var heap = Heap<Int>.minHeap()
    [5, 3, 8, 1, 2].forEach { heap.insert($0) }
    print("Min element: \(heap.extract() ?? -1)")  // 1

    // LRU Cache example
    let cache = LRUCache<String, Int>(capacity: 3)
    cache["a"] = 1
    cache["b"] = 2
    cache["c"] = 3
    _ = cache["a"]  // Access 'a' to make it recently used
    cache["d"] = 4  // This evicts 'b' (least recently used)
    print("Cache has 'b': \(cache["b"] != nil)")  // false

    // Trie example
    let trie = Trie()
    ["apple", "app", "application", "banana"].forEach { trie.insert($0) }
    print("Words with 'app': \(trie.wordsWithPrefix("app"))")

    // Graph example
    var graph = Graph<String>()
    graph.addEdge(from: "A", to: "B")
    graph.addEdge(from: "A", to: "C")
    graph.addEdge(from: "B", to: "D")
    graph.addEdge(from: "C", to: "D")

    print("BFS from A:")
    graph.bfs(from: "A") { print($0, terminator: " ") }
    print()

    if let path = graph.shortestPath(from: "A", to: "D") {
        print("Shortest path A->D: \(path.joined(separator: " -> "))")
    }
}
