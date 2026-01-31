cmake_minimum_required(VERSION 3.13)

PROJECT(ucode-mod-yaml C)

ADD_DEFINITIONS(-Os -Wall -Werror --std=gnu99 -ffunction-sections -fdata-sections -fPIC)

IF(NOT APPLE)
  SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-Wl,--gc-sections")
ENDIF()

FIND_PATH(ucode_include_dir ucode/module.h)
FIND_LIBRARY(ucode NAMES ucode)
FIND_LIBRARY(yaml NAMES yaml)

IF(ucode_include_dir AND ucode AND yaml)
  INCLUDE_DIRECTORIES(${ucode_include_dir})

  ADD_LIBRARY(yaml_lib MODULE yaml.c)
  SET_TARGET_PROPERTIES(yaml_lib PROPERTIES OUTPUT_NAME yaml PREFIX "")
  TARGET_LINK_LIBRARIES(yaml_lib ${yaml} ${ucode})

  INSTALL(TARGETS yaml_lib LIBRARY DESTINATION lib/ucode)
ELSE()
  MESSAGE(FATAL_ERROR "Could not find required dependencies (ucode headers, libucode, libyaml)")
ENDIF()
