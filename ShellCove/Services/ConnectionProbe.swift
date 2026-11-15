import Darwin
import Foundation

/// 手动连通性探活（PRD 3.2）：只做一次 TCP 建连，不轮询。
enum ConnectionProbe {
    /// 返回 TCP 建连耗时（毫秒）；失败返回 nil。
    static func latency(host: String, port: Int, timeout: TimeInterval = 4) async -> Int? {
        await Task.detached(priority: .utility) {
            connectLatency(host: host, port: port, timeout: timeout)
        }.value
    }

    private static func connectLatency(host: String, port: Int, timeout: TimeInterval) -> Int? {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var results: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &results) == 0,
              let first = results else {
            return nil
        }
        defer { freeaddrinfo(results) }

        var candidate: UnsafeMutablePointer<addrinfo>? = first
        while let info = candidate {
            if let latency = connect(info.pointee, timeout: timeout) {
                return latency
            }
            candidate = info.pointee.ai_next
        }
        return nil
    }

    private static func connect(_ info: addrinfo, timeout: TimeInterval) -> Int? {
        let descriptor = socket(info.ai_family, info.ai_socktype, info.ai_protocol)
        guard descriptor >= 0 else { return nil }
        defer { Darwin.close(descriptor) }

        let flags = fcntl(descriptor, F_GETFL, 0)
        guard flags >= 0 else { return nil }
        _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)

        let started = Date()
        if Darwin.connect(descriptor, info.ai_addr, info.ai_addrlen) == 0 {
            return Int(Date().timeIntervalSince(started) * 1000)
        }
        guard errno == EINPROGRESS else { return nil }

        var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
        let ready = poll(&pollDescriptor, 1, Int32(max(0, timeout) * 1000))
        guard ready > 0 else { return nil }

        var socketError: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &socketError, &length) == 0,
              socketError == 0 else {
            return nil
        }
        return Int(Date().timeIntervalSince(started) * 1000)
    }
}
