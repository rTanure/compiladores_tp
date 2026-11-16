#include <stdlib.h>
#include <string.h>
#include "quad.h"

typedef struct {
    char *op, *arg1, *arg2, *result;
} Quadrupla;

static Quadrupla *codigo;
static int        n_quads, cap_quads;
static int        n_temps, n_rotulos;

static char *copia(const char *s)
{
    return s ? strdup(s) : NULL;
}

void quad_emit(const char *op, const char *arg1, const char *arg2, const char *result)
{
    if (n_quads == cap_quads) {
        cap_quads = cap_quads ? cap_quads * 2 : 64;
        codigo = realloc(codigo, cap_quads * sizeof *codigo);
        if (!codigo) { perror("realloc"); exit(1); }
    }
    codigo[n_quads++] = (Quadrupla){ copia(op), copia(arg1), copia(arg2), copia(result) };
}

char *quad_temp(void)
{
    char buf[16];
    snprintf(buf, sizeof buf, "t%d", ++n_temps);
    return strdup(buf);
}

int quad_rotulo(void)
{
    return ++n_rotulos;
}

void quad_emit_label(int rotulo)
{
    char buf[16];
    snprintf(buf, sizeof buf, "L%d", rotulo);
    quad_emit("label", NULL, NULL, buf);
}

void quad_emit_goto(int rotulo)
{
    char buf[16];
    snprintf(buf, sizeof buf, "L%d", rotulo);
    quad_emit("goto", NULL, NULL, buf);
}

void quad_emit_if_false(const char *cond, int rotulo)
{
    char buf[16];
    snprintf(buf, sizeof buf, "L%d", rotulo);
    quad_emit("ifFalse", cond, NULL, buf);
}

void quad_imprime_codigo(FILE *out)
{
    for (int i = 0; i < n_quads; i++) {
        const Quadrupla *q = &codigo[i];

        if (!strcmp(q->op, "label"))
            fprintf(out, "%s:\n", q->result);
        else if (!strcmp(q->op, "goto"))
            fprintf(out, "    goto %s\n", q->result);
        else if (!strcmp(q->op, "ifFalse"))
            fprintf(out, "    ifFalse %s goto %s\n", q->arg1, q->result);
        else if (!strcmp(q->op, "param"))
            fprintf(out, "    param %s\n", q->arg1);
        else if (!strcmp(q->op, "return"))
            fprintf(out, q->arg1 ? "    return %s\n" : "    return\n", q->arg1);
        else if (!strcmp(q->op, "call")) {
            if (q->result)
                fprintf(out, "    %s = call %s, %s\n", q->result, q->arg1, q->arg2);
            else
                fprintf(out, "    call %s, %s\n", q->arg1, q->arg2);
        }
        else if (!strcmp(q->op, "="))
            fprintf(out, "    %s = %s\n", q->result, q->arg1);
        else if (q->arg2)
            fprintf(out, "    %s = %s %s %s\n", q->result, q->arg1, q->op, q->arg2);
        else
            fprintf(out, "    %s = %s %s\n", q->result, q->op, q->arg1);
    }
}

void quad_imprime_tabela(FILE *out)
{
    #define CAMPO(s) ((s) ? (s) : "-")
    fprintf(out, "%4s  %-11s %-12s %-6s %s\n", "Nº", "op", "arg1", "arg2", "result");
    for (int i = 0; i < n_quads; i++)
        fprintf(out, "%4d  %-11s %-12s %-6s %s\n", i, codigo[i].op,
                CAMPO(codigo[i].arg1), CAMPO(codigo[i].arg2), CAMPO(codigo[i].result));
    #undef CAMPO
}
