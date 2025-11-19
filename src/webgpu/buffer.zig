// High-level Buffer API for WebGPU
//
// Provides a convenient struct-based interface around the low-level FFI functions.
// Buffers are the primary way to transfer data between CPU and GPU.

const std = @import("std");
const handles = @import("handles.zig");
const device = @import("device.zig");

/// High-level Buffer wrapper with metadata
pub const Buffer = struct {
    handle: handles.BufferHandle,
    size: u64,
    usage: device.BufferUsage,

    /// Create a new GPU buffer
    pub fn create(size: u64, usage: device.BufferUsage) Buffer {
        const handle = device.createBuffer(size, usage, false);
        return .{
            .handle = handle,
            .size = size,
            .usage = usage,
        };
    }

    /// Create a buffer that's immediately mapped for writing
    pub fn createMapped(size: u64, usage: device.BufferUsage) Buffer {
        const handle = device.createBuffer(size, usage, true);
        return .{
            .handle = handle,
            .size = size,
            .usage = usage,
        };
    }

    /// Write data to the buffer at a given offset
    pub fn write(self: Buffer, offset: u64, data: []const u8) void {
        device.writeBuffer(self.handle, offset, data);
    }

    /// Write typed data to the buffer
    pub fn writeTyped(self: Buffer, comptime T: type, offset: u64, data: []const T) void {
        const bytes = std.mem.sliceAsBytes(data);
        self.write(offset, bytes);
    }

    /// Destroy the buffer and free GPU resources
    pub fn destroy(self: Buffer) void {
        device.destroyBuffer(self.handle);
    }

    /// Check if buffer is valid
    pub fn isValid(self: Buffer) bool {
        return self.handle.isValid();
    }
};

/// Common buffer usage patterns as helper constructors
/// Create a storage buffer (read/write from compute shaders)
pub fn createStorageBuffer(size: u64) Buffer {
    return Buffer.create(size, .{
        .storage = true,
        .copy_dst = true,
        .copy_src = true,
    });
}

/// Create a uniform buffer (read-only shader parameters)
pub fn createUniformBuffer(size: u64) Buffer {
    return Buffer.create(size, .{
        .uniform = true,
        .copy_dst = true,
    });
}

/// Create a vertex buffer
pub fn createVertexBuffer(size: u64) Buffer {
    return Buffer.create(size, .{
        .vertex = true,
        .copy_dst = true,
    });
}

/// Create a staging buffer for reading back from GPU
pub fn createReadbackBuffer(size: u64) Buffer {
    return Buffer.create(size, .{
        .map_read = true,
        .copy_dst = true,
    });
}

/// Create a storage buffer with initial data
pub fn createStorageBufferWithData(comptime T: type, data: []const T) Buffer {
    const buffer = createStorageBuffer(@sizeOf(T) * data.len);
    buffer.writeTyped(T, 0, data);
    return buffer;
}

/// Create a uniform buffer with initial data
pub fn createUniformBufferWithData(comptime T: type, data: []const T) Buffer {
    const buffer = createUniformBuffer(@sizeOf(T) * data.len);
    buffer.writeTyped(T, 0, data);
    return buffer;
}
