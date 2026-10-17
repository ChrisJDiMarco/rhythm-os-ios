import MetalKit
import SwiftUI
import simd

struct BiofieldMetalView: UIViewRepresentable {
    var visualState: RhythmVisualState
    var touchOrigin: CGPoint?
    var touchPoint: CGPoint?
    var commandTint: SIMD3<Float>?

    func makeCoordinator() -> BiofieldMetalRenderer {
        BiofieldMetalRenderer()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.backgroundColor = UIColor(red: 0.01, green: 0.015, blue: 0.03, alpha: 1)
        view.clearColor = MTLClearColor(red: 0.004, green: 0.008, blue: 0.018, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        context.coordinator.configure(view: view)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(
            visualState: visualState,
            touch: BiofieldTouchState(
                origin: touchOrigin,
                point: touchPoint,
                tint: commandTint ?? visualState.accent
            )
        )
    }
}

private struct BiofieldTouchState {
    var origin: CGPoint?
    var point: CGPoint?
    var tint: SIMD3<Float>

    static let inactive = BiofieldTouchState(origin: nil, point: nil, tint: SIMD3<Float>(0.0, 0.96, 0.83))
}

private struct BiofieldSeed {
    var angle: Float
    var radius: Float
    var speed: Float
    var depth: Float
    var scale: Float
    var lane: Float
    var colorMix: Float
    var jitter: Float
}

private struct BiofieldParticleVertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
    var pointSize: Float
    var glow: Float
}

private struct BiofieldShaderUniforms {
    var viewportSize: SIMD2<Float>
    var time: Float
    var coherence: Float
    var entropy: Float
    var turbulence: Float
    var pulseRate: Float
    var glow: Float
    var primary: SIMD4<Float>
    var secondary: SIMD4<Float>
    var accent: SIMD4<Float>
    var shadow: SIMD4<Float>
    var touch: SIMD4<Float>
}

final class BiofieldMetalRenderer: NSObject, MTKViewDelegate {
    private let startTime = CACurrentMediaTime()
    private var commandQueue: MTLCommandQueue?
    private var backgroundPipeline: MTLRenderPipelineState?
    private var particlePipeline: MTLRenderPipelineState?
    private var seeds: [BiofieldSeed] = []
    private var vertices: [BiofieldParticleVertex] = []
    private var visualState = RhythmVisualState(snapshot: .mock, confidence: 0.56, isRefreshing: false)
    private var touch = BiofieldTouchState.inactive

    func configure(view: MTKView) {
        guard let device = view.device else { return }

        commandQueue = device.makeCommandQueue()
        buildPipelines(device: device, pixelFormat: view.colorPixelFormat)
        seeds = Self.makeSeeds(count: 1_120)
        vertices = Array(
            repeating: BiofieldParticleVertex(
                position: .zero,
                color: SIMD4<Float>(1, 1, 1, 1),
                pointSize: 3,
                glow: 1
            ),
            count: seeds.count
        )
    }

    fileprivate func update(visualState: RhythmVisualState, touch: BiofieldTouchState) {
        self.visualState = visualState
        self.touch = touch
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue?.makeCommandBuffer()
        else { return }

        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.004, green: 0.008, blue: 0.018, alpha: 1)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store

        let time = Float(CACurrentMediaTime() - startTime)
        let uniforms = makeUniforms(for: view, time: time)
        let activeCount = updateVertices(in: view, time: time)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        if let backgroundPipeline {
            encoder.setRenderPipelineState(backgroundPipeline)
            encoder.setFragmentBytes(
                [uniforms],
                length: MemoryLayout<BiofieldShaderUniforms>.stride,
                index: 0
            )
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        if let particlePipeline, activeCount > 0 {
            encoder.setRenderPipelineState(particlePipeline)
            encoder.setVertexBytes(
                vertices,
                length: MemoryLayout<BiofieldParticleVertex>.stride * activeCount,
                index: 0
            )
            encoder.setVertexBytes(
                [uniforms],
                length: MemoryLayout<BiofieldShaderUniforms>.stride,
                index: 1
            )
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: activeCount)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func buildPipelines(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)

            let backgroundDescriptor = MTLRenderPipelineDescriptor()
            backgroundDescriptor.vertexFunction = library.makeFunction(name: "backgroundVertex")
            backgroundDescriptor.fragmentFunction = library.makeFunction(name: "backgroundFragment")
            backgroundDescriptor.colorAttachments[0].pixelFormat = pixelFormat
            backgroundPipeline = try device.makeRenderPipelineState(descriptor: backgroundDescriptor)

            let particleDescriptor = MTLRenderPipelineDescriptor()
            particleDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")
            particleDescriptor.fragmentFunction = library.makeFunction(name: "particleFragment")
            particleDescriptor.colorAttachments[0].pixelFormat = pixelFormat
            particleDescriptor.colorAttachments[0].isBlendingEnabled = true
            particleDescriptor.colorAttachments[0].rgbBlendOperation = .add
            particleDescriptor.colorAttachments[0].alphaBlendOperation = .add
            particleDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            particleDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            particleDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            particleDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            particlePipeline = try device.makeRenderPipelineState(descriptor: particleDescriptor)
        } catch {
            print("Biofield Metal pipeline failed: \(error.localizedDescription)")
        }
    }

    private func makeUniforms(for view: MTKView, time: Float) -> BiofieldShaderUniforms {
        let size = view.drawableSize
        let normalizedTouch = normalized(point: touch.point, in: view.bounds.size)
        let touchActive: Float = touch.point == nil ? 0 : 1

        return BiofieldShaderUniforms(
            viewportSize: SIMD2<Float>(Float(max(size.width, 1)), Float(max(size.height, 1))),
            time: time,
            coherence: visualState.coherence,
            entropy: visualState.entropy,
            turbulence: visualState.turbulence,
            pulseRate: visualState.pulseRate,
            glow: visualState.glow,
            primary: vector4(visualState.primary, 1),
            secondary: vector4(visualState.secondary, 1),
            accent: vector4(visualState.accent, 1),
            shadow: vector4(visualState.shadow, 1),
            touch: SIMD4<Float>(
                normalizedTouch.x,
                normalizedTouch.y,
                touchActive,
                visualState.magneticResponse
            )
        )
    }

    private func updateVertices(in view: MTKView, time: Float) -> Int {
        let state = visualState
        let activeCount = min(seeds.count, max(360, Int(360 + state.density * 690)))
        let touchPosition = normalized(point: touch.point, in: view.bounds.size)
        let touchActive = touch.point != nil
        let selectedTint = touch.tint

        for index in 0..<activeCount {
            let seed = seeds[index]
            let lanePhase = seed.lane * .pi * 2
            let rhythmTime = time * (0.18 + seed.speed * 0.34 + state.pulseRate * 0.08)
            let wobble = sin(rhythmTime * 1.7 + seed.jitter * 8.0) * state.turbulence
            let coherencePull = 0.18 + state.coherence * 0.48
            let angle = seed.angle + rhythmTime + wobble * 0.26
            let pulse = sin(time * state.pulseRate * 2.2 + lanePhase)
            let radius = seed.radius
                * (0.58 + state.entropy * 0.42)
                * (1.0 + pulse * (0.018 + state.turbulence * 0.035))

            let clusterAngle = lanePhase + time * (0.055 + state.coherence * 0.045)
            let cluster = SIMD2<Float>(
                cos(clusterAngle) * 0.32,
                sin(clusterAngle) * 0.24
            )

            var position = SIMD2<Float>(
                cos(angle) * radius * (0.58 + seed.depth * 0.24),
                sin(angle * 1.04 + seed.lane) * radius * 0.78
            )

            position = position * (1.0 - coherencePull) + cluster * coherencePull

            let noise = SIMD2<Float>(
                sin(seed.jitter * 18.1 + time * (0.44 + state.entropy)),
                cos(seed.jitter * 13.7 - time * (0.38 + state.turbulence))
            )
            position += noise * (state.entropy * 0.22 + state.turbulence * 0.08)

            var influence: Float = 0
            if touchActive {
                let delta = touchPosition - position
                let distanceSquared = max(simd_length_squared(delta), 0.0001)
                influence = exp(-distanceSquared * (2.8 + state.coherence * 1.6)) * state.magneticResponse
                let direction = delta / sqrt(distanceSquared)
                let ripple = sin(sqrt(distanceSquared) * 17.0 - time * 6.0) * 0.036 * influence
                position += direction * influence * (0.12 + state.entropy * 0.18)
                position += SIMD2<Float>(-direction.y, direction.x) * ripple
            }

            let z = max(0.04, seed.depth + sin(time * 0.34 + seed.angle * 1.7) * 0.18 + state.entropy * 0.24)
            let depthFade = 1.0 / (1.0 + z * 0.42)
            let baseColor = blendedColor(seed: seed, state: state)
            let touchColor = baseColor + (selectedTint - baseColor) * min(influence * 0.74, 0.74)
            let colorLift = 0.58 + state.glow * 0.62 + influence * 0.52
            let alpha = min(0.86, 0.20 + state.glow * 0.22 + state.coherence * 0.12 + influence * 0.30)
            let pointSize = (1.9 + seed.scale * (5.2 + state.glow * 4.5 + influence * 8.0)) * depthFade

            vertices[index] = BiofieldParticleVertex(
                position: SIMD3<Float>(position.x, position.y, z),
                color: SIMD4<Float>(touchColor * colorLift, alpha),
                pointSize: pointSize,
                glow: 0.42 + state.glow * 0.72 + influence * 0.82
            )
        }

        return activeCount
    }

    private func blendedColor(seed: BiofieldSeed, state: RhythmVisualState) -> SIMD3<Float> {
        let primaryToSecondary = state.primary + (state.secondary - state.primary) * seed.colorMix
        let accentWeight = smooth(seed.lane) * (0.22 + state.entropy * 0.20)
        let color = primaryToSecondary + (state.accent - primaryToSecondary) * accentWeight
        return max(color, SIMD3<Float>(repeating: 0))
    }

    private func normalized(point: CGPoint?, in size: CGSize) -> SIMD2<Float> {
        guard let point, size.width > 1, size.height > 1 else {
            return SIMD2<Float>(0, 0)
        }

        return SIMD2<Float>(
            Float(point.x / size.width * 2 - 1),
            Float(1 - point.y / size.height * 2)
        )
    }

    private func vector4(_ value: SIMD3<Float>, _ alpha: Float) -> SIMD4<Float> {
        SIMD4<Float>(value.x, value.y, value.z, alpha)
    }

    private func smooth(_ value: Float) -> Float {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    private static func makeSeeds(count: Int) -> [BiofieldSeed] {
        (0..<count).map { index in
            let base = Float(index)
            let lane = floor(hash(base * 2.17) * 3.0) / 2.0
            let radius = 0.16 + pow(hash(base * 5.13), 0.58) * 0.98
            return BiofieldSeed(
                angle: hash(base * 12.99) * .pi * 2,
                radius: radius,
                speed: 0.56 + hash(base * 1.71) * 1.06,
                depth: hash(base * 8.27) * 1.24,
                scale: 0.42 + hash(base * 3.43) * 1.0,
                lane: lane,
                colorMix: hash(base * 7.31),
                jitter: hash(base * 9.91)
            )
        }
    }

    private static func hash(_ value: Float) -> Float {
        let raw = sin(Double(value) * 12.9898) * 43_758.5453
        return Float(raw - floor(raw))
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct BiofieldShaderUniforms {
        float2 viewportSize;
        float time;
        float coherence;
        float entropy;
        float turbulence;
        float pulseRate;
        float glow;
        float4 primary;
        float4 secondary;
        float4 accent;
        float4 shadow;
        float4 touch;
    };

    struct BiofieldParticleVertex {
        float3 position;
        float4 color;
        float pointSize;
        float glow;
    };

    struct BackgroundOut {
        float4 position [[position]];
        float2 uv;
    };

    struct ParticleOut {
        float4 position [[position]];
        float4 color;
        float pointSize [[point_size]];
        float glow;
    };

    vertex BackgroundOut backgroundVertex(uint vertexID [[vertex_id]]) {
        float2 positions[4] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2( 1.0,  1.0)
        };

        BackgroundOut out;
        float2 position = positions[vertexID];
        out.position = float4(position, 0.0, 1.0);
        out.uv = position * 0.5 + 0.5;
        return out;
    }

    fragment half4 backgroundFragment(
        BackgroundOut in [[stage_in]],
        constant BiofieldShaderUniforms &u [[buffer(0)]]
    ) {
        float2 p = in.uv * 2.0 - 1.0;
        p.x *= u.viewportSize.x / max(u.viewportSize.y, 1.0);

        float orbit = length(p);
        float waveA = sin((p.x * 7.0 + p.y * 4.0) + u.time * (0.32 + u.pulseRate * 0.18));
        float waveB = cos((p.x * -3.0 + p.y * 8.0) - u.time * (0.18 + u.turbulence * 0.32));
        float interference = (waveA + waveB) * 0.5;
        float centerGlow = exp(-orbit * orbit * (2.2 - u.coherence * 0.9));
        float upperGlow = exp(-length(p - float2(-0.14, 0.36)) * (2.4 + u.entropy * 0.7));
        float lowerGlow = exp(-length(p - float2(0.22, -0.52)) * 2.8);
        float pressure = smoothstep(0.72, 0.06, abs(orbit - (0.44 + interference * 0.025)));

        float3 color = u.shadow.rgb * (0.54 + u.entropy * 0.22);
        color += u.primary.rgb * centerGlow * (0.19 + u.glow * 0.25);
        color += u.secondary.rgb * upperGlow * (0.10 + u.coherence * 0.12);
        color += u.accent.rgb * lowerGlow * (0.08 + u.entropy * 0.10);
        color += (u.primary.rgb + u.accent.rgb) * pressure * (0.020 + u.glow * 0.028);
        color += float3(0.014, 0.018, 0.030) * (1.0 - smoothstep(0.0, 1.2, orbit));

        float vignette = smoothstep(1.36, 0.18, orbit);
        color *= 0.36 + vignette * 0.86;
        return half4(half3(color), 1.0);
    }

    vertex ParticleOut particleVertex(
        const device BiofieldParticleVertex *vertices [[buffer(0)]],
        constant BiofieldShaderUniforms &u [[buffer(1)]],
        uint vertexID [[vertex_id]]
    ) {
        BiofieldParticleVertex particle = vertices[vertexID];
        float perspective = 1.0 / (1.0 + max(particle.position.z, 0.0) * 0.46);
        float2 position = particle.position.xy * perspective;

        ParticleOut out;
        out.position = float4(position, 0.0, 1.0);
        out.color = particle.color;
        out.pointSize = max(1.2, particle.pointSize * (0.88 + perspective * 0.52));
        out.glow = particle.glow;
        return out;
    }

    fragment half4 particleFragment(
        ParticleOut in [[stage_in]],
        float2 pointCoord [[point_coord]]
    ) {
        float2 uv = pointCoord * 2.0 - 1.0;
        float radius = length(uv);
        if (radius > 1.0) {
            discard_fragment();
        }

        float core = pow(saturate(1.0 - radius), 2.8);
        float halo = pow(saturate(1.0 - radius), 0.62) * 0.34;
        float rim = pow(saturate(1.0 - abs(radius - 0.58) * 2.4), 2.2) * 0.22 * in.glow;
        float energy = core * 1.22 + halo + rim;
        float alpha = in.color.a * saturate(core * 1.35 + halo * 0.72 + rim);
        float3 color = in.color.rgb * energy;
        return half4(half3(color), half(alpha));
    }
    """
}
