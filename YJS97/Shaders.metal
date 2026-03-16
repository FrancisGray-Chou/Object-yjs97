#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              device const VertexIn *vertices [[buffer(0)]],
                              constant float4x4 &transformMatrix [[buffer(1)]]) {
    
    VertexOut out;
    out.position = transformMatrix * vertices[vertexID].position;
    out.texCoord = vertices[vertexID].texCoord;
        
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> colorTexture [[texture(0)]]) {
    
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    float4 textureColor = colorTexture.sample(textureSampler, in.texCoord);
    return textureColor;
    
    //return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
}
