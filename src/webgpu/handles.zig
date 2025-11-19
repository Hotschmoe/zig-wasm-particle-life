// WebGPU Handle System
//
// Handles are opaque u32 IDs that represent WebGPU objects living in JavaScript.
// Zig code passes handles to JS, which looks up the actual WebGPU objects.
//
// This design keeps:
// - All WebGPU objects in JavaScript (where they belong)
// - Zig code type-safe with distinct handle types
// - FFI boundary simple (just u32 IDs)

const std = @import("std");

/// Base handle type - all WebGPU handles are u32 IDs
pub const Handle = u32;

/// Invalid/null handle sentinel value
pub const INVALID_HANDLE: Handle = 0;

/// Type-safe handle wrappers for different WebGPU object types
/// Using distinct types prevents accidentally passing wrong handle type to FFI
pub const DeviceHandle = struct {
    id: Handle,

    pub fn isValid(self: DeviceHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() DeviceHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const BufferHandle = struct {
    id: Handle,

    pub fn isValid(self: BufferHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() BufferHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const ShaderModuleHandle = struct {
    id: Handle,

    pub fn isValid(self: ShaderModuleHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() ShaderModuleHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const TextureHandle = struct {
    id: Handle,

    pub fn isValid(self: TextureHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() TextureHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const TextureViewHandle = struct {
    id: Handle,

    pub fn isValid(self: TextureViewHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() TextureViewHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const BindGroupHandle = struct {
    id: Handle,

    pub fn isValid(self: BindGroupHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() BindGroupHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const BindGroupLayoutHandle = struct {
    id: Handle,

    pub fn isValid(self: BindGroupLayoutHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() BindGroupLayoutHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const PipelineLayoutHandle = struct {
    id: Handle,

    pub fn isValid(self: PipelineLayoutHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() PipelineLayoutHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const ComputePipelineHandle = struct {
    id: Handle,

    pub fn isValid(self: ComputePipelineHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() ComputePipelineHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const RenderPipelineHandle = struct {
    id: Handle,

    pub fn isValid(self: RenderPipelineHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() RenderPipelineHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const CommandEncoderHandle = struct {
    id: Handle,

    pub fn isValid(self: CommandEncoderHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() CommandEncoderHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const RenderPassEncoderHandle = struct {
    id: Handle,

    pub fn isValid(self: RenderPassEncoderHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() RenderPassEncoderHandle {
        return .{ .id = INVALID_HANDLE };
    }
};

pub const ComputePassEncoderHandle = struct {
    id: Handle,

    pub fn isValid(self: ComputePassEncoderHandle) bool {
        return self.id != INVALID_HANDLE;
    }

    pub fn invalid() ComputePassEncoderHandle {
        return .{ .id = INVALID_HANDLE };
    }
};
