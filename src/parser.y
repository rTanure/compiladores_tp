%code requires {
#include "tabela.h"

/* Atributo sintetizado de uma expressão: onde o valor está (variável,
 * constante ou temporária) e qual o seu tipo. */
typedef struct {
    char *place;
    Tipo  tipo;
} Expr;

/* Argumentos de uma chamada, já avaliados. */
typedef struct {
    char *place[MAX_PARAMS];
    Tipo  tipo[MAX_PARAMS];
    int   n;
} Args;
}

%code {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "quad.h"

int yylex(void);
void yyerror(const char *s);

extern int erros_lexicos;
static int erros_sintaticos = 0;
static int erros_semanticos = 0;

/* Função em análise (para checar o return) e parâmetros do cabeçalho em leitura. */
static Tipo ret_atual;
static Tipo params_tipo[MAX_PARAMS];
static char *params_nome[MAX_PARAMS];
static int  n_params;

typedef enum { ARITMETICA, RESTO, RELACIONAL, LOGICA } Categoria;

static void erro_semantico(int linha, const char *fmt, ...)
{
    /* Com erros léxicos ou sintáticos a árvore é incompleta: erros semânticos seriam ruído. */
    if (erros_lexicos > 0 || erros_sintaticos > 0)
        return;

    va_list ap;
    va_start(ap, fmt);
    if (linha > 0)
        fprintf(stderr, "Erro semântico na linha %d: ", linha);
    else
        fprintf(stderr, "Erro semântico: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    erros_semanticos++;
}

static Expr expr_nova(char *place, Tipo tipo)
{
    Expr e = { place, tipo };
    return e;
}

static Expr expr_erro(void)
{
    return expr_nova("?", T_ERRO);
}

/* Promove um int para float quando o contexto exige. */
static Expr converte(Expr e, Tipo alvo)
{
    if (e.tipo != T_INT || alvo != T_FLOAT)
        return e;
    char *t = quad_temp();
    quad_emit("inttofloat", e.place, NULL, t);
    return expr_nova(t, T_FLOAT);
}

static Expr usa_variavel(const char *nome, int linha)
{
    const Simbolo *s = simbolo_busca(nome);
    if (!s) {
        erro_semantico(linha, "variável '%s' usada sem declaração", nome);
        return expr_erro();
    }
    return expr_nova(strdup(nome), s->tipo);
}

static Expr binaria(const char *op, Categoria cat, Expr a, Expr b, int linha)
{
    if (a.tipo == T_ERRO || b.tipo == T_ERRO)
        return expr_erro();

    if ((cat == LOGICA || cat == RESTO) && (a.tipo != T_INT || b.tipo != T_INT)) {
        erro_semantico(linha, "operador '%s' exige operandos int, mas recebeu %s e %s",
                       op, tipo_nome(a.tipo), tipo_nome(b.tipo));
        return expr_erro();
    }

    Tipo alvo = (a.tipo == T_FLOAT || b.tipo == T_FLOAT) ? T_FLOAT : T_INT;
    a = converte(a, alvo);
    b = converte(b, alvo);

    char *t = quad_temp();
    quad_emit(op, a.place, b.place, t);
    return expr_nova(t, (cat == RELACIONAL || cat == LOGICA) ? T_INT : alvo);
}

static Expr unaria(const char *op, Expr e, int linha)
{
    if (e.tipo == T_ERRO)
        return e;
    if (op[0] == '!' && e.tipo != T_INT) {
        erro_semantico(linha, "operador '!' exige operando int, mas recebeu %s", tipo_nome(e.tipo));
        return expr_erro();
    }
    char *t = quad_temp();
    quad_emit(op, e.place, NULL, t);
    return expr_nova(t, e.tipo);
}

static void declara_variavel(const char *nome, Tipo tipo, int linha)
{
    if (!simbolo_declara(nome, tipo))
        erro_semantico(linha, "variável '%s' já declarada neste escopo", nome);
}

static void atribui(const char *nome, Expr e, int linha)
{
    const Simbolo *s = simbolo_busca(nome);
    if (!s) {
        erro_semantico(linha, "variável '%s' usada sem declaração", nome);
        return;
    }
    if (e.tipo == T_ERRO)
        return;
    if (!tipo_compativel(s->tipo, e.tipo)) {
        erro_semantico(linha, "não é possível atribuir %s à variável '%s' do tipo %s",
                       tipo_nome(e.tipo), nome, tipo_nome(s->tipo));
        return;
    }
    quad_emit("=", converte(e, s->tipo).place, NULL, nome);
}

static void retorna(int tem_valor, Expr e, int linha)
{
    if (ret_atual == T_VOID && tem_valor) {
        erro_semantico(linha, "função void não pode retornar valor");
    } else if (ret_atual != T_VOID && !tem_valor) {
        erro_semantico(linha, "função deve retornar um valor %s", tipo_nome(ret_atual));
    } else if (tem_valor && e.tipo != T_ERRO) {
        if (!tipo_compativel(ret_atual, e.tipo))
            erro_semantico(linha, "retorno do tipo %s em função que retorna %s",
                           tipo_nome(e.tipo), tipo_nome(ret_atual));
        else
            quad_emit("return", converte(e, ret_atual).place, NULL, NULL);
        return;
    }
    quad_emit("return", NULL, NULL, NULL);
}

static Args *args_novo(void)
{
    return calloc(1, sizeof(Args));
}

static Args *args_add(Args *a, Expr e)
{
    if (a->n < MAX_PARAMS) {
        a->place[a->n] = e.place;
        a->tipo[a->n] = e.tipo;
    }
    a->n++;
    return a;
}

static Expr chama(const char *nome, Args *a, int linha)
{
    const Funcao *f = funcao_busca(nome);
    int ok = 1;

    if (!f) {
        erro_semantico(linha, "função '%s' chamada sem declaração", nome);
        return expr_erro();
    }
    if (a->n != f->nparams) {
        erro_semantico(linha, "função '%s' espera %d argumento(s), mas recebeu %d",
                       nome, f->nparams, a->n);
        return expr_erro();
    }
    for (int i = 0; i < a->n; i++) {
        if (a->tipo[i] == T_ERRO) {
            ok = 0;
        } else if (!tipo_compativel(f->params[i], a->tipo[i])) {
            erro_semantico(linha, "argumento %d de '%s': esperado %s, mas recebeu %s",
                           i + 1, nome, tipo_nome(f->params[i]), tipo_nome(a->tipo[i]));
            ok = 0;
        }
    }
    if (!ok)
        return expr_erro();

    for (int i = 0; i < a->n; i++)
        a->place[i] = converte(expr_nova(a->place[i], a->tipo[i]), f->params[i]).place;
    for (int i = 0; i < a->n; i++)
        quad_emit("param", a->place[i], NULL, NULL);

    char contagem[16];
    snprintf(contagem, sizeof contagem, "%d", a->n);
    if (f->retorno == T_VOID) {
        quad_emit("call", nome, contagem, NULL);
        return expr_nova(NULL, T_VOID);
    }
    char *t = quad_temp();
    quad_emit("call", nome, contagem, t);
    return expr_nova(t, f->retorno);
}

static void adiciona_parametro(Tipo tipo, const char *nome, int linha)
{
    if (n_params == MAX_PARAMS) {
        erro_semantico(linha, "número máximo de parâmetros (%d) excedido", MAX_PARAMS);
        return;
    }
    params_tipo[n_params] = tipo;
    params_nome[n_params] = strdup(nome);
    n_params++;
}

/* Registra a função, abre o escopo dos parâmetros e emite o rótulo dela. */
static void inicia_funcao(const char *nome, Tipo retorno, int linha)
{
    if (!funcao_declara(nome, retorno, params_tipo, n_params))
        erro_semantico(linha, "função '%s' já declarada", nome);

    ret_atual = retorno;
    escopo_entra(nome);
    for (int i = 0; i < n_params; i++)
        if (!simbolo_declara(params_nome[i], params_tipo[i]))
            erro_semantico(linha, "parâmetro '%s' repetido", params_nome[i]);
    n_params = 0;

    quad_emit("label", NULL, NULL, nome);
}

static void finaliza_funcao(void)
{
    quad_emit("return", NULL, NULL, NULL);
    escopo_sai();
}
}

%locations
%define parse.error custom
%define parse.lac full

%union {
    char *sval;
    Tipo  tipo;
    Expr  expr;
    Args *args;
    int   rotulo;
}

%token <sval> TK_ID_GLOBAL "identificador global"
%token <sval> TK_ID_LOCAL  "identificador local"
%token <sval> TK_ID_FUNC   "nome de função"
%token <sval> TK_INT       "número inteiro"
%token <sval> TK_FLOAT     "número float"

%token TK_TYPE_INT   "int"
%token TK_TYPE_FLOAT "float"
%token TK_TYPE_VOID  "void"
%token TK_IF         "if"
%token TK_ELSE       "else"
%token TK_WHILE      "while"
%token TK_RETURN     "return"
%token TK_PRINCIPAL  "principal"

%token TK_OP_EQ  "=="
%token TK_OP_NEQ "!="
%token TK_OP_LT  "<"
%token TK_OP_GT  ">"
%token TK_OP_GEQ ">="
%token TK_OP_LEQ "<="
%token TK_OP_AND "&&"
%token TK_OP_OR  "||"
%token TK_OP_NOT "!"
%token TK_OP_ADD "+"
%token TK_OP_SUB "-"
%token TK_OP_MUL "*"
%token TK_OP_DIV "/"
%token TK_OP_MOD "%"
%token TK_ASSIGN "="

%token TK_LPAREN    "("
%token TK_RPAREN    ")"
%token TK_LBRACE    "{"
%token TK_RBRACE    "}"
%token TK_COMMA     ","
%token TK_SEMICOLON ";"

%nonassoc IF_SEM_ELSE
%nonassoc TK_ELSE

%left TK_OP_OR
%left TK_OP_AND
%left TK_OP_EQ TK_OP_NEQ
%left TK_OP_LT TK_OP_GT TK_OP_LEQ TK_OP_GEQ
%left TK_OP_ADD TK_OP_SUB
%left TK_OP_MUL TK_OP_DIV TK_OP_MOD
%right TK_OP_NOT UMINUS

%type <tipo>   tipo tipo_retorno
%type <sval>   variavel
%type <expr>   expressao chamada_funcao
%type <args>   argumentos_opt lista_argumentos
%type <rotulo> if_cabeca while_inicio

%%

programa:
      %empty
    | programa elemento
    ;

elemento:
      declaracao_global
    | declaracao_funcao
    | funcao_principal
    | error
    ;

/* ---------- declarações ---------- */

tipo:
      TK_TYPE_INT   { $$ = T_INT; }
    | TK_TYPE_FLOAT { $$ = T_FLOAT; }
    ;

tipo_retorno:
      tipo          { $$ = $1; }
    | TK_TYPE_VOID  { $$ = T_VOID; }
    ;

variavel:
      TK_ID_GLOBAL
    | TK_ID_LOCAL
    ;

declaracao_global:
    tipo TK_ID_GLOBAL TK_SEMICOLON { declara_variavel($2, $1, @2.first_line); }
    ;

declaracao_local:
    tipo TK_ID_LOCAL TK_SEMICOLON { declara_variavel($2, $1, @2.first_line); }
    ;

/* ---------- funções ---------- */

declaracao_funcao:
    cabecalho_funcao corpo_funcao
    ;

cabecalho_funcao:
    tipo_retorno TK_ID_FUNC TK_LPAREN parametros_opt TK_RPAREN
        { inicia_funcao($2, $1, @2.first_line); }
    ;

funcao_principal:
    cabecalho_principal corpo_funcao
    ;

cabecalho_principal:
    tipo_retorno TK_PRINCIPAL TK_LPAREN TK_RPAREN
        { inicia_funcao("principal", $1, @2.first_line); }
    ;

parametros_opt:
      %empty
    | lista_parametros
    ;

lista_parametros:
      parametro
    | lista_parametros TK_COMMA parametro
    ;

parametro:
    tipo TK_ID_LOCAL { adiciona_parametro($1, $2, @2.first_line); }
    ;

corpo_funcao:
    TK_LBRACE comandos TK_RBRACE { finaliza_funcao(); }
    ;

/* ---------- comandos ---------- */

bloco:
    TK_LBRACE { escopo_entra(NULL); } comandos TK_RBRACE { escopo_sai(); }
    ;

comandos:
      %empty
    | comandos comando
    ;

comando:
      declaracao_local
    | variavel TK_ASSIGN expressao TK_SEMICOLON { atribui($1, $3, @1.first_line); }
    | chamada_funcao TK_SEMICOLON
    | comando_if
    | comando_while
    | comando_return
    | bloco
    | error TK_SEMICOLON { yyerrok; }
    | error
    ;

if_cabeca:
    TK_IF TK_LPAREN expressao TK_RPAREN
        { $$ = quad_rotulo(); quad_emit_if_false($3.place, $$); }
    ;

comando_if:
      if_cabeca comando %prec IF_SEM_ELSE
        { quad_emit_label($1); }
    | if_cabeca comando TK_ELSE
        { $<rotulo>$ = quad_rotulo(); quad_emit_goto($<rotulo>$); quad_emit_label($1); }
      comando
        { quad_emit_label($<rotulo>4); }
    ;

while_inicio:
    TK_WHILE { $$ = quad_rotulo(); quad_emit_label($$); }
    ;

comando_while:
    while_inicio TK_LPAREN expressao TK_RPAREN
        { $<rotulo>$ = quad_rotulo(); quad_emit_if_false($3.place, $<rotulo>$); }
      comando
        { quad_emit_goto($1); quad_emit_label($<rotulo>5); }
    ;

comando_return:
      TK_RETURN TK_SEMICOLON          { retorna(0, expr_erro(), @1.first_line); }
    | TK_RETURN expressao TK_SEMICOLON { retorna(1, $2, @1.first_line); }
    ;

/* ---------- chamadas ---------- */

chamada_funcao:
    TK_ID_FUNC TK_LPAREN argumentos_opt TK_RPAREN { $$ = chama($1, $3, @1.first_line); }
    ;

argumentos_opt:
      %empty           { $$ = args_novo(); }
    | lista_argumentos
    ;

lista_argumentos:
      expressao                              { $$ = args_add(args_novo(), $1); }
    | lista_argumentos TK_COMMA expressao    { $$ = args_add($1, $3); }
    ;

/* ---------- expressões ---------- */

expressao:
      TK_INT   { $$ = expr_nova($1, T_INT); }
    | TK_FLOAT { $$ = expr_nova($1, T_FLOAT); }
    | variavel { $$ = usa_variavel($1, @1.first_line); }
    | chamada_funcao
        {
            if ($1.tipo == T_VOID) {
                erro_semantico(@1.first_line, "função void não produz valor para uso em expressão");
                $$ = expr_erro();
            } else {
                $$ = $1;
            }
        }
    | TK_LPAREN expressao TK_RPAREN { $$ = $2; }

    | expressao TK_OP_ADD expressao { $$ = binaria("+",  ARITMETICA, $1, $3, @2.first_line); }
    | expressao TK_OP_SUB expressao { $$ = binaria("-",  ARITMETICA, $1, $3, @2.first_line); }
    | expressao TK_OP_MUL expressao { $$ = binaria("*",  ARITMETICA, $1, $3, @2.first_line); }
    | expressao TK_OP_DIV expressao { $$ = binaria("/",  ARITMETICA, $1, $3, @2.first_line); }
    | expressao TK_OP_MOD expressao { $$ = binaria("%",  RESTO,      $1, $3, @2.first_line); }

    | expressao TK_OP_EQ  expressao { $$ = binaria("==", RELACIONAL, $1, $3, @2.first_line); }
    | expressao TK_OP_NEQ expressao { $$ = binaria("!=", RELACIONAL, $1, $3, @2.first_line); }
    | expressao TK_OP_LT  expressao { $$ = binaria("<",  RELACIONAL, $1, $3, @2.first_line); }
    | expressao TK_OP_GT  expressao { $$ = binaria(">",  RELACIONAL, $1, $3, @2.first_line); }
    | expressao TK_OP_LEQ expressao { $$ = binaria("<=", RELACIONAL, $1, $3, @2.first_line); }
    | expressao TK_OP_GEQ expressao { $$ = binaria(">=", RELACIONAL, $1, $3, @2.first_line); }

    | expressao TK_OP_AND expressao { $$ = binaria("&&", LOGICA, $1, $3, @2.first_line); }
    | expressao TK_OP_OR  expressao { $$ = binaria("||", LOGICA, $1, $3, @2.first_line); }

    | TK_OP_NOT expressao                { $$ = unaria("!", $2, @1.first_line); }
    | TK_OP_SUB expressao %prec UMINUS   { $$ = unaria("-", $2, @1.first_line); }
    ;

%%

/* Mensagem de erro sintático em português: "encontrado X, esperado A, B ou C". */
static const char *nome_simbolo(yysymbol_kind_t s)
{
    return s == YYSYMBOL_YYEOF ? "fim do arquivo" : yysymbol_name(s);
}

int yyreport_syntax_error(const yypcontext_t *ctx)
{
    enum { MAX_ESPERADOS = 5 };
    yysymbol_kind_t esperados[MAX_ESPERADOS];
    yysymbol_kind_t encontrado = yypcontext_token(ctx);
    int n = yypcontext_expected_tokens(ctx, esperados, MAX_ESPERADOS);

    fprintf(stderr, "Erro sintático na linha %d: encontrado %s",
            yypcontext_location(ctx)->first_line,
            nome_simbolo(encontrado));
    if (n > 0 && n < MAX_ESPERADOS) {
        fprintf(stderr, ", esperado ");
        for (int i = 0; i < n; i++)
            fprintf(stderr, "%s%s", i ? (i == n - 1 ? " ou " : ", ") : "", nome_simbolo(esperados[i]));
    }
    fprintf(stderr, "\n");
    erros_sintaticos++;
    return 0;
}

void yyerror(const char *s)
{
    fprintf(stderr, "%s\n", s);
    erros_sintaticos++;
}

int main(void)
{
    yyparse();

    if (!funcao_busca("principal") && erros_sintaticos == 0)
        erro_semantico(0, "função 'principal' não definida");

    int total = erros_lexicos + erros_sintaticos + erros_semanticos;
    printf("Análise léxica:     %d erro(s)\n", erros_lexicos);
    printf("Análise sintática:  %d erro(s)\n", erros_sintaticos);
    if (erros_lexicos + erros_sintaticos > 0)
        printf("Análise semântica:  não executada (corrija os erros acima)\n");
    else
        printf("Análise semântica:  %d erro(s)\n", erros_semanticos);

    if (total > 0) {
        printf("Compilação interrompida: nenhum código foi gerado.\n");
        return 1;
    }

    printf("Programa reconhecido com sucesso.\n\n");
    tabela_imprime(stdout);
    printf("\nCódigo de três endereços:\n");
    quad_imprime_codigo(stdout);
    printf("\nQuádruplas:\n");
    quad_imprime_tabela(stdout);
    return 0;
}
