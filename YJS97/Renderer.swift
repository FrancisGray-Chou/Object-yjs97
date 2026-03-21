import MetalKit
import simd

struct BoundingBox {
    var minBounds: simd_float3
    var maxBounds: simd_float3
    func intersects(_ other: BoundingBox) -> Bool {
        return
            (minBounds.x <= other.maxBounds.x
            && maxBounds.x >= other.minBounds.x)
            && (minBounds.y <= other.maxBounds.y
                && maxBounds.y >= other.minBounds.y)
            && (minBounds.z <= other.maxBounds.z
                && maxBounds.z >= other.minBounds.z)
    }
}
struct Vertex {
    var position: simd_float4  // 3D position
    var texCoord: simd_float2  // texture(u, v)

}

func rotationYMatrix(angle: Float) -> simd_float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    return simd_float4x4(
        simd_float4(c, 0, -s, 0),
        simd_float4(0, 1, 0, 0),
        simd_float4(s, 0, c, 0),
        simd_float4(0, 0, 0, 1)
    )
}

func rotationXMatrix(angle: Float) -> simd_float4x4 {
    let c = cos(angle)
    let s = sin(angle)
    return simd_float4x4(
        simd_float4(1, 0, 0, 0),
        simd_float4(0, c, s, 0),
        simd_float4(0, -s, c, 0),
        simd_float4(0, 0, 0, 1)
    )
}

func translationMatrix(x: Float, y: Float, z: Float) -> simd_float4x4 {
    return simd_float4x4(
        simd_float4(1, 0, 0, 0),
        simd_float4(0, 1, 0, 0),
        simd_float4(0, 0, 1, 0),
        simd_float4(x, y, z, 1)
    )
}

func scaleMatrix(x: Float, y: Float, z: Float) -> simd_float4x4 {
    return simd_float4x4(
        simd_float4(x, 0, 0, 0),
        simd_float4(0, y, 0, 0),
        simd_float4(0, 0, z, 0),
        simd_float4(0, 0, 0, 1)
    )
}

func perspectiveMatrix(fov: Float, aspect: Float, nearZ: Float, farZ: Float)
    -> simd_float4x4
{
    let y = 1.0 / tan(fov * 0.5)
    let x = y / aspect
    let z = farZ / (farZ - nearZ)
    let w = -(farZ * nearZ) / (farZ - nearZ)
    return simd_float4x4(
        simd_float4(x, 0, 0, 0),
        simd_float4(0, y, 0, 0),
        simd_float4(0, 0, z, 1),
        simd_float4(0, 0, w, 0)
    )
}

class GameObject {
    var position: simd_float3
    var rotation: simd_float3
    var scale: simd_float3
    var texture: MTLTexture?

    var name: String = ""
    var isColleted: Bool = false

    var boundingBox: BoundingBox {
        let halfsize = scale / 2.0
        return BoundingBox(
            minBounds: position - halfsize,
            maxBounds: position + halfsize
        )
    }

    init(position: simd_float3, texture: MTLTexture?) {
        self.position = position
        self.rotation = simd_float3(0, 0, 0)
        self.scale = simd_float3(1, 1, 1)
        self.texture = texture
    }

    // 计算实体的 Model 矩阵：缩放 -> 旋转 -> 平移
    func modelMatrix() -> simd_float4x4 {
        let s = scaleMatrix(x: scale.x, y: scale.y, z: scale.z)
        let rotX = rotationXMatrix(angle: rotation.x)
        let rotY = rotationYMatrix(angle: rotation.y)
        let t = translationMatrix(x: position.x, y: position.y, z: position.z)

        return t * rotY * rotX * s
    }
}

func lookAtMatrix(eye: simd_float3, center: simd_float3, up: simd_float3)
    -> simd_float4x4
{
    let z = normalize(center - eye)  // 眼睛看向目标的方向
    let x = normalize(cross(up, z))  // 算出摄像机的“右边”
    let y = cross(z, x)  // 算出摄像机的“正上方”

    return simd_float4x4(
        simd_float4(x.x, y.x, z.x, 0),
        simd_float4(x.y, y.y, z.y, 0),
        simd_float4(x.z, y.z, z.z, 0),
        simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
    )
}

class Camera {
    var position: simd_float3 = [0, 0, 0]
    var yaw: Float = 0
    var pitch: Float = 0

    var forward: simd_float3 {
        return [
            sin(yaw) * cos(pitch),
            sin(pitch),
            cos(yaw) * cos(pitch),
        ]
    }

    var right: simd_float3 {
        return simd_normalize(simd_cross(simd_float3(0, 1, 0), forward))
    }

    var boundingBox: BoundingBox {
        let radius: Float = 0.3
        return BoundingBox(
            minBounds: position - simd_float3(radius, radius, radius),
            maxBounds: position + simd_float3(radius, radius, radius)
        )
    }

    func viewMatrix() -> simd_float4x4 {
        // 根据当前的转头角度 (yaw, pitch) 算出正在盯着的正前方
        let forward = simd_float3(
            sin(yaw) * cos(pitch),
            sin(pitch),
            cos(yaw) * cos(pitch)
        )

        let target = position + forward  // 眼睛位置 + 朝向 = 视线焦点

        return lookAtMatrix(
            eye: position,
            center: target,
            up: simd_float3(0, 1, 0)
        )
    }

    func processMouseMovement(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.0005
        yaw += deltaX * sensitivity
        pitch -= deltaY * sensitivity

        let pitchLimit = Float.pi / 2.0 - 0.01
        if pitch > pitchLimit { pitch = pitchLimit }
        if pitch < -pitchLimit { pitch = -pitchLimit }
    }
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var depthState: MTLDepthStencilState!

    var time: Float = 0.0

    // 游戏资源
    var catTexture: MTLTexture!
    var dirtTexture: MTLTexture!

    // 游戏世界实体列表
    var gameObjects: [GameObject] = []
    var camera = Camera()
    var pressedKeys: Set<String> = []
    var scores: Int = 0

    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        super.init()

        // 天空颜色，稍微调蓝一点点，像白天的天空
        metalKitView.clearColor = MTLClearColor(
            red: 0.2,
            green: 0.3,
            blue: 0.4,
            alpha: 1.0
        )
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.delegate = self

        setupPipeline()
        setupBuffer()
        setupTexture()
        camera.position = simd_float3(0, 0.5, -2.0)
    }

    func setupTexture() {
        let textureLoader = MTKTextureLoader(device: device)

        // 1. 加载猫咪
        if let catUrl = Bundle.main.url(
            forResource: "yjs",
            withExtension: "png"
        ) {
            do {
                catTexture = try textureLoader.newTexture(
                    URL: catUrl,
                    options: nil
                )
            } catch { print("猫咪加载失败: \(error)") }
        }

        // 2. 加载泥土（⚠️ 监控探头已部署）
        if let dirtUrl = Bundle.main.url(
            forResource: "dirt",
            withExtension: "png"
        ) {
            do {
                dirtTexture = try textureLoader.newTexture(
                    URL: dirtUrl,
                    options: nil
                )
                print("🎉🎉🎉 泥土图片加载成功！")
            } catch {
                print("泥土解码失败: \(error)")
            }
        } else {
            // 如果执行了这句话，100% 说明没打勾，或者文件名写错了！
            print(
                "致命问题：安装包里根本没有找到 dirt.png！请检查：1.名字对不对？ 2.右侧 Target Membership 到底有没有打勾？"
            )
        }

        setupWorld()
    }

    func setupWorld() {
        // 1. 创建地面
        let ground = GameObject(
            position: simd_float3(0, -1.0, 3.0),
            texture: dirtTexture
        )
        // ✨ 将地面在 X 和 Z 轴放大 5 倍，Y 轴压扁，做成大地板！
        ground.scale = simd_float3(5.0, 0.1, 5.0)

        // 2. 创建猫咪收集物 (悬浮在地面上)
        let catBox = GameObject(
            position: simd_float3(0, 0, 3.0),
            texture: catTexture,
        )
        catBox.name = "cat"

        gameObjects.append(ground)
        gameObjects.append(catBox)
    }

    func setupBuffer() {
        let vertices = [
            // 前面 (Front)
            Vertex(position: [-0.5, 0.5, 0.5, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [-0.5, -0.5, 0.5, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [0.5, -0.5, 0.5, 1.0], texCoord: [1.0, 1.0]),
            Vertex(position: [0.5, 0.5, 0.5, 1.0], texCoord: [1.0, 0.0]),
            // 后面 (Back)
            Vertex(position: [0.5, 0.5, -0.5, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [0.5, -0.5, -0.5, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [-0.5, -0.5, -0.5, 1.0], texCoord: [1.0, 1.0]),
            Vertex(position: [-0.5, 0.5, -0.5, 1.0], texCoord: [1.0, 0.0]),
            // 左面 (Left)
            Vertex(position: [-0.5, 0.5, -0.5, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [-0.5, -0.5, -0.5, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [-0.5, -0.5, 0.5, 1.0], texCoord: [1.0, 1.0]),
            Vertex(position: [-0.5, 0.5, 0.5, 1.0], texCoord: [1.0, 0.0]),
            // 右面 (Right)
            Vertex(position: [0.5, 0.5, 0.5, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [0.5, -0.5, 0.5, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [0.5, -0.5, -0.5, 1.0], texCoord: [1.0, 1.0]),
            Vertex(position: [0.5, 0.5, -0.5, 1.0], texCoord: [1.0, 0.0]),
            // 上面 (Top)
            Vertex(position: [-0.5, 0.5, -0.5, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [-0.5, 0.5, 0.5, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [0.5, 0.5, 0.5, 1.0], texCoord: [1.0, 1.0]),
            Vertex(position: [0.5, 0.5, -0.5, 1.0], texCoord: [1.0, 0.0]),
            // 下面 (Bottom)
            Vertex(position: [-0.5, -0.5, 0.5, 1.0], texCoord: [0.0, 0.0]),
            Vertex(position: [-0.5, -0.5, -0.5, 1.0], texCoord: [0.0, 1.0]),
            Vertex(position: [0.5, -0.5, -0.5, 1.0], texCoord: [1.0, 1.0]),
            Vertex(position: [0.5, -0.5, 0.5, 1.0], texCoord: [1.0, 0.0]),
        ]

        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0,
            4, 5, 6, 6, 7, 4,
            8, 9, 10, 10, 11, 8,
            12, 13, 14, 14, 15, 12,
            16, 17, 18, 18, 19, 16,
            20, 21, 22, 22, 23, 20,
        ]

        let vertexLength = vertices.count * MemoryLayout<Vertex>.stride
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertexLength,
            options: .storageModeShared
        )
        let indexLength = indices.count * MemoryLayout<UInt16>.stride
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: indexLength,
            options: .storageModeShared
        )
    }

    func setupPipeline() {
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            pipelineState = try device.makeRenderPipelineState(
                descriptor: pipelineDescriptor
            )
        } catch {
            print("渲染管线创建失败: \(error)")
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor
            )
        else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projection = perspectiveMatrix(
            fov: Float.pi / 3.0,
            aspect: aspect,
            nearZ: 0.1,
            farZ: 100.0
        )

        time += 0.016

        // 更新猫咪方块的旋转角度
        if gameObjects.count > 1 {
            gameObjects[1].rotation.y = time
            gameObjects[1].rotation.x = time * 0.5
        }
        //Move
        let moveSpeed: Float = 0.05
        if pressedKeys.contains("w") {
            camera.position += camera.forward * moveSpeed
        }  // 往前走
        if pressedKeys.contains("s") {
            camera.position -= camera.forward * moveSpeed
        }  // 往后退
        if pressedKeys.contains("a") {
            camera.position -= camera.right * moveSpeed
        }  // 往左走 (减去右边)
        if pressedKeys.contains("d") {
            camera.position += camera.right * moveSpeed
        }  // 往右走
        if pressedKeys.contains(" ") { camera.position.y += moveSpeed }

        //实体渲染循环！
        let viewMatrix = camera.viewMatrix()

        for object in gameObjects {
            if object.isColleted { continue }
            if object.name == "cat" {
                if camera.boundingBox.intersects(object.boundingBox) {
                    object.isColleted = true
                    scores += 1
                    print("+1")
                    continue
                }
            }
            let modelMatrix = object.modelMatrix()
            var finalMatrix = projection * viewMatrix * modelMatrix
            renderEncoder.setVertexBytes(
                &finalMatrix,
                length: MemoryLayout<simd_float4x4>.size,
                index: 1
            )
            if let tex = object.texture {
                renderEncoder.setFragmentTexture(tex, index: 0)
            }
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 36,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
