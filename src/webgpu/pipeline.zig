// High-level Pipeline API for WebGPU
//
// Provides convenient wrappers for creating bind groups, layouts, and pipelines.

const std = @import("std");
const handles = @import("handles.zig");
const device = @import("device.zig");
const shader = @import("shader.zig");

// === Shader Visibility Flags ===

pub const ShaderVisibility = packed struct(u32) {
    vertex: bool = false,
    fragment: bool = false,
    compute: bool = false,
    _padding: u29 = 0,

    pub const COMPUTE: u32 = 0x4; // GPUShaderStage.COMPUTE
    pub const VERTEX: u32 = 0x1; // GPUShaderStage.VERTEX
    pub const FRAGMENT: u32 = 0x2; // GPUShaderStage.FRAGMENT
};

// === Buffer Binding Types ===

pub const BufferBindingType = enum(u32) {
    uniform = 0,
    storage = 1,
    read_only_storage = 2,
};

pub const BindingType = enum(u32) {
    buffer = 0,
    texture = 1,
    sampler = 2, // For future use
};

// === Bind Group Layout ===

pub const BindGroupLayoutEntry = extern struct {
    binding: u32,
    visibility: u32,
    entry_type: u32, // 0 = buffer, 1 = texture, 2 = sampler
    buffer_type: u32, // For buffers: uniform/storage/read_only_storage
    has_min_size: u32,
    has_dynamic_offset: u32,
    min_size: u64, // u64 needs to be 8-byte aligned, moved after u32 fields
    _padding: u64, // Pad to consistent size

    /// Create buffer binding entry
    pub fn init(binding: u32, visibility: u32, buffer_type: BufferBindingType) BindGroupLayoutEntry {
        return .{
            .binding = binding,
            .visibility = visibility,
            .entry_type = @intFromEnum(BindingType.buffer),
            .buffer_type = @intFromEnum(buffer_type),
            .has_min_size = 0,
            .has_dynamic_offset = 0,
            .min_size = 0,
            ._padding = 0,
        };
    }

    /// Create texture binding entry
    pub fn initTexture(binding: u32, visibility: u32) BindGroupLayoutEntry {
        return .{
            .binding = binding,
            .visibility = visibility,
            .entry_type = @intFromEnum(BindingType.texture),
            .buffer_type = 0, // Not used for textures
            .has_min_size = 0,
            .has_dynamic_offset = 0,
            .min_size = 0,
            ._padding = 0,
        };
    }

    pub fn withMinSize(self: BindGroupLayoutEntry, min_size: u64) BindGroupLayoutEntry {
        var entry = self;
        entry.has_min_size = 1;
        entry.min_size = min_size;
        return entry;
    }

    pub fn withDynamicOffset(self: BindGroupLayoutEntry) BindGroupLayoutEntry {
        var entry = self;
        entry.has_dynamic_offset = 1;
        return entry;
    }
};

pub const BindGroupLayout = struct {
    handle: handles.BindGroupLayoutHandle,

    pub fn create(entries: []const BindGroupLayoutEntry) BindGroupLayout {
        const dev = device.getDevice();
        if (!dev.isValid()) {
            return .{ .handle = handles.BindGroupLayoutHandle.invalid() };
        }

        const handle_id = js_webgpu_create_bind_group_layout(
            dev.id,
            @intFromPtr(entries.ptr),
            entries.len,
        );

        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: BindGroupLayout) bool {
        return self.handle.isValid();
    }
};

// === Bind Group ===

pub const BindGroupEntry = extern struct {
    binding: u32,
    entry_type: u32, // 0 = buffer, 1 = texture_view
    resource_handle: u32, // Buffer handle or TextureView handle
    _padding1: u32,
    offset: u64,
    size: u64,

    /// Create buffer binding entry
    pub fn init(binding: u32, buffer_handle: handles.BufferHandle, offset: u64, size: u64) BindGroupEntry {
        return .{
            .binding = binding,
            .entry_type = 0, // buffer
            .resource_handle = buffer_handle.id,
            ._padding1 = 0,
            .offset = offset,
            .size = size,
        };
    }

    /// Create buffer binding entry (full buffer)
    pub fn initFull(binding: u32, buffer_handle: handles.BufferHandle, buffer_size: u64) BindGroupEntry {
        return init(binding, buffer_handle, 0, buffer_size);
    }

    /// Create texture view binding entry
    pub fn initTextureView(binding: u32, texture_view_handle: handles.TextureViewHandle) BindGroupEntry {
        return .{
            .binding = binding,
            .entry_type = 1, // texture_view
            .resource_handle = texture_view_handle.id,
            ._padding1 = 0,
            .offset = 0,
            .size = 0,
        };
    }
};

pub const BindGroup = struct {
    handle: handles.BindGroupHandle,

    pub fn create(layout: BindGroupLayout, entries: []const BindGroupEntry) BindGroup {
        const dev = device.getDevice();
        if (!dev.isValid() or !layout.isValid()) {
            return .{ .handle = handles.BindGroupHandle.invalid() };
        }

        const handle_id = js_webgpu_create_bind_group(
            dev.id,
            layout.handle.id,
            @intFromPtr(entries.ptr),
            entries.len,
        );

        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: BindGroup) bool {
        return self.handle.isValid();
    }
};

// === Pipeline Layout ===

pub const PipelineLayout = struct {
    handle: handles.PipelineLayoutHandle,

    pub fn create(bind_group_layouts: []const BindGroupLayout) PipelineLayout {
        const dev = device.getDevice();
        if (!dev.isValid()) {
            return .{ .handle = handles.PipelineLayoutHandle.invalid() };
        }

        // Extract handle IDs
        var layout_ids: [8]u32 = undefined; // Support up to 8 bind group layouts
        const count = @min(bind_group_layouts.len, layout_ids.len);

        for (bind_group_layouts[0..count], 0..) |layout, i| {
            layout_ids[i] = layout.handle.id;
        }

        const handle_id = js_webgpu_create_pipeline_layout(
            dev.id,
            @intFromPtr(&layout_ids),
            count,
        );

        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: PipelineLayout) bool {
        return self.handle.isValid();
    }
};

// === Compute Pipeline ===

pub const ComputePipeline = struct {
    handle: handles.ComputePipelineHandle,

    pub fn create(
        layout: PipelineLayout,
        shader_module: shader.ShaderModule,
        entry_point: []const u8,
    ) ComputePipeline {
        const dev = device.getDevice();
        if (!dev.isValid() or !layout.isValid() or !shader_module.isValid()) {
            return .{ .handle = handles.ComputePipelineHandle.invalid() };
        }

        const handle_id = js_webgpu_create_compute_pipeline(
            dev.id,
            layout.handle.id,
            shader_module.handle.id,
            entry_point.ptr,
            entry_point.len,
        );

        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn isValid(self: ComputePipeline) bool {
        return self.handle.isValid();
    }
};

// === FFI Declarations ===

extern fn js_webgpu_create_bind_group_layout(
    device: u32,
    entries_ptr: usize,
    entries_len: usize,
) u32;

extern fn js_webgpu_create_bind_group(
    device: u32,
    layout: u32,
    entries_ptr: usize,
    entries_len: usize,
) u32;

extern fn js_webgpu_create_pipeline_layout(
    device: u32,
    layouts_ptr: usize,
    layouts_len: usize,
) u32;

extern fn js_webgpu_create_compute_pipeline(
    device: u32,
    layout: u32,
    shader: u32,
    entry_point_ptr: [*]const u8,
    entry_point_len: usize,
) u32;
