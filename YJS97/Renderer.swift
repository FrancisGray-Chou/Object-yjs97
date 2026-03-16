import MetalKit
import simd

struct Vertex{
    var position: simd_float4 //3D position
    var texCoord: simd_float2 //texture(u, v)
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!
    
    var vertexBuffer: MTLBuffer! //to save the vertex data's MEM buffer area.
    var indexBuffer: MTLBuffer! //to save index number's buffer area.
    
    var time: Float = 0.0
    var texture: MTLTexture!
    
    var depthState: MTLDepthStencilState!
    

    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        super.init()

        // 设置画板的背景色：暗灰色
        metalKitView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalKitView.depthStencilPixelFormat = .depth32Float
        metalKitView.delegate = self

        setupPipeline()
        setupBuffer()
        setupTexture()
    }
    
    func setupTexture() {
            let textureLoader = MTKTextureLoader(device: device)
            
            // 1. 直接在项目根目录找这个文件
            guard let url = Bundle.main.url(forResource: "yjs", withExtension: "png") else {
                print("文件没找到，请确认图片已经拖进左侧列表，并且名字和后缀是对的！")
                return
            }
            
            // 2. 通过 URL 强制加载
            do {
                texture = try textureLoader.newTexture(URL: url, options: nil)
                print("方案加载成功！")
            } catch {
                print("URL加载失败：\(error)")
            }
        }
    
    func setupBuffer() {
            // 注意：每个 position 后面都加了一个 1.0
            let vertices = [
                // 前面 (Front)
                Vertex(position: [-0.5,  0.5,  0.5, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [-0.5, -0.5,  0.5, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [ 0.5, -0.5,  0.5, 1.0], texCoord: [1.0, 1.0]),
                Vertex(position: [ 0.5,  0.5,  0.5, 1.0], texCoord: [1.0, 0.0]),
                // 后面 (Back)
                Vertex(position: [ 0.5,  0.5, -0.5, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [ 0.5, -0.5, -0.5, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [-0.5, -0.5, -0.5, 1.0], texCoord: [1.0, 1.0]),
                Vertex(position: [-0.5,  0.5, -0.5, 1.0], texCoord: [1.0, 0.0]),
                // 左面 (Left)
                Vertex(position: [-0.5,  0.5, -0.5, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [-0.5, -0.5, -0.5, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [-0.5, -0.5,  0.5, 1.0], texCoord: [1.0, 1.0]),
                Vertex(position: [-0.5,  0.5,  0.5, 1.0], texCoord: [1.0, 0.0]),
                // 右面 (Right)
                Vertex(position: [ 0.5,  0.5,  0.5, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [ 0.5, -0.5,  0.5, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [ 0.5, -0.5, -0.5, 1.0], texCoord: [1.0, 1.0]),
                Vertex(position: [ 0.5,  0.5, -0.5, 1.0], texCoord: [1.0, 0.0]),
                // 上面 (Top)
                Vertex(position: [-0.5,  0.5, -0.5, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [-0.5,  0.5,  0.5, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [ 0.5,  0.5,  0.5, 1.0], texCoord: [1.0, 1.0]),
                Vertex(position: [ 0.5,  0.5, -0.5, 1.0], texCoord: [1.0, 0.0]),
                // 下面 (Bottom)
                Vertex(position: [-0.5, -0.5,  0.5, 1.0], texCoord: [0.0, 0.0]),
                Vertex(position: [-0.5, -0.5, -0.5, 1.0], texCoord: [0.0, 1.0]),
                Vertex(position: [ 0.5, -0.5, -0.5, 1.0], texCoord: [1.0, 1.0]),
                Vertex(position: [ 0.5, -0.5,  0.5, 1.0], texCoord: [1.0, 0.0])
            ]
            
            let indices: [UInt16] = [
                 0,  1,  2,  2,  3,  0,
                 4,  5,  6,  6,  7,  4,
                 8,  9, 10, 10, 11,  8,
                12, 13, 14, 14, 15, 12,
                16, 17, 18, 18, 19, 16,
                20, 21, 22, 22, 23, 20
            ]
            
            let vertexLength = vertices.count * MemoryLayout<Vertex>.stride
            vertexBuffer = device.makeBuffer(bytes: vertices, length: vertexLength, options: .storageModeShared)
            let indexLength = indices.count * MemoryLayout<UInt16>.stride
            indexBuffer = device.makeBuffer(bytes: indices, length: indexLength, options: .storageModeShared)
        }
    
    func rotationYMatrix(angle: Float) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        
        return simd_float4x4(
            simd_float4( c, 0, -s, 0),
            simd_float4( 0, 1, 0, 0),
            simd_float4( s, 0, c, 0),
            simd_float4( 0, 0, 0, 1)
        )
    }
    func rotationXMatrix(angle: Float) -> simd_float4x4 {
            let c = cos(angle)
            let s = sin(angle)
            return simd_float4x4(
                simd_float4(1,  0,  0, 0),
                simd_float4(0,  c,  s, 0),
                simd_float4(0, -s,  c, 0),
                simd_float4(0,  0,  0, 1)
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

    func perspectiveMatrix(fov: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
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
    func setupPipeline() {
        // 1. 刚才重写的 Shaders.metal 中加载函数
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")

        // 2. 配置渲染管线描述符
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm // 默认的颜色像素格式
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        // 3. 让 GPU 编译并创建这个管线状态 (PipelineState)
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("渲染管线创建失败: \(error)")
        }
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    // 每一帧都会自动调用这个方法来进行绘制 (通常是 60 次/秒)
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        // --- 核心绘制指令开始 ---
        
        // 绑定创渲染管线
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0) //把装有数据的 Buffer 绑定到第 0 号通道
        time += 0.016
        let rotY = rotationYMatrix(angle: time)
                let rotX = rotationXMatrix(angle: time * 0.5) // X轴转慢一点
                let rotation = rotY * rotX
        let translation = translationMatrix(x: 0, y: 0, z: 2.5)
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projection = perspectiveMatrix(fov: Float.pi / 3.0, aspect: aspect, nearZ: 0.1, farZ: 100.0)
        var finalMatrix = projection * translation * rotation
        if let myValidTexture = self.texture {
                    // 如果图片真的存在，就传给 GPU 的 0 号通道
                    renderEncoder.setFragmentTexture(myValidTexture, index: 0)
                } else {
                    // 如果跑到这里，说明图片根本没加载进内存！
                    print("🚨 警告：准备画图了，但是 texture 变量居然是空的！")
                }
        renderEncoder.setVertexBytes(&finalMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)
        
        
        // indexCount: 一共要画几个点（我们的 indices 数组有 36 个数字）
        // indexType: 我们用的数据类型是 16位无符号整数 (.uint16)
        // indexBuffer: 传入刚才创建的索引缓冲区
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 36, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        // --- 核心绘制指令结束 ---
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // 窗口大小改变时的回调，暂时不需要写逻辑
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
