cmake_minimum_required(VERSION 3.10)
project(lexer C)

find_package(FLEX REQUIRED)

FLEX_TARGET(
    scanner 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lexer.l 
    ${CMAKE_CURRENT_BINARY_DIR}/lex.yy.c
)

add_executable(lexer ${FLEX_scanner_OUTPUTS})