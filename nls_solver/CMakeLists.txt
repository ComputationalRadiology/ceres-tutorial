cmake_minimum_required(VERSION 3.28)
project(nls_solver VERSION 0.9)

# Ceres Solver 2.2.0 requires C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-O3 -pthread)

#find_package(glog 0.7.0 REQUIRED)
#find_package(glog 0.4.0 REQUIRED)

find_package(Ceres REQUIRED)

add_library(nls_solver SHARED nls_solver.cxx nls_solver.h)
target_link_libraries(nls_solver Ceres::ceres glog::glog gflags)

