cmake_minimum_required(VERSION 3.15)
project(FBX2glTF)

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15")

set(typical_usage_str
  "Example usage:\n\
  > mkdir -p build_debug\n\
  > conan install . -i build_debug -s build_type=Debug -e FBXSDK_SDKS=/home/zell/FBXSDK\n\
  > conan build . -bf build_debug")

if ("${CMAKE_CURRENT_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
  message(FATAL_ERROR
    "Building from within the source tree is not supported! ${typical_usage_str}")
endif ()

set(CMAKE_CXX_STANDARD 17)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}")
include(ExternalProject)

set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
find_package(Threads REQUIRED)

list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_BINARY_DIR}")

# stuff
find_package(LibXml2 REQUIRED)
find_package(ZLIB REQUIRED)
find_package(fmt CONFIG REQUIRED)

# fbx sdk
if (NOT DEFINED FbxSdkHome)
    message(FATAL_ERROR "You must specify the FBX SDK home.")
endif ()
message (STATUS "FBX SDK home: ${FbxSdkHome}")

# https://blog.kitware.com/cmake-and-the-default-build-type/
message (STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
if (NOT CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "Debug")
  set (FbxSdkConfiguration "debug")
else ()
  set (FbxSdkConfiguration "release")
endif ()
message (STATUS "FBX SDK configuration: ${FbxSdkConfiguration}")

message (STATUS "CMAKE_CXX_COMPILER_ID: ${CMAKE_CXX_COMPILER_ID}")
set (FBXSDK_INCLUDE_DIR "${FbxSdkHome}/include")
if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    if (EXISTS "${FbxSdkHome}/lib/vs2022")
        set (FBXSDK_LIBRARY "${FbxSdkHome}/lib/vs2022/x64/${FbxSdkConfiguration}/libfbxsdk-mt.lib")
    elseif (EXISTS "${FbxSdkHome}/lib/vs2019")
        set (FBXSDK_LIBRARY "${FbxSdkHome}/lib/vs2019/x64/${FbxSdkConfiguration}/libfbxsdk-mt.lib")
    else ()
        set (FbxSdkLibraries "${FbxSdkHome}/lib/vs2017/x64/${FbxSdkConfiguration}/libfbxsdk-mt.lib")
    endif ()
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set (FBXSDK_LIBRARY "${FbxSdkHome}/lib/clang/${FbxSdkConfiguration}/libfbxsdk.a")
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set (FBXSDK_LIBRARY "${FbxSdkHome}/lib/gcc/x64/${FbxSdkConfiguration}/libfbxsdk.a")
else ()
    message (FATAL_ERROR "Can not decide FBX SDK library to use cause of unknown C++ compiler ID: ${CMAKE_CXX_COMPILER_ID}")
endif ()
message (STATUS "FBX SDK include directories: ${FBXSDK_INCLUDE_DIR}")
message (STATUS "FBX SDK libraries: ${FBXSDK_LIBRARY}")

# DRACO
set(DRACO_INSTALL_DIR "${CMAKE_BINARY_DIR}/draco/install")
set(ARCH_FLAGS "")
if (APPLE)
    set(ARCH_FLAGS "-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64")
endif()

ExternalProject_Add(Draco
  GIT_REPOSITORY https://github.com/google/draco
  GIT_TAG 1.3.4
  PREFIX draco
  INSTALL_DIR "${DRACO_INSTALL_DIR}"
  CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=${DRACO_INSTALL_DIR}
        -DBUILD_FOR_GLTF=1
        ${ARCH_FLAGS}
)

set(DRACO_INCLUDE_DIR "${DRACO_INSTALL_DIR}/include")
if (WIN32)
    set(DRACO_LIB "${DRACO_INSTALL_DIR}/lib/dracoenc.lib")
else()
    set(DRACO_LIB "${DRACO_INSTALL_DIR}/lib/libdracoenc.a")
endif()

# MATHFU
set(mathfu_build_benchmarks OFF CACHE BOOL "")
set(mathfu_build_tests OFF CACHE BOOL "")
ExternalProject_Add(MathFu
  PREFIX mathfu
  GIT_REPOSITORY https://github.com/google/mathfu
  GIT_TAG v1.1.0
  CONFIGURE_COMMAND ${CMAKE_COMMAND} -E echo "Skipping MathFu configure step."
  BUILD_COMMAND ${CMAKE_COMMAND} -E echo "Skipping MathFu build step."
  INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Skipping MathFu install step."
)
set(MATHFU_INCLUDE_DIRS
        "${CMAKE_BINARY_DIR}/mathfu/src/MathFu/include/"
        "${CMAKE_BINARY_DIR}/mathfu/src/MathFu/dependencies/vectorial/include")

# OrderedMap
ExternalProject_Add(FiFoMap
  PREFIX fifo_map
  GIT_REPOSITORY https://github.com/nlohmann/fifo_map
  CONFIGURE_COMMAND ${CMAKE_COMMAND} -E echo "Skipping FiFoMap configure step."
  BUILD_COMMAND ${CMAKE_COMMAND} -E echo "Skipping FiFoMap build step."
  INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Skipping FiFoMap install step."
)
set(FIFO_MAP_INCLUDE_DIR "${CMAKE_BINARY_DIR}/fifo_map/src/FiFoMap/src")

# cppcodec
ExternalProject_Add(CPPCodec
  PREFIX cppcodec
  GIT_REPOSITORY https://github.com/tplgy/cppcodec
  CONFIGURE_COMMAND ${CMAKE_COMMAND} -E echo "Skipping CPPCodec configure step."
  BUILD_COMMAND ${CMAKE_COMMAND} -E echo "Skipping CPPCodec build step."
  INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "Skipping CPPCodec install step."
)
set(CPPCODEC_INCLUDE_DIR "${CMAKE_BINARY_DIR}/cppcodec/src/CPPCodec")

if (APPLE)
    find_library(CF_FRAMEWORK CoreFoundation)
    message("CoreFoundation Framework: ${CF_FRAMEWORK}")
    set(FRAMEWORKS ${CF_FRAMEWORK})
endif()

set(LIB_SOURCE_FILES
        src/FBX2glTF.h
        src/fbx/materials/3dsMaxPhysicalMaterial.cpp
        src/fbx/materials/FbxMaterials.cpp
        src/fbx/materials/FbxMaterials.hpp
        src/fbx/materials/RoughnessMetallicMaterials.hpp
        src/fbx/materials/StingrayPBSMaterial.cpp
        src/fbx/materials/TraditionalMaterials.cpp
        src/fbx/materials/TraditionalMaterials.hpp
        src/fbx/Fbx2Raw.cpp
        src/fbx/Fbx2Raw.hpp
        src/fbx/FbxBlendShapesAccess.cpp
        src/fbx/FbxBlendShapesAccess.hpp
        src/fbx/FbxLayerElementAccess.hpp
        src/fbx/FbxSkinningAccess.cpp
        src/fbx/FbxSkinningAccess.hpp
        src/gltf/Raw2Gltf.cpp
        src/gltf/Raw2Gltf.hpp
        src/gltf/GltfModel.cpp
        src/gltf/GltfModel.hpp
        src/gltf/TextureBuilder.cpp
        src/gltf/TextureBuilder.hpp
        src/gltf/properties/AccessorData.cpp
        src/gltf/properties/AccessorData.hpp
        src/gltf/properties/AnimationData.cpp
        src/gltf/properties/AnimationData.hpp
        src/gltf/properties/BufferData.cpp
        src/gltf/properties/BufferData.hpp
        src/gltf/properties/BufferViewData.cpp
        src/gltf/properties/BufferViewData.hpp
        src/gltf/properties/CameraData.cpp
        src/gltf/properties/CameraData.hpp
        src/gltf/properties/ImageData.cpp
        src/gltf/properties/ImageData.hpp
        src/gltf/properties/LightData.cpp
        src/gltf/properties/LightData.hpp
        src/gltf/properties/MaterialData.cpp
        src/gltf/properties/MaterialData.hpp
        src/gltf/properties/MeshData.cpp
        src/gltf/properties/MeshData.hpp
        src/gltf/properties/NodeData.cpp
        src/gltf/properties/NodeData.hpp
        src/gltf/properties/PrimitiveData.cpp
        src/gltf/properties/PrimitiveData.hpp
        src/gltf/properties/SamplerData.hpp
        src/gltf/properties/SceneData.cpp
        src/gltf/properties/SceneData.hpp
        src/gltf/properties/SkinData.cpp
        src/gltf/properties/SkinData.hpp
        src/gltf/properties/TextureData.cpp
        src/gltf/properties/TextureData.hpp
        src/mathfu.hpp
        src/raw/RawModel.cpp
        src/raw/RawModel.hpp
        src/utils/File_Utils.cpp
        src/utils/File_Utils.hpp
        src/utils/Image_Utils.cpp
        src/utils/Image_Utils.hpp
        src/utils/String_Utils.hpp
        third_party/CLI11/CLI11.hpp
)

add_library(libFBX2glTF STATIC ${LIB_SOURCE_FILES})
set_target_properties(libFBX2glTF PROPERTIES OUTPUT_NAME "FBX2glTF")
if(MSVC)
    set_target_properties(libFBX2glTF PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

add_executable(appFBX2glTF src/FBX2glTF.cpp)
set_target_properties(appFBX2glTF PROPERTIES OUTPUT_NAME "FBX2glTF")
if(MSVC)
    set_target_properties(appFBX2glTF PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

add_dependencies(libFBX2glTF
  Draco
  MathFu
  FiFoMap
  CPPCodec
)

if (NOT MSVC)
  # Disable annoying & spammy warning from FBX SDK header file
  target_compile_options(libFBX2glTF PRIVATE
    "-Wno-null-dereference"
    "-Wunused"
    )
  target_compile_options(appFBX2glTF PRIVATE
    "-Wno-null-dereference"
    "-Wunused"
    )
endif()

target_link_libraries(libFBX2glTF
  PRIVATE ${FRAMEWORKS}
  PRIVATE ${DRACO_LIB}
  PRIVATE ${CMAKE_DL_LIBS}
  PRIVATE ${CMAKE_THREAD_LIBS_INIT}
  PRIVATE ZLIB::ZLIB
  PRIVATE fmt::fmt
  PRIVATE fmt::fmt-header-only
  PRIVATE ${FBXSDK_LIBRARY}
)

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    # I don't know why on Ubuntu "PUBLIC" is needed, otherwise there're link errors.
    target_link_libraries(libFBX2glTF PUBLIC LibXml2::LibXml2)
else ()
    target_link_libraries(libFBX2glTF PRIVATE ${LIBXML2_LIBRARIES})
endif ()

target_include_directories(libFBX2glTF PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_include_directories(libFBX2glTF SYSTEM PUBLIC
  "third_party/stb"
  "third_party/json"
  ${FBXSDK_INCLUDE_DIR}
  ${DRACO_INCLUDE_DIR}
  ${MATHFU_INCLUDE_DIRS}
  ${FIFO_MAP_INCLUDE_DIR}
  ${CPPCODEC_INCLUDE_DIR}
  ${LIBXML2_INCLUDE_DIR}
)

target_include_directories(appFBX2glTF PUBLIC
  "third_party/CLI11"
)
target_link_libraries(appFBX2glTF PRIVATE libFBX2glTF fmt::fmt-header-only)

install (TARGETS libFBX2glTF DESTINATION "bin")
install (FILES $<TARGET_LINKER_FILE:libFBX2glTF> DESTINATION "lib" OPTIONAL)
if (CMAKE_BUILD_TYPE EQUAL "DEBUG")
    install (FILES $<TARGET_PDB_FILE:libFBX2glTF> DESTINATION "bin" OPTIONAL)
endif()

install (TARGETS appFBX2glTF DESTINATION "bin")
