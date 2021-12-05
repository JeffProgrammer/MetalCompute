cmake_minimum_required(VERSION 3.18 FATAL_ERROR)

project(MetalCompute)
set (CMAKE_CXX_STANDARD 17)

add_subdirectory(thirdparty/glfw)

include_directories(
    thirdparty/glfw/include
    thirdparty/mbe
    src
)

add_library(mbe thirdparty/mbe/MBEMathUtilities.mm)

set(METAL_SOURCE 
    src/main.mm
    src/particles.metal
)

add_executable(MetalCompute ${METAL_SOURCE})
target_link_libraries(MetalCompute
    glfw
    mbe
    "-framework Metal"
    "-framework Foundation"
    "-framework QuartzCore"
)

set(RESOURCE_FILES
    src/particles.metal
)

set_target_properties(MetalCompute PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_FRAMEWORK_IDENTIFIER com.github.jeffprogrammer.metalcompute
  RESOURCE "${RESOURCE_FILES}")