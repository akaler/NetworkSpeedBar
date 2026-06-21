import Darwin
import Foundation

/// Reads simple system-level sensors (free memory).
///
/// Memory info uses public Mach APIs. Callers should handle nil gracefully
/// (e.g. hide the row or show "N/A").
enum SystemMonitor {

    // MARK: - Memory

    struct MemoryStatus {
        let totalBytes: UInt64
        let freeBytes: UInt64

        var usedBytes: UInt64 { totalBytes - freeBytes }
    }

    static func memoryStatus() -> MemoryStatus? {
        guard let total = totalMemoryBytes(), let free = freeMemoryBytes() else { return nil }
        return MemoryStatus(totalBytes: total, freeBytes: free)
    }

    private static func totalMemoryBytes() -> UInt64? {
        var size: UInt64 = 0
        var len = size_t(MemoryLayout<UInt64>.size)
        guard sysctlbyname("hw.memsize", &size, &len, nil, 0) == 0 else { return nil }
        return size
    }

    private static func freeMemoryBytes() -> UInt64? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return UInt64(stats.free_count) * UInt64(vm_page_size)
    }

}


