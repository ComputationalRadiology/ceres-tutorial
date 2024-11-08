cmake_minimum_required(VERSION 3.28)

project(intensityScaling VERSION 1.0)

# Ceres Solver 2.2.0 requires C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-O3 -pthread)

find_package(Ceres REQUIRED)

find_package(quill REQUIRED)


find_package(ITK REQUIRED)
INCLUDE(${ITK_USE_FILE})

# We use the eigen package which can be included with ITK or external to ITK
set(ITK_EIGEN_LIBRARIES "") # No extra libraries are required if ITK is using system Eigen3

if(DEFINED ITKInternalEigen3_DIR) # Equivalent to if(NOT ITK_USE_SYSTEM_EIGEN)
   set(Eigen3_DIR ${ITKInternalEigen3_DIR})
   find_package(Eigen3 REQUIRED CONFIG)
endif()


add_library(intensityScaling SHARED intensityScaling.cxx intensityScaling.h)

target_link_libraries(intensityScaling Ceres::ceres glog::glog gflags)
target_link_libraries(intensityScaling ${ITK_LIBRARIES})
target_link_libraries(intensityScaling Eigen3::Eigen)

target_include_directories( intensityScaling PRIVATE ${ITK_INCLUDE_DIRS} )

# Linking against quill
#target_link_libraries(intensityScaling PRIVATE quill::quill)
target_link_libraries(intensityScaling quill::quill)

