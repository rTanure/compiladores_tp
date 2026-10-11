cmake_minimum_required(VERSION 3.10)
project(lexer C)

option(LEXER_STANDALONE "Compila o lexer isolado (sem Bison)" ON)

find_package(FLEX REQUIRED)

FLEX_TARGET(
    scanner
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lexer.l
    ${CMAKE_CURRENT_BINARY_DIR}/lex.yy.c
)

add_executable(lexer ${FLEX_scanner_OUTPUTS})

target_include_directories(lexer PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_BINARY_DIR}
)

if(LEXER_STANDALONE)
    target_compile_definitions(lexer PRIVATE LEXER_STANDALONE)
endif()