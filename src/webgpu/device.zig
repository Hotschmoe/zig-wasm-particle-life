// WebGPU Device Management
//
// The device is the core WebGPU object through which we create all other resources.
// JavaScript initializes the device and passes a handle to Zig.

const std = @import("std");
const handles = @import("handles.zig");

/// Global device handle (initialized by JavaScript)
var g_device: handles.DeviceHandle = handles.DeviceHandle.invalid();

/// Initialize with a device handle from JavaScript
pub fn init(device_handle: u32) void {
    g_device = .{ .id = device_handle };
}

/// Get the current device handle
pub fn getDevice() handles.DeviceHandle {
    return g_device;
}

/// Check if device is initialized
pub fn isInitialized() bool {
    return g_device.isValid();
}

// FFI imports from JavaScript
// These will be implemented in main.js

/// Create a buffer on the GPU
extern fn js_webgpu_create_buffer(
    device: u32,
    size: u64,
    usage: u32,
    mapped_at_creation: bool,
) u32;

/// Write data to a buffer
extern fn js_webgpu_buffer_write(
    device: u32,
    buffer: u32,
    offset: u64,
    data_ptr: [*]const u8,
    data_len: usize,
) void;

/// Destroy a buffer
extern fn js_webgpu_buffer_destroy(buffer: u32) void;

/// Create a shader module from WGSL source
extern fn js_webgpu_create_shader_module(
    device: u32,
    source_ptr: [*]const u8,
    source_len: usize,
) u32;

// Buffer usage flags (matching WebGPU spec)
pub const BufferUsage = packed struct(u32) {
    map_read: bool = false,
    map_write: bool = false,
    copy_src: bool = false,
    copy_dst: bool = false,
    index: bool = false,
    vertex: bool = false,
    uniform: bool = false,
    storage: bool = false,
    indirect: bool = false,
    query_resolve: bool = false,
    _padding: u22 = 0,
};

/// Create a GPU buffer
pub fn createBuffer(size: u64, usage: BufferUsage, mapped_at_creation: bool) handles.BufferHandle {
    if (!g_device.isValid()) {
        return handles.BufferHandle.invalid();
    }

    const usage_flags = @as(u32, @bitCast(usage));
    const handle_id = js_webgpu_create_buffer(g_device.id, size, usage_flags, mapped_at_creation);

    return .{ .id = handle_id };
}

/// Write data to a buffer
pub fn writeBuffer(buffer: handles.BufferHandle, offset: u64, data: []const u8) void {
    if (!g_device.isValid() or !buffer.isValid()) {
        return;
    }

    js_webgpu_buffer_write(g_device.id, buffer.id, offset, data.ptr, data.len);
}

/// Destroy a buffer
pub fn destroyBuffer(buffer: handles.BufferHandle) void {
    if (!buffer.isValid()) {
        return;
    }

    js_webgpu_buffer_destroy(buffer.id);
}

/// Create a shader module from WGSL source
pub fn createShaderModule(source: []const u8) handles.ShaderModuleHandle {
    if (!g_device.isValid()) {
        return handles.ShaderModuleHandle.invalid();
    }

    const handle_id = js_webgpu_create_shader_module(g_device.id, source.ptr, source.len);

    return .{ .id = handle_id };
}
