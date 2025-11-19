// Particle Life - Physics Pipeline
//
// Simplified physics update to get particles moving

const std = @import("std");
const particle = @import("particle.zig");
const shaders = @import("shaders.zig");
const buffer = @import("../webgpu/buffer.zig");
const shader = @import("../webgpu/shader.zig");
const pipeline = @import("../webgpu/pipeline.zig");
const compute = @import("../webgpu/compute.zig");
const device = @import("../webgpu/device.zig");

pub const Physics = struct {
    // Compute shaders
    advance_shader: shader.ShaderModule,

    // Pipelines
    advance_pipeline: pipeline.ComputePipeline,

    // Bind groups (group 0: particles, group 1: options)
    particle_layout: pipeline.BindGroupLayout,
    options_layout: pipeline.BindGroupLayout,
    particle_group: pipeline.BindGroup,
    options_group: pipeline.BindGroup,

    pub fn init(particle_buffer: buffer.Buffer, options_buffer: buffer.Buffer) !Physics {
        log("Setting up physics pipeline...");

        // Create advance shader
        const advance_shader = shader.ShaderModule.create(shaders.particle_advance);
        if (!advance_shader.isValid()) {
            log("ERROR: Failed to create advance shader");
            return error.ShaderCreationFailed;
        }

        // Create bind group layouts
        // Group 0: particles (storage buffer)
        const particle_layout_entries = [_]pipeline.BindGroupLayoutEntry{
            pipeline.BindGroupLayoutEntry.init(0, pipeline.ShaderVisibility.COMPUTE, .storage),
        };
        const particle_layout = pipeline.BindGroupLayout.create(&particle_layout_entries);

        // Group 1: options (uniform buffer)
        const options_layout_entries = [_]pipeline.BindGroupLayoutEntry{
            pipeline.BindGroupLayoutEntry.init(0, pipeline.ShaderVisibility.COMPUTE, .uniform),
        };
        const options_layout = pipeline.BindGroupLayout.create(&options_layout_entries);

        // Create bind groups
        const particle_entries = [_]pipeline.BindGroupEntry{
            pipeline.BindGroupEntry.initFull(0, particle_buffer.handle, particle_buffer.size),
        };
        const particle_group = pipeline.BindGroup.create(particle_layout, &particle_entries);

        const options_entries = [_]pipeline.BindGroupEntry{
            pipeline.BindGroupEntry.initFull(0, options_buffer.handle, options_buffer.size),
        };
        const options_group = pipeline.BindGroup.create(options_layout, &options_entries);

        // Create pipeline layout with BOTH bind group layouts
        const layouts = [_]pipeline.BindGroupLayout{ particle_layout, options_layout };
        const pipeline_layout = pipeline.PipelineLayout.create(&layouts);

        // Create compute pipeline
        const advance_pipeline = pipeline.ComputePipeline.create(
            pipeline_layout,
            advance_shader,
            "particleAdvance",
        );

        if (!advance_pipeline.isValid()) {
            log("ERROR: Failed to create advance pipeline");
            return error.PipelineCreationFailed;
        }

        log("✓ Physics pipeline created");

        return Physics{
            .advance_shader = advance_shader,
            .advance_pipeline = advance_pipeline,
            .particle_layout = particle_layout,
            .options_layout = options_layout,
            .particle_group = particle_group,
            .options_group = options_group,
        };
    }

    pub fn update(self: *Physics, particle_count: u32) void {
        // Create command encoder
        const encoder = compute.CommandEncoder.create();
        const pass = encoder.beginComputePass();

        // Set pipeline
        pass.setPipeline(self.advance_pipeline);

        // Set BOTH bind groups
        pass.setBindGroup(0, self.particle_group);
        pass.setBindGroup(1, self.options_group);

        // Dispatch
        const workgroup_count = (particle_count + 63) / 64;
        pass.dispatch(workgroup_count, 1, 1);

        // End pass and submit
        pass.end();
        const cmd_buffer = encoder.finish();
        cmd_buffer.submit();
    }
};

fn log(comptime msg: []const u8) void {
    js_console_log(msg.ptr, msg.len);
}

extern fn js_console_log(ptr: [*]const u8, len: usize) void;
