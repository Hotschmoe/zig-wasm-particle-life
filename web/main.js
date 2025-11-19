// Minimal JavaScript glue code for Zig WASM + WebGPU
// Goal: Keep this under 200 lines while providing full WebGPU FFI

import { UI } from './ui.js';

// Global state
const state = {
    wasm: null,
    canvas: null,
    context: null,
    device: null,
    adapter: null,
    preferredFormat: null,
    lastFrameTime: 0,
    frameCount: 0,
    commandEncoder: null,
    renderPassEncoder: null,
};

// Handle management for WebGPU objects
// Zig will reference WebGPU objects by handle ID
const handles = {
    nextId: 1,
    map: new Map(),

    create(obj) {
        const id = this.nextId++;
        this.map.set(id, obj);
        return id;
    },

    get(id) {
        return this.map.get(id);
    },

    release(id) {
        this.map.delete(id);
    }
};

// FFI functions exposed to WASM
// NOTE: Memory is configured in build.zig (16MB initial, 512MB max)
const wasmImports = {
    env: {
        // === Console Logging ===

        js_console_log(ptr, len) {
            const memory = state.wasm.exports.memory;
            const text = new TextDecoder().decode(
                new Uint8Array(memory.buffer, ptr, len)
            );
            console.log(`[Zig] ${text}`);
        },

        // === Buffer Management ===

        js_webgpu_create_buffer(deviceId, size, usage, mappedAtCreation) {
            const device = handles.get(deviceId);
            if (!device) {
                console.error('Invalid device handle:', deviceId);
                return 0;
            }

            const buffer = device.createBuffer({
                size: Number(size),
                usage: usage,
                mappedAtCreation: mappedAtCreation,
            });

            return handles.create(buffer);
        },

        js_webgpu_buffer_write(deviceId, bufferId, offset, dataPtr, dataLen) {
            const device = handles.get(deviceId);
            const buffer = handles.get(bufferId);
            if (!device || !buffer) {
                console.error('Invalid device or buffer handle');
                return;
            }

            const memory = state.wasm.exports.memory;
            const data = new Uint8Array(memory.buffer, dataPtr, dataLen);

            device.queue.writeBuffer(buffer, Number(offset), data);
        },

        js_webgpu_buffer_destroy(bufferId) {
            const buffer = handles.get(bufferId);
            if (buffer) {
                buffer.destroy();
                handles.release(bufferId);
            }
        },

        js_webgpu_copy_buffer_to_buffer(srcId, srcOffset, dstId, dstOffset, size) {
            const srcBuffer = handles.get(srcId);
            const dstBuffer = handles.get(dstId);

            if (!srcBuffer || !dstBuffer) {
                console.error('Invalid source or destination buffer handle');
                return;
            }

            // Need to use a command encoder for buffer copies
            const encoder = state.device.createCommandEncoder();
            encoder.copyBufferToBuffer(srcBuffer, Number(srcOffset), dstBuffer, Number(dstOffset), Number(size));
            const commandBuffer = encoder.finish();
            state.device.queue.submit([commandBuffer]);
        },

        js_webgpu_copy_buffer_to_buffer_in_encoder(encoderId, srcId, srcOffset, dstId, dstOffset, size) {
            const encoder = handles.get(encoderId);
            const srcBuffer = handles.get(srcId);
            const dstBuffer = handles.get(dstId);

            if (!encoder || !srcBuffer || !dstBuffer) {
                console.error('Invalid encoder, source, or destination buffer handle');
                return;
            }

            encoder.copyBufferToBuffer(srcBuffer, Number(srcOffset), dstBuffer, Number(dstOffset), Number(size));
        },

        js_webgpu_encoder_begin_compute_pass(encoderId) {
            const encoder = handles.get(encoderId);
            if (!encoder) {
                console.error('Invalid encoder handle');
                return 0;
            }

            const pass = encoder.beginComputePass();
            return handles.create(pass);
        },

        // === Shader Management ===

        js_webgpu_create_shader_module(deviceId, sourcePtr, sourceLen) {
            const device = handles.get(deviceId);
            if (!device) {
                console.error('Invalid device handle:', deviceId);
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const source = new TextDecoder().decode(
                new Uint8Array(memory.buffer, sourcePtr, sourceLen)
            );

            try {
                const shaderModule = device.createShaderModule({ code: source });
                return handles.create(shaderModule);
            } catch (e) {
                console.error('Shader compilation error:', e);
                console.error('Shader source:', source);
                return 0;
            }
        },

        // === Texture Management ===

        js_webgpu_create_texture(deviceId, width, height, format, usage) {
            const device = handles.get(deviceId);
            if (!device) {
                console.error('Invalid device handle');
                return 0;
            }

            // Map format enum to WebGPU format string
            const formats = [
                'rgba16float',     // 0
                'rgba32float',     // 1
                'bgra8unorm',      // 2
                'rgba8unorm',      // 3
                'rgba8unorm-srgb', // 4
                'depth24plus',     // 5
                'depth32float',    // 6
            ];

            const formatString = formats[format] || 'rgba8unorm';

            try {
                const texture = device.createTexture({
                    size: { width, height, depthOrArrayLayers: 1 },
                    format: formatString,
                    usage: usage,
                    dimension: '2d',
                });

                return handles.create(texture);
            } catch (e) {
                console.error('Failed to create texture:', e);
                console.error('  Width:', width, 'Height:', height);
                console.error('  Format:', formatString, 'Usage:', usage);
                return 0;
            }
        },

        js_webgpu_create_texture_view(textureId) {
            const texture = handles.get(textureId);
            if (!texture) {
                console.error('Invalid texture handle');
                return 0;
            }

            try {
                const view = texture.createView();
                return handles.create(view);
            } catch (e) {
                console.error('Failed to create texture view:', e);
                return 0;
            }
        },

        js_webgpu_destroy_texture(textureId) {
            const texture = handles.get(textureId);
            if (texture) {
                // WebGPU textures don't have explicit destroy(), they're garbage collected
                // But we should release the handle
                handles.release(textureId);
            }
        },

        // === Rendering ===

        js_webgpu_begin_render_pass(r, g, b, a) {
            if (!state.device || !state.context) {
                console.error('Device or context not initialized');
                return 0;
            }

            // Create command encoder
            state.commandEncoder = state.device.createCommandEncoder();

            // Get current texture from canvas context
            const textureView = state.context.getCurrentTexture().createView();

            // Begin render pass with clear color
            state.renderPassEncoder = state.commandEncoder.beginRenderPass({
                colorAttachments: [{
                    view: textureView,
                    clearValue: { r, g, b, a },
                    loadOp: 'clear',
                    storeOp: 'store',
                }],
            });

            return handles.create(state.renderPassEncoder);
        },

        js_webgpu_end_render_pass(encoderId) {
            if (state.renderPassEncoder) {
                state.renderPassEncoder.end();
                state.renderPassEncoder = null;
            }
        },

        js_webgpu_present() {
            if (state.commandEncoder && state.device) {
                const commandBuffer = state.commandEncoder.finish();
                state.device.queue.submit([commandBuffer]);
                state.commandEncoder = null;
            }
        },

        // === Compute Pipeline ===

        js_webgpu_create_bind_group_layout(deviceId, entriesPtr, entriesLen) {
            const device = handles.get(deviceId);
            if (!device) {
                console.error('Invalid device handle');
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const entries = [];

            // Each entry is: binding(u32), visibility(u32), entry_type(u32), buffer_type(u32), has_min_size(u32), has_dynamic_offset(u32), min_size(u64), padding(u64)
            const ENTRY_SIZE = 40; // 4 + 4 + 4 + 4 + 4 + 4 + 8 + 8 bytes
            const view = new DataView(memory.buffer, entriesPtr, entriesLen * ENTRY_SIZE);

            for (let i = 0; i < entriesLen; i++) {
                const offset = i * ENTRY_SIZE;
                const binding = view.getUint32(offset, true);
                const visibility = view.getUint32(offset + 4, true);
                const entryType = view.getUint32(offset + 8, true); // 0 = buffer, 1 = texture
                const bufferType = view.getUint32(offset + 12, true);
                const hasMinSize = view.getUint32(offset + 16, true);
                const hasDynamicOffset = view.getUint32(offset + 20, true);
                const minSize = Number(view.getBigUint64(offset + 24, true));

                // Debug logging for texture bindings
                if (entryType === 1) {
                    console.log(`  Entry ${i}: binding=${binding}, visibility=0x${visibility.toString(16)}, type=texture`);
                }

                const entry = {
                    binding: binding,
                    visibility: visibility,
                };

                if (entryType === 0) {
                    // Buffer binding
                    entry.buffer = {
                        type: ['uniform', 'storage', 'read-only-storage'][bufferType] || 'storage',
                    };

                    if (hasMinSize) {
                        entry.buffer.minBindingSize = minSize;
                    }

                    if (hasDynamicOffset) {
                        entry.buffer.hasDynamicOffset = true;
                    }
                } else if (entryType === 1) {
                    // Texture binding
                    entry.texture = {
                        sampleType: 'float',
                        viewDimension: '2d',
                        multisampled: false,
                    };
                } else if (entryType === 2) {
                    // Sampler binding (for future use)
                    entry.sampler = {
                        type: 'filtering',
                    };
                }

                entries.push(entry);
            }

            const layout = device.createBindGroupLayout({ entries });
            return handles.create(layout);
        },

        js_webgpu_create_bind_group(deviceId, layoutId, entriesPtr, entriesLen) {
            const device = handles.get(deviceId);
            const layout = handles.get(layoutId);
            if (!device || !layout) {
                console.error('Invalid device or layout handle');
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const entries = [];

            // Each entry is: binding(u32), entry_type(u32), resource_handle(u32), padding(u32), offset(u64), size(u64)
            // Total: 4 + 4 + 4 + 4 + 8 + 8 = 32 bytes
            const ENTRY_SIZE = 32;
            const view = new DataView(memory.buffer, entriesPtr, entriesLen * ENTRY_SIZE);

            for (let i = 0; i < entriesLen; i++) {
                const offset = i * ENTRY_SIZE;
                const binding = view.getUint32(offset, true);
                const entryType = view.getUint32(offset + 4, true); // 0 = buffer, 1 = texture_view
                const resourceHandle = view.getUint32(offset + 8, true);
                const bufferOffset = Number(view.getBigUint64(offset + 16, true));
                const size = Number(view.getBigUint64(offset + 24, true));

                const resource = handles.get(resourceHandle);
                if (!resource) {
                    console.error('Invalid resource handle in bind group');
                    return 0;
                }

                const entry = { binding: binding };

                if (entryType === 0) {
                    // Buffer binding
                    entry.resource = {
                        buffer: resource,
                        offset: bufferOffset,
                        size: size,
                    };
                } else if (entryType === 1) {
                    // Texture view binding
                    entry.resource = resource; // Just the texture view directly
                }

                entries.push(entry);
            }

            const bindGroup = device.createBindGroup({
                layout: layout,
                entries: entries,
            });

            return handles.create(bindGroup);
        },

        js_webgpu_create_pipeline_layout(deviceId, layoutsPtr, layoutsLen) {
            const device = handles.get(deviceId);
            if (!device) {
                console.error('Invalid device handle');
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const layouts = [];

            // Array of u32 handles
            const view = new Uint32Array(memory.buffer, layoutsPtr, layoutsLen);
            for (let i = 0; i < layoutsLen; i++) {
                const layout = handles.get(view[i]);
                if (!layout) {
                    console.error('Invalid bind group layout handle');
                    return 0;
                }
                layouts.push(layout);
            }

            const pipelineLayout = device.createPipelineLayout({
                bindGroupLayouts: layouts,
            });

            return handles.create(pipelineLayout);
        },

        js_webgpu_create_compute_pipeline(deviceId, layoutId, shaderId, entryPointPtr, entryPointLen) {
            const device = handles.get(deviceId);
            const layout = handles.get(layoutId);
            const shader = handles.get(shaderId);

            if (!device || !layout || !shader) {
                console.error('Invalid device, layout, or shader handle');
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const entryPoint = new TextDecoder().decode(
                new Uint8Array(memory.buffer, entryPointPtr, entryPointLen)
            );

            try {
                const pipeline = device.createComputePipeline({
                    layout: layout,
                    compute: {
                        module: shader,
                        entryPoint: entryPoint,
                    }
                });

                return handles.create(pipeline);
            } catch (e) {
                console.error('Compute pipeline creation error:', e);
                return 0;
            }
        },

        js_webgpu_create_command_encoder(deviceId) {
            const device = handles.get(deviceId);
            if (!device) {
                console.error('Invalid device handle');
                return 0;
            }

            const encoder = device.createCommandEncoder();
            return handles.create(encoder);
        },

        js_webgpu_begin_compute_pass(encoderId) {
            const encoder = handles.get(encoderId);
            if (!encoder) {
                console.error('Invalid encoder handle');
                return 0;
            }

            const pass = encoder.beginComputePass();
            return handles.create(pass);
        },

        js_webgpu_compute_pass_set_pipeline(passId, pipelineId) {
            const pass = handles.get(passId);
            const pipeline = handles.get(pipelineId);

            if (!pass || !pipeline) {
                console.error('Invalid pass or pipeline handle');
                return;
            }

            pass.setPipeline(pipeline);
        },

        js_webgpu_compute_pass_set_bind_group(passId, index, bindGroupId) {
            const pass = handles.get(passId);
            const bindGroup = handles.get(bindGroupId);

            if (!pass || !bindGroup) {
                console.error('Invalid pass or bind group handle');
                return;
            }

            pass.setBindGroup(index, bindGroup);
        },

        js_webgpu_compute_pass_set_bind_group_with_offset(passId, index, bindGroupId, dynamicOffset) {
            const pass = handles.get(passId);
            const bindGroup = handles.get(bindGroupId);

            if (!pass || !bindGroup) {
                console.error('Invalid pass or bind group handle');
                return;
            }

            pass.setBindGroup(index, bindGroup, [dynamicOffset]);
        },

        js_webgpu_compute_pass_dispatch(passId, x, y, z) {
            const pass = handles.get(passId);
            if (!pass) {
                console.error('Invalid pass handle');
                return;
            }

            pass.dispatchWorkgroups(x, y, z);
        },

        js_webgpu_compute_pass_end(passId) {
            const pass = handles.get(passId);
            if (!pass) {
                console.error('Invalid pass handle');
                return;
            }

            pass.end();
            handles.release(passId);
        },

        js_webgpu_command_encoder_finish(encoderId) {
            const encoder = handles.get(encoderId);
            if (!encoder) {
                console.error('Invalid encoder handle');
                return 0;
            }

            const commandBuffer = encoder.finish();
            handles.release(encoderId);
            return handles.create(commandBuffer);
        },

        js_webgpu_queue_submit(deviceId, commandBufferId) {
            const device = handles.get(deviceId);
            const commandBuffer = handles.get(commandBufferId);

            if (!device || !commandBuffer) {
                console.error('Invalid device or command buffer handle');
                return;
            }

            device.queue.submit([commandBuffer]);
            handles.release(commandBufferId);
        },

        // === Render Pipeline ===

        js_webgpu_create_render_pipeline(deviceId, layoutId, shaderId, vertexEntryPtr, vertexEntryLen, fragmentEntryPtr, fragmentEntryLen) {
            const device = handles.get(deviceId);
            const layout = handles.get(layoutId);
            const shader = handles.get(shaderId);

            if (!device || !layout || !shader) {
                console.error('Invalid device, layout, or shader handle');
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const vertexEntry = new TextDecoder().decode(
                new Uint8Array(memory.buffer, vertexEntryPtr, vertexEntryLen)
            );
            const fragmentEntry = new TextDecoder().decode(
                new Uint8Array(memory.buffer, fragmentEntryPtr, fragmentEntryLen)
            );

            try {
                const pipeline = device.createRenderPipeline({
                    layout: layout,
                    vertex: {
                        module: shader,
                        entryPoint: vertexEntry,
                    },
                    primitive: {
                        topology: 'triangle-list',
                    },
                    fragment: {
                        module: shader,
                        entryPoint: fragmentEntry,
                        targets: [{
                            format: state.preferredFormat,
                            blend: {
                                color: {
                                    srcFactor: 'src-alpha',
                                    dstFactor: 'one-minus-src-alpha',
                                },
                                alpha: {
                                    srcFactor: 'one',
                                    dstFactor: 'one-minus-src-alpha',
                                },
                            },
                        }],
                    },
                });

                return handles.create(pipeline);
            } catch (e) {
                console.error('Render pipeline creation error:', e);
                return 0;
            }
        },

        js_webgpu_create_render_pipeline_hdr(deviceId, layoutId, shaderId, vertexEntryPtr, vertexEntryLen, fragmentEntryPtr, fragmentEntryLen, targetFormat, enableBlending) {
            const device = handles.get(deviceId);
            const layout = handles.get(layoutId);
            const shader = handles.get(shaderId);

            if (!device || !layout || !shader) {
                console.error('Invalid device, layout, or shader handle');
                return 0;
            }

            const memory = state.wasm.exports.memory;
            const vertexEntry = new TextDecoder().decode(
                new Uint8Array(memory.buffer, vertexEntryPtr, vertexEntryLen)
            );
            const fragmentEntry = new TextDecoder().decode(
                new Uint8Array(memory.buffer, fragmentEntryPtr, fragmentEntryLen)
            );

            // Map format enum to string
            const formats = [
                'rgba16float',     // 0 - HDR format
                'rgba32float',     // 1
                'bgra8unorm',      // 2
                'rgba8unorm',      // 3
                'rgba8unorm-srgb', // 4
            ];
            const formatString = formats[targetFormat] || 'bgra8unorm';

            try {
                const pipelineDesc = {
                    layout: layout,
                    vertex: {
                        module: shader,
                        entryPoint: vertexEntry,
                    },
                    primitive: {
                        topology: 'triangle-list',
                    },
                    fragment: {
                        module: shader,
                        entryPoint: fragmentEntry,
                        targets: [{
                            format: formatString,
                        }],
                    },
                };

                // Add additive blending if requested (for HDR accumulation)
                if (enableBlending) {
                    pipelineDesc.fragment.targets[0].blend = {
                        color: {
                            srcFactor: 'src-alpha',
                            dstFactor: 'one',  // Additive!
                            operation: 'add',
                        },
                        alpha: {
                            srcFactor: 'one',
                            dstFactor: 'one',
                            operation: 'add',
                        },
                    };
                }

                const pipeline = device.createRenderPipeline(pipelineDesc);
                return handles.create(pipeline);
            } catch (e) {
                console.error('Failed to create HDR render pipeline:', e);
                console.error('  Format:', formatString, 'Blending:', enableBlending);
                return 0;
            }
        },

        js_webgpu_begin_render_pass_for_particles(r, g, b, a) {
            if (!state.device || !state.context) {
                console.error('Device or context not initialized');
                return 0;
            }

            // Create command encoder if not exists
            if (!state.commandEncoder) {
                state.commandEncoder = state.device.createCommandEncoder();
            }

            // Get current texture from canvas context
            const textureView = state.context.getCurrentTexture().createView();

            // Begin render pass with clear color
            state.renderPassEncoder = state.commandEncoder.beginRenderPass({
                colorAttachments: [{
                    view: textureView,
                    clearValue: { r, g, b, a },
                    loadOp: 'clear',
                    storeOp: 'store',
                }],
            });

            return handles.create(state.renderPassEncoder);
        },

        js_webgpu_begin_render_pass_hdr(textureViewId, r, g, b, a) {
            if (!state.device) {
                console.error('Device not initialized');
                return 0;
            }

            const textureView = handles.get(textureViewId);
            if (!textureView) {
                console.error('Invalid texture view handle');
                return 0;
            }

            // Create command encoder if not exists
            if (!state.commandEncoder) {
                state.commandEncoder = state.device.createCommandEncoder();
            }

            // Begin render pass targeting HDR texture
            state.renderPassEncoder = state.commandEncoder.beginRenderPass({
                colorAttachments: [{
                    view: textureView,
                    clearValue: { r, g, b, a },
                    loadOp: 'clear',
                    storeOp: 'store',
                }],
            });

            return handles.create(state.renderPassEncoder);
        },

        js_webgpu_render_pass_set_pipeline(passId, pipelineId) {
            const pass = handles.get(passId);
            const pipeline = handles.get(pipelineId);

            if (!pass || !pipeline) {
                console.error('Invalid pass or pipeline handle');
                return;
            }

            pass.setPipeline(pipeline);
        },

        js_webgpu_render_pass_set_bind_group(passId, index, bindGroupId) {
            const pass = handles.get(passId);
            const bindGroup = handles.get(bindGroupId);

            if (!pass || !bindGroup) {
                console.error('Invalid pass or bind group handle');
                return;
            }

            pass.setBindGroup(index, bindGroup);
        },

        js_webgpu_render_pass_draw(passId, vertexCount, instanceCount, firstVertex, firstInstance) {
            const pass = handles.get(passId);
            if (!pass) {
                console.error('Invalid pass handle');
                return;
            }

            pass.draw(vertexCount, instanceCount, firstVertex, firstInstance);
        },

        js_webgpu_render_pass_end(passId) {
            if (state.renderPassEncoder) {
                state.renderPassEncoder.end();
                state.renderPassEncoder = null;
            }
        },
    }
};

// Initialize WebGPU
// Helper: Load image from URL
async function loadImage(url) {
    const response = await fetch(url);
    const blob = await response.blob();
    return await createImageBitmap(blob, { colorSpaceConversion: 'none' });
}

async function initWebGPU() {
    state.canvas = document.getElementById('canvas');
    state.context = state.canvas.getContext('webgpu');

    if (!navigator.gpu) {
        updateStatus('WebGPU not supported!');
        throw new Error('WebGPU not supported');
    }

    state.adapter = await navigator.gpu.requestAdapter();
    if (!state.adapter) {
        updateStatus('Failed to get WebGPU adapter');
        throw new Error('Failed to get WebGPU adapter');
    }

    state.device = await state.adapter.requestDevice();
    state.preferredFormat = navigator.gpu.getPreferredCanvasFormat();

    // Configure canvas
    state.context.configure({
        device: state.device,
        format: state.preferredFormat,
        alphaMode: 'opaque',
    });

    // Store device handle (always ID 1)
    handles.create(state.device);

    console.log('WebGPU initialized successfully');
    console.log('Adapter:', state.adapter);
    console.log('Device:', state.device);
    console.log('Format:', state.preferredFormat);

    // Load blue noise texture for dithering
    try {
        const blueNoiseImage = await loadImage('blue-noise.png');
        const blueNoiseTexture = state.device.createTexture({
            format: 'rgba8unorm',
            size: [blueNoiseImage.width, blueNoiseImage.height],
            usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
        });

        state.device.queue.copyExternalImageToTexture(
            { source: blueNoiseImage },
            { texture: blueNoiseTexture },
            { width: blueNoiseImage.width, height: blueNoiseImage.height }
        );

        state.blueNoiseTexture = blueNoiseTexture;
        state.blueNoiseTextureView = blueNoiseTexture.createView();

        // Store handles for blue noise (will be used by compose pipeline)
        const blueNoiseTextureHandle = handles.create(blueNoiseTexture);
        const blueNoiseViewHandle = handles.create(state.blueNoiseTextureView);

        console.log('✓ Blue noise texture loaded:', blueNoiseImage.width, 'x', blueNoiseImage.height);
        console.log('  Texture handle:', blueNoiseTextureHandle);
        console.log('  View handle:', blueNoiseViewHandle);

        // Pass to Zig if WASM is already loaded
        if (state.wasm && state.wasm.exports.setBlueNoiseTexture) {
            state.wasm.exports.setBlueNoiseTexture(blueNoiseTextureHandle, blueNoiseViewHandle);
        }
    } catch (error) {
        console.warn('Failed to load blue noise texture:', error);
        console.warn('  Compositing will work but without dithering');
    }
}

// Load and initialize WASM
async function initWASM() {
    try {
        updateStatus('Loading WASM...');

        // Add cache busting timestamp to URL
        const response = await fetch(`app.wasm?t=${Date.now()}`);
        if (!response.ok) {
            throw new Error(`Failed to fetch app.wasm: ${response.status}`);
        }

        const wasmBytes = await response.arrayBuffer();
        const wasmModule = await WebAssembly.instantiate(wasmBytes, wasmImports);

        state.wasm = wasmModule.instance;

        updateStatus('Initializing...');

        // Pass device handle to Zig
        if (state.wasm.exports.setDevice) {
            state.wasm.exports.setDevice(1); // Device handle is always 1
        }

        // Call Zig init function
        if (state.wasm.exports.init) {
            const seed = Math.floor(Math.random() * 0xFFFFFFFF);
            state.wasm.exports.init(seed);
        }

        updateStatus('Running');

        // Update camera with current canvas size
        // Force update canvas dimensions to match display size (accounting for DPR)
        const dpr = window.devicePixelRatio || 1;
        state.canvas.width = Math.round(state.canvas.clientWidth * dpr);
        state.canvas.height = Math.round(state.canvas.clientHeight * dpr);

        if (state.wasm.exports.onResize) {
            state.wasm.exports.onResize(state.canvas.width, state.canvas.height);
            console.log('Camera initialized with canvas size:', state.canvas.width, 'x', state.canvas.height);
        }

        // Initialize UI
        state.ui = new UI(state.wasm, state.canvas);
        console.log('UI initialized');

        // Start animation loop
        requestAnimationFrame(animationLoop);

    } catch (error) {
        console.error('Failed to initialize WASM:', error);
        updateStatus(`Error: ${error.message}`);
    }
}

// Animation loop
function animationLoop(timestamp) {
    const dt = timestamp - state.lastFrameTime;
    state.lastFrameTime = timestamp;
    state.frameCount++;

    // Update FPS counter every 60 frames
    if (state.frameCount % 60 === 0) {
        const fps = Math.round(1000 / dt);
        document.getElementById('fps').textContent = `FPS: ${fps}`;
    }

    // Call WASM update
    if (state.wasm && state.wasm.exports.update) {
        // Check if paused
        if (state.ui && state.ui.isPaused()) {
            // Still call update but with dt=0 to keep rendering (if needed) or just skip
            // If we skip, the canvas won't update. If we pass 0, it might still render.
            // Let's pass 0 so we can still pan/zoom while paused if we want (though update logic might need to handle dt=0 correctly)
            state.wasm.exports.update(0);
        } else {
            state.wasm.exports.update(dt / 1000); // Convert to seconds
        }
    }

    requestAnimationFrame(animationLoop);
}

// Update status display
function updateStatus(text) {
    document.getElementById('status').textContent = text;
}

// Handle canvas resize
function resizeCanvas() {
    if (!state.canvas) return;

    const dpr = window.devicePixelRatio || 1;
    state.canvas.width = state.canvas.clientWidth * dpr;
    state.canvas.height = state.canvas.clientHeight * dpr;

    console.log(`Canvas resized to ${state.canvas.width}x${state.canvas.height}`);

    // Notify WASM of resize
    if (state.wasm && state.wasm.exports.onResize) {
        state.wasm.exports.onResize(state.canvas.width, state.canvas.height);
    }
}

// Initialize everything
async function init() {
    try {
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);

        await initWebGPU();
        await initWASM();

    } catch (error) {
        console.error('Initialization failed:', error);
        updateStatus(`Fatal error: ${error.message}`);
    }
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
