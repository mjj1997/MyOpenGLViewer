include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(MyOpenGLViewer_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(MyOpenGLViewer_setup_options)
  option(MyOpenGLViewer_ENABLE_HARDENING "Enable hardening" ON)
  option(MyOpenGLViewer_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    MyOpenGLViewer_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    MyOpenGLViewer_ENABLE_HARDENING
    OFF)

  MyOpenGLViewer_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR MyOpenGLViewer_PACKAGING_MAINTAINER_MODE)
    option(MyOpenGLViewer_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(MyOpenGLViewer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(MyOpenGLViewer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(MyOpenGLViewer_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(MyOpenGLViewer_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(MyOpenGLViewer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(MyOpenGLViewer_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(MyOpenGLViewer_ENABLE_IPO "Enable IPO/LTO" ON)
    option(MyOpenGLViewer_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(MyOpenGLViewer_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(MyOpenGLViewer_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(MyOpenGLViewer_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(MyOpenGLViewer_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(MyOpenGLViewer_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(MyOpenGLViewer_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(MyOpenGLViewer_ENABLE_PCH "Enable precompiled headers" OFF)
    option(MyOpenGLViewer_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      MyOpenGLViewer_ENABLE_IPO
      MyOpenGLViewer_WARNINGS_AS_ERRORS
      MyOpenGLViewer_ENABLE_USER_LINKER
      MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS
      MyOpenGLViewer_ENABLE_SANITIZER_LEAK
      MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED
      MyOpenGLViewer_ENABLE_SANITIZER_THREAD
      MyOpenGLViewer_ENABLE_SANITIZER_MEMORY
      MyOpenGLViewer_ENABLE_UNITY_BUILD
      MyOpenGLViewer_ENABLE_CLANG_TIDY
      MyOpenGLViewer_ENABLE_CPPCHECK
      MyOpenGLViewer_ENABLE_COVERAGE
      MyOpenGLViewer_ENABLE_PCH
      MyOpenGLViewer_ENABLE_CACHE)
  endif()

  MyOpenGLViewer_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS OR MyOpenGLViewer_ENABLE_SANITIZER_THREAD OR MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(MyOpenGLViewer_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(MyOpenGLViewer_global_options)
  if(MyOpenGLViewer_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    MyOpenGLViewer_enable_ipo()
  endif()

  MyOpenGLViewer_supports_sanitizers()

  if(MyOpenGLViewer_ENABLE_HARDENING AND MyOpenGLViewer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED
       OR MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS
       OR MyOpenGLViewer_ENABLE_SANITIZER_THREAD
       OR MyOpenGLViewer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${MyOpenGLViewer_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED}")
    MyOpenGLViewer_enable_hardening(MyOpenGLViewer_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(MyOpenGLViewer_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(MyOpenGLViewer_warnings INTERFACE)
  add_library(MyOpenGLViewer_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  MyOpenGLViewer_set_project_warnings(
    MyOpenGLViewer_warnings
    ${MyOpenGLViewer_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(MyOpenGLViewer_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    MyOpenGLViewer_configure_linker(MyOpenGLViewer_options)
  endif()

  include(cmake/Sanitizers.cmake)
  MyOpenGLViewer_enable_sanitizers(
    MyOpenGLViewer_options
    ${MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS}
    ${MyOpenGLViewer_ENABLE_SANITIZER_LEAK}
    ${MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED}
    ${MyOpenGLViewer_ENABLE_SANITIZER_THREAD}
    ${MyOpenGLViewer_ENABLE_SANITIZER_MEMORY})

  set_target_properties(MyOpenGLViewer_options PROPERTIES UNITY_BUILD ${MyOpenGLViewer_ENABLE_UNITY_BUILD})

  if(MyOpenGLViewer_ENABLE_PCH)
    target_precompile_headers(
      MyOpenGLViewer_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(MyOpenGLViewer_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    MyOpenGLViewer_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(MyOpenGLViewer_ENABLE_CLANG_TIDY)
    MyOpenGLViewer_enable_clang_tidy(MyOpenGLViewer_options ${MyOpenGLViewer_WARNINGS_AS_ERRORS})
  endif()

  if(MyOpenGLViewer_ENABLE_CPPCHECK)
    MyOpenGLViewer_enable_cppcheck(${MyOpenGLViewer_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(MyOpenGLViewer_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    MyOpenGLViewer_enable_coverage(MyOpenGLViewer_options)
  endif()

  if(MyOpenGLViewer_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(MyOpenGLViewer_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(MyOpenGLViewer_ENABLE_HARDENING AND NOT MyOpenGLViewer_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR MyOpenGLViewer_ENABLE_SANITIZER_UNDEFINED
       OR MyOpenGLViewer_ENABLE_SANITIZER_ADDRESS
       OR MyOpenGLViewer_ENABLE_SANITIZER_THREAD
       OR MyOpenGLViewer_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    MyOpenGLViewer_enable_hardening(MyOpenGLViewer_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
