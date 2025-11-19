// WebGPU Texture Management
//
// Handles texture creation, views, and lifetime management

const std = @import("std");
const handles = @import("handles.zig");
const device = @import("device.zig");

/// Texture formats supported by WebGPU
pub const TextureFormat = enum(u32) {
    // HDR formats
    rgba16float = 0,
    rgba32float = 1,

    // Standard formats
    bgra8unorm = 2,
    rgba8unorm = 3,
    rgba8unorm_srgb = 4,

    // Depth/stencil
    depth24plus = 5,
    depth32float = 6,

    pub fn toString(self: TextureFormat) []const u8 {
        return switch (self) {
            .rgba16float => "rgba16float",
            .rgba32float => "rgba32float",
            .bgra8unorm => "bgra8unorm",
            .rgba8unorm => "rgba8unorm",
            .rgba8unorm_srgb => "rgba8unorm-srgb",
            .depth24plus => "depth24plus",
            .depth32float => "depth32float",
        };
    }
};

/// Texture usage flags (bitfield)
pub const TextureUsage = packed struct(u32) {
    copy_src: bool = false,
    copy_dst: bool = false,
    texture_binding: bool = false,
    storage_binding: bool = false,
    render_attachment: bool = false,
    _padding: u27 = 0,

    pub fn toU32(self: TextureUsage) u32 {
        return @bitCast(self);
    }
};

/// Texture dimension types
pub const TextureDimension = enum(u32) {
    dimension_1d = 0,
    dimension_2d = 1,
    dimension_3d = 2,
};

/// Texture wrapper with metadata
pub const Texture = struct {
    handle: handles.TextureHandle,
    width: u32,
    height: u32,
    format: TextureFormat,

    pub fn isValid(self: Texture) bool {
        return self.handle.isValid();
    }

    /// Create a 2D texture
    pub fn create(
        width: u32,
        height: u32,
        format: TextureFormat,
        usage: TextureUsage,
    ) Texture {
        const handle_id = js_webgpu_create_texture(
            device.getDevice().id,
            width,
            height,
            @intFromEnum(format),
            usage.toU32(),
        );

        return Texture{
            .handle = .{ .id = handle_id },
            .width = width,
            .height = height,
            .format = format,
        };
    }

    /// Create a texture view (for binding to pipelines)
    pub fn createView(self: Texture) TextureView {
        if (!self.isValid()) {
            return TextureView{
                .handle = handles.TextureViewHandle.invalid(),
                .texture = self, // Keep reference to parent texture
            };
        }

        const view_handle_id = js_webgpu_create_texture_view(self.handle.id);

        return TextureView{
            .handle = .{ .id = view_handle_id },
            .texture = self,
        };
    }

    /// Destroy the texture and free GPU resources
    pub fn destroy(self: *Texture) void {
        if (self.isValid()) {
            js_webgpu_destroy_texture(self.handle.id);
            self.handle = handles.TextureHandle.invalid();
        }
    }
};

/// Texture view wrapper
pub const TextureView = struct {
    handle: handles.TextureViewHandle,
    texture: Texture,

    pub fn isValid(self: TextureView) bool {
        return self.handle.isValid();
    }
};

/// Helper: Create HDR render target
pub fn createHDRTexture(width: u32, height: u32) Texture {
    return Texture.create(
        width,
        height,
        .rgba16float,
        .{
            .render_attachment = true,
            .texture_binding = true,
        },
    );
}

/// Helper: Create standard render target
pub fn createRenderTexture(width: u32, height: u32, format: TextureFormat) Texture {
    return Texture.create(
        width,
        height,
        format,
        .{
            .render_attachment = true,
            .texture_binding = true,
        },
    );
}

// FFI declarations

/// Create a 2D texture
extern fn js_webgpu_create_texture(
    device: u32,
    width: u32,
    height: u32,
    format: u32,
    usage: u32,
) u32;

/// Create a texture view
extern fn js_webgpu_create_texture_view(texture: u32) u32;

/// Destroy texture and free resources
extern fn js_webgpu_destroy_texture(texture: u32) void;

// Helper logging
fn log(comptime msg: []const u8) void {
    js_console_log(msg.ptr, msg.len);
}

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
