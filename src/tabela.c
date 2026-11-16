#include <stdlib.h>
#include <string.h>
#include "tabela.h"

typedef struct {
    Simbolo simbolo;
    int     nivel;
} Entrada;

typedef struct {
    char *nome;
    Tipo  tipo;
    char *escopo;
} Registro;

static Entrada  *pilha;
static int       topo, cap_pilha;
static int       nivel_atual;
static char     *dono_atual = "global";

static Registro *historico;
static int       n_historico, cap_historico;

static Funcao   *funcoes;
static int       n_funcoes, cap_funcoes;

#define CRESCE(vetor, n, cap) \
    do { \
        if ((n) == (cap)) { \
            (cap) = (cap) ? (cap) * 2 : 16; \
            (vetor) = realloc((vetor), (cap) * sizeof *(vetor)); \
            if (!(vetor)) { perror("realloc"); exit(1); } \
        } \
    } while (0)

const char *tipo_nome(Tipo t)
{
    switch (t) {
        case T_INT:   return "int";
        case T_FLOAT: return "float";
        case T_VOID:  return "void";
        default:      return "erro";
    }
}

int tipo_compativel(Tipo destino, Tipo origem)
{
    return destino == origem || (destino == T_FLOAT && origem == T_INT);
}

void escopo_entra(const char *dono)
{
    nivel_atual++;
    if (nivel_atual == 1)
        dono_atual = strdup(dono);
}

void escopo_sai(void)
{
    while (topo > 0 && pilha[topo - 1].nivel == nivel_atual)
        topo--;
    nivel_atual--;
    if (nivel_atual == 0)
        dono_atual = "global";
}

int simbolo_declara(const char *nome, Tipo tipo)
{
    for (int i = topo - 1; i >= 0 && pilha[i].nivel == nivel_atual; i--)
        if (strcmp(pilha[i].simbolo.nome, nome) == 0)
            return 0;

    CRESCE(pilha, topo, cap_pilha);
    pilha[topo].simbolo.nome = strdup(nome);
    pilha[topo].simbolo.tipo = tipo;
    pilha[topo].nivel = nivel_atual;
    topo++;

    CRESCE(historico, n_historico, cap_historico);
    historico[n_historico].nome   = strdup(nome);
    historico[n_historico].tipo   = tipo;
    historico[n_historico].escopo = dono_atual;
    n_historico++;
    return 1;
}

const Simbolo *simbolo_busca(const char *nome)
{
    for (int i = topo - 1; i >= 0; i--)
        if (strcmp(pilha[i].simbolo.nome, nome) == 0)
            return &pilha[i].simbolo;
    return NULL;
}

int funcao_declara(const char *nome, Tipo retorno, const Tipo *params, int n)
{
    if (funcao_busca(nome))
        return 0;

    CRESCE(funcoes, n_funcoes, cap_funcoes);
    Funcao *f = &funcoes[n_funcoes++];
    f->nome    = strdup(nome);
    f->retorno = retorno;
    f->nparams = n;
    memcpy(f->params, params, n * sizeof *params);
    return 1;
}

const Funcao *funcao_busca(const char *nome)
{
    for (int i = 0; i < n_funcoes; i++)
        if (strcmp(funcoes[i].nome, nome) == 0)
            return &funcoes[i];
    return NULL;
}

void tabela_imprime(FILE *out)
{
    fprintf(out, "Tabela de símbolos:\n");
    fprintf(out, "  %-20s %-8s %s\n", "Nome", "Tipo", "Escopo");
    for (int i = 0; i < n_funcoes; i++)
        fprintf(out, "  %-20s %-8s %s\n", funcoes[i].nome,
                tipo_nome(funcoes[i].retorno), "função");
    for (int i = 0; i < n_historico; i++)
        fprintf(out, "  %-20s %-8s %s\n", historico[i].nome,
                tipo_nome(historico[i].tipo), historico[i].escopo);
}
