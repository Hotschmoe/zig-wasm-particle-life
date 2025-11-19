// WebGPU Rendering Operations
//
// Functions for rendering, including clear screen and basic render passes

const std = @import("std");
const handles = @import("handles.zig");
const device = @import("device.zig");

// FFI imports for rendering operations

/// Begin a render pass with a clear color
extern fn js_webgpu_begin_render_pass(
    r: f32,
    g: f32,
    b: f32,
    a: f32,
) u32;

/// End the current render pass
extern fn js_webgpu_end_render_pass(encoder: u32) void;

/// Submit commands and present to canvas
extern fn js_webgpu_present() void;

/// Color for clearing the screen
pub const ClearColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn init(r: f32, g: f32, b: f32, a: f32) ClearColor {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn black() ClearColor {
        return init(0.0, 0.0, 0.0, 1.0);
    }

    pub fn white() ClearColor {
        return init(1.0, 1.0, 1.0, 1.0);
    }

    pub fn fromHSV(h: f32, s: f32, v: f32) ClearColor {
        const c = v * s;
        const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
        const m = v - c;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (h < 60.0) {
            r = c;
            g = x;
            b = 0;
        } else if (h < 120.0) {
            r = x;
            g = c;
            b = 0;
        } else if (h < 180.0) {
            r = 0;
            g = c;
            b = x;
        } else if (h < 240.0) {
            r = 0;
            g = x;
            b = c;
        } else if (h < 300.0) {
            r = x;
            g = 0;
            b = c;
        } else {
            r = c;
            g = 0;
            b = x;
        }

        return init(r + m, g + m, b + m, 1.0);
    }
};

/// Begin a render pass and return encoder handle
pub fn beginRenderPass(clear_color: ClearColor) handles.RenderPassEncoderHandle {
    const handle_id = js_webgpu_begin_render_pass(
        clear_color.r,
        clear_color.g,
        clear_color.b,
        clear_color.a,
    );

    return .{ .id = handle_id };
}

/// End a render pass
pub fn endRenderPass(encoder: handles.RenderPassEncoderHandle) void {
    if (!encoder.isValid()) {
        return;
    }

    js_webgpu_end_render_pass(encoder.id);
}

/// Submit commands and present to screen
pub fn present() void {
    js_webgpu_present();
}

/// Simple helper to clear screen to a color
pub fn clearScreen(color: ClearColor) void {
    const encoder = beginRenderPass(color);
    endRenderPass(encoder);
    present();
}
