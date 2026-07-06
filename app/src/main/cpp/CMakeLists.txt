cmake_minimum_required(VERSION 3.22.1)

project(navi_jpeg)

# Debug APK 也用于真机性能测试；Android Gradle 的 Debug native 默认偏调试，
# libjpeg-turbo 在无优化时会明显变慢，因此这里强制 native 编码路径使用 O3。
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O3 -DNDEBUG")

set(ENABLE_SHARED OFF CACHE BOOL "Build shared libraries" FORCE)
set(ENABLE_STATIC ON CACHE BOOL "Build static libraries" FORCE)
set(WITH_TURBOJPEG ON CACHE BOOL "Build TurboJPEG API library" FORCE)
set(WITH_TOOLS OFF CACHE BOOL "Build command-line tools" FORCE)
set(WITH_TESTS OFF CACHE BOOL "Build regression tests" FORCE)
set(WITH_JAVA OFF CACHE BOOL "Build Java support" FORCE)

add_subdirectory(libjpeg-turbo libjpeg-turbo-build EXCLUDE_FROM_ALL)

add_library(navi_jpeg SHARED navi_jpeg.cpp)

target_include_directories(navi_jpeg PRIVATE libjpeg-turbo/src)

target_link_libraries(
    navi_jpeg
    jnigraphics
    log
    turbojpeg-static
)
