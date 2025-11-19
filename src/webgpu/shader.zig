// High-level Shader Module API for WebGPU
//
// Provides convenient wrappers for creating and managing WGSL shader modules.

const std = @import("std");
const handles = @import("handles.zig");
const device = @import("device.zig");

/// High-level Shader Module wrapper
pub const ShaderModule = struct {
    handle: handles.ShaderModuleHandle,

    /// Create a shader module from WGSL source code
    pub fn create(source: []const u8) ShaderModule {
        const handle = device.createShaderModule(source);
        return .{ .handle = handle };
    }

    /// Create a shader module from a compile-time string literal
    pub fn createFromLiteral(comptime source: []const u8) ShaderModule {
        return create(source);
    }

    /// Check if shader module is valid
    pub fn isValid(self: ShaderModule) bool {
        return self.handle.isValid();
    }
};

/// Common shader entry point names
pub const EntryPoint = struct {
    pub const MAIN = "main";
    pub const COMPUTE = "compute";
    pub const VERTEX = "vertex";
    pub const FRAGMENT = "fragment";
};
