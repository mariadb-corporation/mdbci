cmake_minimum_required(VERSION 3.5)

project(AppRun)

add_executable(AppRun AppRun.c)

target_compile_definitions(AppRun
    PRIVATE -D_FILE_OFFSET_BITS=64
    PRIVATE -DENABLE_BINRELOC
)
