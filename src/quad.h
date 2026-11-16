#ifndef QUAD_H
#define QUAD_H

#include <stdio.h>

/*
 * Quádrupla (op, arg1, arg2, result). Campos não usados ficam NULL.
 *
 *   op          arg1    arg2   result   texto gerado
 *   "+" "-" ... a       b      t        t = a + b
 *   "-" "!"     a       NULL   t        t = - a
 *   "inttofloat" a      NULL   t        t = inttofloat a
 *   "="         a       NULL   x        x = a
 *   "label"     NULL    NULL   L        L:
 *   "goto"      NULL    NULL   L        goto L
 *   "ifFalse"   c       NULL   L        ifFalse c goto L
 *   "param"     a       NULL   NULL     param a
 *   "call"      f       n      t|NULL   t = call f, n
 *   "return"    a|NULL  NULL   NULL     return a
 */

void  quad_emit(const char *op, const char *arg1, const char *arg2, const char *result);
char *quad_temp(void);
int   quad_rotulo(void);

void  quad_emit_label(int rotulo);
void  quad_emit_goto(int rotulo);
void  quad_emit_if_false(const char *cond, int rotulo);

void  quad_imprime_codigo(FILE *out);
void  quad_imprime_tabela(FILE *out);

#endif
