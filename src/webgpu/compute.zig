// High-level Compute Pass API for WebGPU
//
// Provides convenient wrappers for recording and dispatching compute operations.

const std = @import("std");
const handles = @import("handles.zig");
const device = @import("device.zig");
const pipeline = @import("pipeline.zig");

// === Command Encoder ===

pub const CommandEncoder = struct {
    handle: handles.CommandEncoderHandle,

    pub fn create() CommandEncoder {
        const dev = device.getDevice();
        if (!dev.isValid()) {
            return .{ .handle = handles.CommandEncoderHandle.invalid() };
        }

        const handle_id = js_webgpu_create_command_encoder(dev.id);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn beginComputePass(self: CommandEncoder) ComputePass {
        if (!self.isValid()) {
            return .{ .handle = handles.ComputePassEncoderHandle.invalid() };
        }

        const handle_id = js_webgpu_begin_compute_pass(self.handle.id);
        return .{ .handle = .{ .id = handle_id } };
    }

    pub fn finish(self: CommandEncoder) CommandBuffer {
        if (!self.isValid()) {
            return .{ .handle = 0 };
        }

        const handle_id = js_webgpu_command_encoder_finish(self.handle.id);
        return .{ .handle = handle_id };
    }

    pub fn isValid(self: CommandEncoder) bool {
        return self.handle.isValid();
    }
};

// === Compute Pass ===

pub const ComputePass = struct {
    handle: handles.ComputePassEncoderHandle,

    pub fn setPipeline(self: ComputePass, compute_pipeline: pipeline.ComputePipeline) void {
        if (!self.isValid() or !compute_pipeline.isValid()) {
            return;
        }

        js_webgpu_compute_pass_set_pipeline(self.handle.id, compute_pipeline.handle.id);
    }

    pub fn setBindGroup(self: ComputePass, index: u32, bind_group: pipeline.BindGroup) void {
        if (!self.isValid() or !bind_group.isValid()) {
            return;
        }

        js_webgpu_compute_pass_set_bind_group(self.handle.id, index, bind_group.handle.id);
    }

    pub fn dispatch(self: ComputePass, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        if (!self.isValid()) {
            return;
        }

        js_webgpu_compute_pass_dispatch(self.handle.id, workgroup_count_x, workgroup_count_y, workgroup_count_z);
    }

    pub fn end(self: ComputePass) void {
        if (!self.isValid()) {
            return;
        }

        js_webgpu_compute_pass_end(self.handle.id);
    }

    pub fn isValid(self: ComputePass) bool {
        return self.handle.isValid();
    }
};

// === Command Buffer ===

pub const CommandBuffer = struct {
    handle: u32,

    pub fn submit(self: CommandBuffer) void {
        const dev = device.getDevice();
        if (!dev.isValid() or self.handle == 0) {
            return;
        }

        js_webgpu_queue_submit(dev.id, self.handle);
    }
};

// === Helper: Dispatch Compute Shader ===

/// High-level helper to dispatch a compute shader in one call
pub fn dispatchCompute(
    compute_pipeline: pipeline.ComputePipeline,
    bind_group: pipeline.BindGroup,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
) void {
    const encoder = CommandEncoder.create();
    const pass = encoder.beginComputePass();

    pass.setPipeline(compute_pipeline);
    pass.setBindGroup(0, bind_group);
    pass.dispatch(workgroup_count_x, workgroup_count_y, workgroup_count_z);
    pass.end();

    const cmd_buffer = encoder.finish();
    cmd_buffer.submit();
}

// === FFI Declarations ===

extern fn js_webgpu_create_command_encoder(device: u32) u32;
extern fn js_webgpu_begin_compute_pass(encoder: u32) u32;
extern fn js_webgpu_compute_pass_set_pipeline(pass: u32, pipeline: u32) void;
extern fn js_webgpu_compute_pass_set_bind_group(pass: u32, index: u32, bind_group: u32) void;
extern fn js_webgpu_compute_pass_dispatch(pass: u32, x: u32, y: u32, z: u32) void;
extern fn js_webgpu_compute_pass_end(pass: u32) void;
extern fn js_webgpu_command_encoder_finish(encoder: u32) u32;
extern fn js_webgpu_queue_submit(device: u32, command_buffer: u32) void;
