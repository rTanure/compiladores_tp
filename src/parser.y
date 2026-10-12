%{
#include <stdio.h>
#include <stdlib.h>

extern int yylineno;
extern int erros_lexicos;

int yylex(void);
void yyerror(const char *s);
%}

%define parse.error detailed

/* identificadores */
%token TK_ID_GLOBAL TK_ID_LOCAL TK_ID_FUNC

/* tipos */
%token TK_TYPE_INT TK_TYPE_FLOAT TK_TYPE_STRING TK_TYPE_VOID TK_TYPE_CHAR

/* literais */
%token TK_INT TK_FLOAT TK_STRING TK_NULL TK_CHAR

/* operadores logicos */
%token TK_OP_EQ TK_OP_NEQ TK_OP_LT TK_OP_GT TK_OP_GEQ TK_OP_LEQ TK_OP_AND TK_OP_OR TK_OP_NOT

/* operadores aritmeticos */
%token TK_OP_ADD TK_OP_SUB TK_OP_MUL TK_OP_DIV TK_OP_MOD
%token TK_ASSIGN

/* delimitadores */
%token TK_LPAREN TK_RPAREN
%token TK_LBRACKET TK_RBRACKET
%token TK_LBRACE TK_RBRACE
%token TK_COMMA TK_SEMICOLON

/* palavras reservadas */
%token TK_IF TK_ELSE
%token TK_WHILE
%token TK_RETURN
%token TK_PRINCIPAL

%nonassoc IF_SEM_ELSE
%nonassoc TK_ELSE

%left TK_OP_OR
%left TK_OP_AND
%left TK_OP_EQ TK_OP_NEQ
%left TK_OP_LT TK_OP_GT TK_OP_LEQ TK_OP_GEQ
%left TK_OP_ADD TK_OP_SUB
%left TK_OP_MUL TK_OP_DIV TK_OP_MOD

%right TK_OP_NOT UMINUS

%define parse.trace

%%

/* programa principal */

programa:
    /* vazio */
    | programa elemento
    ;

elemento:
      declaracao_global
    | declaracao_funcao
    | funcao_principal
    ;

/* declarações */

tipo:
      TK_TYPE_INT
    | TK_TYPE_FLOAT
    | TK_TYPE_CHAR
    | TK_TYPE_STRING
    ;

tipo_retorno:
      tipo
    | TK_TYPE_VOID
    ;

identificador_global:
    TK_ID_GLOBAL
    ;

identificador_local:
    TK_ID_LOCAL
    ;

variavel:
    identificador_global
    | identificador_local
    ;

declaracao_global:
    tipo identificador_global dimensao_array TK_SEMICOLON
    ;

dimensao_array:
    %empty
  | TK_LBRACKET TK_INT TK_RBRACKET
;

/* funções */

declaracao_funcao:
    tipo_retorno TK_ID_FUNC TK_LPAREN parametros_opt TK_RPAREN bloco
    ;

parametros_opt:
    /* vazio */
    | lista_parametros
    ;

lista_parametros:
    parametro
    | lista_parametros TK_COMMA parametro

parametro:
    tipo identificador_local dimensao_array
    ;

/* função principal */

funcao_principal:
    tipo_retorno TK_PRINCIPAL TK_LPAREN TK_RPAREN bloco
    ;

/* bloco */

bloco:
    TK_LBRACE comandos TK_RBRACE

comandos:
    /* vazio */
    | comandos comando
    ;

comando:
      declaracao_local
    | atribuicao TK_SEMICOLON
    | chamada_funcao TK_SEMICOLON
    | comando_if
    | comando_while
    | comando_return
    | bloco
    | TK_SEMICOLON
    ;

declaracao_local:
    tipo identificador_local dimensao_array TK_SEMICOLON
    ;

atribuicao:
    alvo TK_ASSIGN expressao
    ;

alvo:
    variavel
    | variavel TK_LBRACKET expressao TK_RBRACKET
    ;

/* controle de fluxo */

comando_if:
    TK_IF TK_LPAREN expressao TK_RPAREN comando
    %prec IF_SEM_ELSE
    | TK_IF TK_LPAREN expressao TK_RPAREN comando TK_ELSE comando
    ;

comando_while:
    TK_WHILE TK_LPAREN expressao TK_RPAREN comando
    ;

comando_return:
    TK_RETURN TK_SEMICOLON;
    | TK_RETURN expressao TK_SEMICOLON
    ;

/* chamadas de funções */

chamada_funcao:
    TK_ID_FUNC TK_LPAREN argumentos_opt TK_RPAREN
    ;

argumentos_opt:
    /* vazio */
    | lista_argumentos
    ;

lista_argumentos:
    expressao
    | lista_argumentos TK_COMMA expressao
    ;

/* expressões */

expressao:
      TK_INT
    | TK_FLOAT
    | TK_STRING
    | TK_NULL
    | variavel
    | variavel TK_LBRACKET expressao TK_RBRACKET
    | chamada_funcao
    | TK_LPAREN expressao TK_RPAREN

    | expressao TK_OP_ADD expressao
    | expressao TK_OP_SUB expressao
    | expressao TK_OP_MUL expressao
    | expressao TK_OP_DIV expressao
    | expressao TK_OP_MOD expressao

    | expressao TK_OP_EQ expressao
    | expressao TK_OP_NEQ expressao
    | expressao TK_OP_LT expressao
    | expressao TK_OP_GT expressao
    | expressao TK_OP_LEQ expressao
    | expressao TK_OP_GEQ expressao

    | expressao TK_OP_AND expressao
    | expressao TK_OP_OR expressao

    | TK_OP_NOT expressao
    | TK_OP_SUB expressao %prec UMINUS

%%

void yyerror(const char *s)
{
    fprintf(stderr,
            "Erro sintatico na linha %d: %s\n",
            yylineno, s);
}

extern int yydebug;

int main(void)
{
    yydebug = 1;
    int resultado = yyparse();

    if (resultado == 0 && erros_lexicos == 0) {
        printf("Analise concluida: programa sintaticamente valido.\n");
        return 0;
    }

    if (erros_lexicos > 0) {
        fprintf(stderr, "Foram encontrados %d erro(s) lexico(s).\n", erros_lexicos);
    }

    return 1;
}

