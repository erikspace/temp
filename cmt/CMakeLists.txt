cmake_minimum_required(VERSION "3.16")

project("cmt")

add_executable("${PROJECT_NAME}" main.cpp)

install(TARGETS "${PROJECT_NAME}" DESTINATION bin)
install(FILES "main.cpp" DESTINATION src)



option(ADD_VELOX "add velox to product" OFF)
if(ADD_VELOX)
set(CMAKE_CXX_FLAGS "-DFOO=1")
else()
set(CMAKE_CXX_FLAGS "-DFOO=99")
endif(ADD_VELOX)
unset(ADD_VELOX CACHE)
