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

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <simd/simd.h>
#import <MBEMathUtilities.h>

#define WINDOW_WIDTH 1600
#define WINDOW_HEIGHT 900
#define MAX_NUMBER_PARTICLES 50
#define PARTICLE_TIME_MAX_MS 3000.0f

struct ParticleData
{
   simd_float4 position;
   simd_float4 velocity;
   simd_float4 color;
   float lifeTime;
   float lifeTimeMax;
};

struct RenderUniforms
{
   matrix_float4x4 projViewMatrix;
   float deltaMS;
};

const simd_float4 FLOAT4_ZERO = (simd_float4){0.0f, 0.0f, 0.0f, 0.0f};

static id<MTLRenderPipelineState> genRenderPipelineDescriptor(id<MTLDevice> device, MTLPixelFormat pixelFormat)
{
   NSError* error = nil;

   id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
   id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"particleVertMain"];
   id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"particleFragMain"];

   MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
   pipelineStateDescriptor.label = @"Render Particle Pipeline";
   pipelineStateDescriptor.vertexFunction = vertexFunction;
   pipelineStateDescriptor.fragmentFunction = fragmentFunction;
   pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat;

   id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
   if (error)
   {
      printf("Error with pipeline state: %s\n", [error.localizedDescription UTF8String]);
      exit(1);
   }
   
   return pipelineState;
}

void resetParticle(ParticleData &p)
{
   float x = (float)(rand() % 1000) - 500.0;
   float y = (float)(rand() % 1000) - 500.0;
   float z = (float)(rand() % 1000) - 500.0;
   
   simd_float3 vel = (simd_float3){x, y, z};
   simd_float3 velocity = simd_normalize(vel);
   
   p.position = (simd_float4){0.0, 0.0, 0.0, 1.0};
   p.velocity = (simd_float4){velocity.x, velocity.y, velocity.z, 1.0f};
   p.color = (simd_float4){0.0f, 1.0f, 1.0f, 1.0f};
   p.lifeTime = 0.0f;
   p.lifeTimeMax = (PARTICLE_TIME_MAX_MS - 1000.0f) - (float)((rand() % 10 + 1) * 100);
}

int main(int argc, char* argv[])
{
   const id<MTLDevice> device = MTLCreateSystemDefaultDevice();
   const id<MTLCommandQueue> queue = [device newCommandQueue];
   CAMetalLayer *swapChain = [CAMetalLayer layer];
   swapChain.framebufferOnly = YES;
   swapChain.device = device;
   swapChain.opaque = YES;
   
   glfwInit();
   glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
   GLFWwindow *window = glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Metal Particle Simulation", NULL, NULL);
   NSWindow *nswindow = glfwGetCocoaWindow(window);
   nswindow.contentView.layer = swapChain;
   nswindow.contentView.wantsLayer = YES;
   
   float aspect = (float)WINDOW_WIDTH/(float)WINDOW_HEIGHT;
   float fov = M_PI_2;
   //matrix_float4x4 projMatrix = matrix_float4x4_perspective(aspect, fov, 0.01f, 500.0f);
   matrix_float4x4 projMatrix = matrix_identity_float4x4;
   
   matrix_float4x4 pitch = matrix_float4x4_rotation((vector_float3){1,0,0}, 0.f);
   matrix_float4x4 yaw = matrix_float4x4_rotation((vector_float3){0,0,1}, 0.f);
   matrix_float4x4 position = matrix_float4x4_translation((vector_float3){0.f, 0.f, 0.f}); // 1.8f, 2.0f, -1.85f
   matrix_float4x4 viewMatrix = matrix_multiply(matrix_multiply(pitch, yaw), position);
   
   RenderUniforms renderUniforms;
   renderUniforms.projViewMatrix = matrix_multiply(projMatrix, viewMatrix);
   renderUniforms.deltaMS = 0;
   
   id<MTLRenderPipelineState> renderPipelineState = genRenderPipelineDescriptor(device, swapChain.pixelFormat);
   
   ParticleData* particleData = new ParticleData[MAX_NUMBER_PARTICLES];
   for (int i = 0; i < MAX_NUMBER_PARTICLES; ++i)
   {
      ParticleData &p = particleData[i];
      resetParticle(p);
   }
   
//   id<MTLBuffer> particleVertexBuffer = [device
//      newBufferWithBytes:particleData
//      length:MAX_NUMBER_PARTICLES * sizeof(ParticleData)
//      options:MTLResourceStorageModeManaged
//   ];

   double lastTimeStamp = glfwGetTime();
   
   while (!glfwWindowShouldClose(window))
   {
      glfwPollEvents();

      double currentTime = glfwGetTime();
      double dt = (currentTime - lastTimeStamp) * 1000;
      lastTimeStamp = currentTime;
      
      renderUniforms.deltaMS = dt;
      
      float deltaSeconds = (float)(dt / 1000.0f);
      for (int i = 0; i < MAX_NUMBER_PARTICLES; ++i)
      {
         ParticleData& p = particleData[i];
         p.position += p.velocity * deltaSeconds;
         p.lifeTime += (float)dt;

         if (p.lifeTime > p.lifeTimeMax)
         {
            resetParticle(p);
         }
      }
      
      @autoreleasepool {
         id<CAMetalDrawable> surface = [swapChain nextDrawable];
         id<MTLCommandBuffer> cmdBuffer = [queue commandBuffer];
         
         MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
         renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
         renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
         renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
         renderPass.colorAttachments[0].texture = surface.texture;
         
         id<MTLRenderCommandEncoder> cmdEncoder = [cmdBuffer renderCommandEncoderWithDescriptor:renderPass];
         [cmdEncoder setViewport:(MTLViewport){0.0, 0.0, (float)WINDOW_WIDTH, (float)WINDOW_HEIGHT, 0.0, 1.0}];
         [cmdEncoder setRenderPipelineState:renderPipelineState];
         //[cmdEncoder setVertexBuffer:particleVertexBuffer offset:0 atIndex:0];
         [cmdEncoder setVertexBytes:particleData length:sizeof(ParticleData) * MAX_NUMBER_PARTICLES atIndex:0];
         [cmdEncoder setVertexBytes:&renderUniforms length:sizeof(renderUniforms) atIndex:1];

         [cmdEncoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:MAX_NUMBER_PARTICLES];
         [cmdEncoder endEncoding];
         
         [cmdBuffer presentDrawable:surface];
         [cmdBuffer commit];
      }
   }
   
   delete[] particleData;
   glfwDestroyWindow(window);
   glfwTerminate();
}
