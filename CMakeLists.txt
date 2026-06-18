cmake_minimum_required(VERSION 3.16)
project(sriov LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Vulkan REQUIRED)

add_executable(sriov main.cpp)
target_link_libraries(sriov PRIVATE Vulkan::Vulkan)
target_compile_definitions(sriov PRIVATE VK_USE_PLATFORM_XLIB_KHR)

# Static linking for C++ runtime (libvulkan must remain dynamic)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc -static-libstdc++")
