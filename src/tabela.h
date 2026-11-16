#ifndef TABELA_H
#define TABELA_H

#include <stdio.h>

#define MAX_PARAMS 16

typedef enum { T_ERRO, T_VOID, T_INT, T_FLOAT } Tipo;

typedef struct {
    char *nome;
    Tipo  tipo;
} Simbolo;

typedef struct {
    char *nome;
    Tipo  retorno;
    int   nparams;
    Tipo  params[MAX_PARAMS];
} Funcao;

const char *tipo_nome(Tipo t);
int         tipo_compativel(Tipo destino, Tipo origem);

/* Escopos de variáveis: o nível 0 é o escopo global. */
void           escopo_entra(const char *dono);
void           escopo_sai(void);
int            simbolo_declara(const char *nome, Tipo tipo);
const Simbolo *simbolo_busca(const char *nome);

/* Funções (sempre globais). */
int            funcao_declara(const char *nome, Tipo retorno, const Tipo *params, int n);
const Funcao  *funcao_busca(const char *nome);

/* Lista todas as variáveis declaradas, com o escopo de cada uma. */
void tabela_imprime(FILE *out);

#endif
