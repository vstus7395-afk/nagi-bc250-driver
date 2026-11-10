cmake_minimum_required(VERSION 3.20)
project(L2AgpWarningSuppressor LANGUAGES CXX)
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
  message(FATAL_ERROR "Build this proxy as Win32/x86 for the 32-bit Lineage II client.")
endif()
include(FetchContent)
FetchContent_Declare(minhook
  GIT_REPOSITORY https://github.com/TsudaKageyu/minhook.git
  GIT_TAG v1.3.3
)
FetchContent_MakeAvailable(minhook)
add_library(dinput8 SHARED src/dllmain.cpp src/proxy.cpp src/agp_warning_hook.cpp src/agp_warning_hook.h)
target_compile_features(dinput8 PRIVATE cxx_std_17)
target_compile_definitions(dinput8 PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(dinput8 PRIVATE minhook)
target_include_directories(dinput8 PRIVATE ${minhook_SOURCE_DIR}/include)
target_link_options(dinput8 PRIVATE "/DEF:${CMAKE_CURRENT_SOURCE_DIR}/src/exports.def")
set_target_properties(dinput8 PROPERTIES OUTPUT_NAME "dinput8" PREFIX ""
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out")
