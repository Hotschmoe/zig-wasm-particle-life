# Zig WASM WebGPU FFI Bindings

Minimal JavaScript WebGPU FFI bindings for Zig+WASM, tested against Nikita Lisitsa's Particle Life simulation.

[![Zig](https://img.shields.io/badge/Zig-0.13.0-orange.svg)](https://ziglang.org/)
[![WebGPU](https://img.shields.io/badge/WebGPU-Enabled-blue.svg)](https://www.w3.org/TR/webgpu/)

## Objectives

**Primary Goal**: Verify that freestanding Zig WASM can successfully drive WebGPU APIs through minimal JavaScript FFI bindings. The Particle Life simulation serves as validation that the FFI layer handles compute pipelines, render pipelines, buffer management, and multi-pass orchestration correctly.

**Secondary Goal**: Establish a reusable pattern for building WebGPU applications in Zig. Once validated, this FFI layer becomes a foundation for other GPU-accelerated web applications without JavaScript overhead.

## Implementation

The project recreates Nikita Lisitsa's Particle Life 2D simulation ([original demo](https://lisyarus.github.io/webgpu/particle-life.html), [blog post](https://lisyarus.github.io/blog/posts/particle-life-simulation-in-browser-using-webgpu.html)). The reference implementation in `docs/nikita_demo` is a 2548-line HTML file containing JavaScript, WebGPU code, and WGSL shaders that runs 65k+ particles at 60fps.

This simulation exercises the complete WebGPU API surface:
- Compute pipelines: particle forces, spatial binning, sorting, state advancement
- Render pipelines: particle visualization with HDR tone mapping and glow effects
- Buffer operations: storage buffers, uniform buffers, atomic operations
- Pipeline coordination: multiple dependent compute passes per frame
- Performance requirements: real-time execution with 65k+ particles

## Architecture

Target: `wasm32-freestanding`

Constraints:
- No WASI - WebGPU provides necessary APIs
- No Emscripten - avoid JavaScript runtime bloat
- No WASM frameworks - direct FFI control
- Minimal JavaScript - approximately 200 lines for WebGPU bridge only

Rationale: Zig's freestanding target provides low-level control, predictable performance, and zero runtime overhead. WASM delivers near-native execution speed across browsers. WebGPU offers modern GPU compute with broad device support. The architecture keeps all simulation logic in Zig while JavaScript serves only as a thin FFI layer to WebGPU browser APIs.

Performance target: match or exceed the reference JavaScript implementation.