// Copyright (c) 2021 Jeff Hutchinson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

struct ParticleData
{
   vector_float4 position;
   vector_float4 velocity;
   vector_float4 color;
   float lifeTime;
   float lifeTimeMax;
};

struct VertexOut
{
   vector_float4 position [[position]];
   vector_float4 color;
   float point_size [[point_size]];
};

struct RenderUniforms
{
   matrix_float4x4 projViewMatrix;
   float timeDeltaMS;
};

vertex VertexOut particleVertMain
(
   const constant ParticleData* vertex_buffer [[buffer(0)]],
   const constant RenderUniforms* uniforms [[buffer(1)]],
   unsigned int vertexId [[vertex_id]]
)
{
   VertexOut output;
   output.position = uniforms->projViewMatrix * vertex_buffer[vertexId].position;
   output.color = vertex_buffer[vertexId].color;
   output.point_size = 8.0;
   
   return output;
}

fragment vector_float4 particleFragMain(VertexOut fragData [[stage_in]])
{
   return fragData.color;
}

kernel void particleComputeMain(
   device ParticleData* buffer [[buffer(0)]],
   constant RenderUniforms *uniforms [[buffer(1)]],
   unsigned int index [[thread_position_in_grid]]
)
{
   float dt = uniforms->timeDeltaMS;

   buffer[index].position += buffer[index].velocity * (dt / 1000.0f);
   buffer[index].lifeTime += dt;
   
   if (buffer[index].lifeTime > buffer[index].lifeTimeMax)
   {
      buffer[index].position = (vector_float4){0.0, 0.0, 0.0, 1.0};
      buffer[index].lifeTime = 0;
   }
}
