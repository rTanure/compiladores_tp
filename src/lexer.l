%option yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>



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

static const char *dica_id(const char *s) {
    int up = 0, low = 0, us = 0;
    for (const char *p = s; *p; p++) {
        if (isupper((unsigned char)*p)) up = 1;
        else if (islower((unsigned char)*p)) low = 1;
        else if (*p == '_') us = 1;
    }
    if (s[0] == '_')
        return "identificadores nao podem comecar com '_'\n";
    if (isupper((unsigned char)s[0]) && low)
        return "globais usam so MAIUSCULAS (MAX_SIZE); funcoes comecam com minuscula (calcularSoma)\n";
    if (islower((unsigned char)s[0]) && up && us)
        return "funcoes usam camelCase sem '_' (calcularSoma); locais usam so minusculas (total_geral)\n";
    return "use MAIUSCULAS (global), snake_case (local) ou camelCase (funcao)\n";
}

static const char *dica_num(const char *s) {
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
        return "hexadecimal nao suportado; use apenas digitos decimais\n";
    if (strchr(s, '_'))
        return "separador '_' nao suportado em numeros\n";
    const char *p = s;
    while (isdigit((unsigned char)*p) || *p == '.') p++;
    if ((*p == 'e' || *p == 'E') && isdigit((unsigned char)p[1]))
        return "notacao cientifica nao suportada\n";
    return "numeros nao podem conter letras; separe do identificador com espaco ou operador\n";
}

static const char *dica_char(char c) {
    switch (c) {
        case '&':  return "o E logico e '&&'\n";
        case '|':  return "o OU logico e '||'\n";
        case '\'': return "nao ha literal de caractere; use aspas duplas \"...\"\n";
        case '.':  return "o ponto so e valido dentro de um float (ex.: 3.14)\n";
        default:   return "caractere nao pertence a linguagem\n";
    }
}

static const char *dica_string(const char *s) {
    if (strstr(s, "\\\""))
        return "falta a aspa de fechamento (uma \\\" no meio foi lida como escape)\n";
    return "falta a aspa de fechamento; strings nao podem passar de uma linha\n";
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
ERR_FLOAT_MULTI_DOT         {REG_INT}(\.{REG_INT}){2,}
ERR_FLOAT_TRAILING          {REG_INT}\.
ERR_FLOAT_LEADING           \.{REG_INT}

REG_STRING                  \"([^"\\\n]|\\.)*\"
ERR_UNTERMINATED_STRING     \"([^"\\\n]|\\.)*

%%

"int"                       {return TOK(TK_TYPE_INT);}
"float"                     {return TOK(TK_TYPE_FLOAT);}
"string"                    {return TOK(TK_TYPE_STRING);}
"void"                      {return TOK(TK_TYPE_VOID);}
"char"                      {return TOK(TK_TYPE_CHAR);}
"null"                      {return TOK(TK_NULL);}
"if"                        {return TOK(TK_IF);}
"else"                      {return TOK(TK_ELSE);}
"while"                     {return TOK(TK_WHILE);}
"return"                    {return TOK(TK_RETURN);}
"principal"                 {return TOK(TK_PRINCIPAL);}

{REG_STRING}                {return TOK(TK_STRING);}
{ERR_UNTERMINATED_STRING}   {lex_error("string nao terminada '%s' na linha %d.\n      Dica: %s", yytext, yylineno, dica_string(yytext));}


{REG_INT}                   {return TOK(TK_INT);}
{ERR_MALFORMED_INT}         {lex_error("inteiro malformado '%s' na linha %d.\n      Dica: %s", yytext, yylineno, dica_num(yytext));}

{REG_FLOAT}                 {return TOK(TK_FLOAT);}
{ERR_MALFORMED_FLOAT}       {lex_error("float malformado '%s' na linha %d.\n      Dica: %s", yytext, yylineno, dica_num(yytext));}
{ERR_FLOAT_MULTI_DOT}       {lex_error("float malformado '%s' na linha %d.\n      Dica: um float tem um unico ponto decimal (ex.: 3.14)\n", yytext, yylineno);}
{ERR_FLOAT_TRAILING}        {lex_error("float malformado '%s' na linha %d.\n      Dica: faltam digitos depois do ponto (ex.: 5.0)\n", yytext, yylineno);}
{ERR_FLOAT_LEADING}         {lex_error("float malformado '%s' na linha %d.\n      Dica: faltam digitos antes do ponto (ex.: 0.5)\n", yytext, yylineno);}



{REG_GLOBAL}                {return TOK(TK_ID_GLOBAL);}
{REG_LOCAL}                 {return TOK(TK_ID_LOCAL);}
{REG_FUNC}                  {return TOK(TK_ID_FUNC);}
{ERR_GENERAL_ID}            {lex_error("identificador invalido '%s' na linha %d.\n      Dica: %s", yytext, yylineno, dica_id(yytext));}

">="                        {return TOK(TK_OP_GEQ);}
"<="                        {return TOK(TK_OP_LEQ);}                   
"=="                        {return TOK(TK_OP_EQ);}
"!="                        {return TOK(TK_OP_NEQ);}
"||"                        {return TOK(TK_OP_OR);}
"&&"                        {return TOK(TK_OP_AND);}
"<"                         {return TOK(TK_OP_LT);}
">"                         {return TOK(TK_OP_GT);}
"!"                         {return TOK(TK_OP_NOT);}

"("                         {return TOK(TK_LPAREN);}
")"                         {return TOK(TK_RPAREN);}
"["                         {return TOK(TK_LBRACKET);}
"]"                         {return TOK(TK_RBRACKET);}
"{"                         {return TOK(TK_LBRACE);}
"}"                         {return TOK(TK_RBRACE);}

"+"                         {return TOK(TK_OP_ADD);}
"-"                         {return TOK(TK_OP_SUB);}
"*"                         {return TOK(TK_OP_MUL);}
"/"                         {return TOK(TK_OP_DIV);}
"%"                         {return TOK(TK_OP_MOD);}

"="                         {return TOK(TK_ASSIGN);}

","                         {return TOK(TK_COMMA);}
";"                         {return TOK(TK_SEMICOLON);}
[ \t\r\n]+                  { }

.                           {lex_error("caractere invalido '%s' na linha %d.\n      Dica: %s", yytext, yylineno, dica_char(yytext[0]));}
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

    return erros_lexicos == 0 ? 0 : 1;
}
#endif