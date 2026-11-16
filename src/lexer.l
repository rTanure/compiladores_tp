%option yylineno noyywrap nounput noinput

%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "parser.tab.h"

#define YY_USER_ACTION yylloc.first_line = yylineno;

int erros_lexicos = 0;

static void erro_lexico(const char *descricao, const char *dica)
{
    fprintf(stderr, "Erro léxico na linha %d: %s '%s'\n      Dica: %s\n",
            yylineno, descricao, yytext, dica);
    erros_lexicos++;
}

static const char *dica_id(const char *s)
{
    int minuscula = 0, maiuscula = 0, sublinhado = 0;
    for (; *s; s++) {
        if (islower((unsigned char)*s))      minuscula = 1;
        else if (isupper((unsigned char)*s)) maiuscula = 1;
        else if (*s == '_')                  sublinhado = 1;
    }
    if (yytext[0] == '_')
        return "identificadores não podem começar com '_'";
    if (isupper((unsigned char)yytext[0]) && minuscula)
        return "globais usam só MAIÚSCULAS (MAX_SIZE); funções começam com minúscula (calcularSoma)";
    if (islower((unsigned char)yytext[0]) && maiuscula && sublinhado)
        return "funções usam camelCase sem '_' (calcularSoma); locais usam só minúsculas (total_geral)";
    return "use MAIÚSCULAS (global), snake_case (local) ou camelCase (função)";
}

static const char *dica_char(char c)
{
    switch (c) {
        case '&': return "o E lógico é '&&'";
        case '|': return "o OU lógico é '||'";
        case '.': return "o ponto só é válido dentro de um float (ex.: 3.14)";
        default:  return "caractere não pertence à linguagem";
    }
}

/* Palpite do token que o programador pretendia escrever num identificador inválido. */
static int token_id_invalido(void)
{
    if (isupper((unsigned char)yytext[0]))
        return TK_ID_GLOBAL;
    for (const char *p = yytext; *p; p++)
        if (isupper((unsigned char)*p))
            return TK_ID_FUNC;
    return TK_ID_LOCAL;
}

static int token_texto(int token)
{
    yylval.sval = strdup(yytext);
    return token;
}
%}

ID_GERAL        [A-Za-z_][A-Za-z0-9_]*
GLOBAL          [A-Z][A-Z0-9_]*
LOCAL           [a-z][a-z0-9_]*
FUNCAO          [a-z]+[A-Z][a-zA-Z0-9]*

INT             [0-9]+
FLOAT           [0-9]+\.[0-9]+

%%

"int"           { return TK_TYPE_INT; }
"float"         { return TK_TYPE_FLOAT; }
"void"          { return TK_TYPE_VOID; }
"if"            { return TK_IF; }
"else"          { return TK_ELSE; }
"while"         { return TK_WHILE; }
"return"        { return TK_RETURN; }
"principal"     { return TK_PRINCIPAL; }

{INT}           { return token_texto(TK_INT); }
{FLOAT}         { return token_texto(TK_FLOAT); }

    /* Números malformados são devolvidos como literais para o parser não se perder. */
{INT}{ID_GERAL}         { erro_lexico("inteiro malformado", "números não podem conter letras; separe do identificador com espaço ou operador"); return token_texto(TK_INT); }
{FLOAT}{ID_GERAL}       { erro_lexico("float malformado", "números não podem conter letras; separe do identificador com espaço ou operador"); return token_texto(TK_FLOAT); }
{INT}(\.{INT}){2,}      { erro_lexico("float malformado", "um único ponto decimal é permitido (ex.: 3.14)"); return token_texto(TK_FLOAT); }
{INT}\.                 { erro_lexico("float malformado", "faltam dígitos depois do ponto (ex.: 5.0)"); return token_texto(TK_FLOAT); }
\.{INT}                 { erro_lexico("float malformado", "faltam dígitos antes do ponto (ex.: 0.5)"); return token_texto(TK_FLOAT); }

{GLOBAL}        { return token_texto(TK_ID_GLOBAL); }
{LOCAL}         { return token_texto(TK_ID_LOCAL); }
{FUNCAO}        { return token_texto(TK_ID_FUNC); }
{ID_GERAL}      { erro_lexico("identificador inválido", dica_id(yytext)); return token_texto(token_id_invalido()); }

">="            { return TK_OP_GEQ; }
"<="            { return TK_OP_LEQ; }
"=="            { return TK_OP_EQ; }
"!="            { return TK_OP_NEQ; }
"&&"            { return TK_OP_AND; }
"||"            { return TK_OP_OR; }
"<"             { return TK_OP_LT; }
">"             { return TK_OP_GT; }
"!"             { return TK_OP_NOT; }
"+"             { return TK_OP_ADD; }
"-"             { return TK_OP_SUB; }
"*"             { return TK_OP_MUL; }
"/"             { return TK_OP_DIV; }
"%"             { return TK_OP_MOD; }
"="             { return TK_ASSIGN; }

"("             { return TK_LPAREN; }
")"             { return TK_RPAREN; }
"{"             { return TK_LBRACE; }
"}"             { return TK_RBRACE; }
","             { return TK_COMMA; }
";"             { return TK_SEMICOLON; }

[ \t\r\n]+      { }

.               { erro_lexico("caractere inválido", dica_char(yytext[0])); }
