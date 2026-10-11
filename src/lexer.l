%option yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>


#ifdef LEXER_STANDALONE
    #include "tokens.h"
    #define TOK(t) (t)
    #define CHAR_TOK() (printf("%-20s -> CHAR '%c'\n", yytext, yytext[0]), yytext[0])

#else
    #include "parser.tab.h"
    #define TOK(t) (t)
    #define CHAR_TOK() (yytext[0])
#endif

int erros_lexicos = 0;

static void lex_error(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "%2d. Erro lexico: ", erros_lexicos + 1);
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    erros_lexicos++;
}
%}

ERR_GENERAL_ID              [A-Za-z_][A-Za-z0-9_]* 
REG_GLOBAL                  [A-Z][A-Z0-9_]*
REG_LOCAL                   [a-z][a-z0-9_]*
REG_FUNC                    [a-z]+[A-Z][a-zA-Z0-9]*

REG_INT                     [0-9]+
REG_FLOAT                   [0-9]+\.[0-9]+

ERR_MALFORMED_INT           {REG_INT}{ERR_GENERAL_ID}
ERR_MALFORMED_FLOAT         {REG_FLOAT}{ERR_GENERAL_ID}

REG_STRING                  \"([^"\\\n]|\\.)*\"
ERR_UNTERMINATED_STRING     \"([^"\\\n]|\\.)*

%%

"int"                   {return TOK(TK_TYPE_INT);}
"float"                 {return TOK(TK_TYPE_FLOAT);}
"string"                {return TOK(TK_TYPE_STRING);}
"void"                  {return TOK(TK_TYPE_VOID);}
"char"                  {return TOK(TK_TYPE_CHAR);}
"null"                  {return TOK(TK_NULL);}
"if"                    {return TOK(TK_IF);}
"else"                  {return TOK(TK_ELSE);}
"while"                 {return TOK(TK_WHILE);}
"return"                {return TOK(TK_RETURN);}
"principal"             {return TOK(TK_PRINCIPAL);}

{REG_STRING}                {return TOK(TK_STRING);}
{ERR_UNTERMINATED_STRING}   {lex_error("string '%s' não terminada na linha %d", yytext, yylineno);}

{REG_INT}                   {return TOK(TK_INT);}
{ERR_MALFORMED_INT}         {lex_error("inteiro malformado '%s' na linha %d.", yytext, yylineno);}

{REG_FLOAT}                 {return TOK(TK_FLOAT);}
{ERR_MALFORMED_FLOAT}       {lex_error("float malformado '%s' na linha %d.", yytext, yylineno);}



{REG_GLOBAL}            {return TOK(TK_ID_GLOBAL);}
{REG_LOCAL}             {return TOK(TK_ID_LOCAL);}
{REG_FUNC}              {return TOK(TK_ID_FUNC);}
{ERR_GENERAL_ID}        {lex_error("identificador inválido '%s' na linha %d.", yytext, yylineno);}

">="                    {return TOK(TK_OP_GEQ);}
"<="                    {return TOK(TK_OP_LEQ);}                   
"=="                    {return TOK(TK_OP_EQ);}
"!="                    {return TOK(TK_OP_NEQ);}
"||"                    {return TOK(TK_OP_OR);}
"&&"                    {return TOK(TK_OP_AND);}
"<"                     {return TOK(TK_OP_LT);}
">"                     {return TOK(TK_OP_GT);}
"!"                     {return TOK(TK_OP_NOT);}

"("                     {return TOK(TK_LPAREN);}
")"                     {return TOK(TK_RPAREN);}
"["                     {return TOK(TK_LBRACKET);}
"]"                     {return TOK(TK_RBRACKET);}
"{"                     {return TOK(TK_LBRACE);}
"}"                     {return TOK(TK_RBRACE);}

"+"                     {return TOK(TK_OP_ADD);}
"-"                     {return TOK(TK_OP_SUB);}
"*"                     {return TOK(TK_OP_MUL);}
"/"                     {return TOK(TK_OP_DIV);}
"%"                     {return TOK(TK_OP_MOD);}

"="                     {return TOK(TK_ASSIGN);}

","                     {return TOK(TK_COMMA);}
";"                     {return TOK(TK_SEMICOLON);}
[ \t\r\n]+              { }

.                       { fprintf(stderr, "Erro lexico (linha %d): caractere invalido '%s'\n", yylineno, yytext); }

%%

int yywrap(void)
{
    return 1;
}


#ifdef LEXER_STANDALONE
int main(void)
{
    printf("\n");
    while (yylex() != 0);

    if (erros_lexicos == 0)
        printf("\nAnalise lexica concluida. Nenhum erro encontrado.\n");
    else
        printf("\nAnalise lexica concluida com %d erro(s) lexico(s).\n", erros_lexicos);

    return 0;
}
#endif