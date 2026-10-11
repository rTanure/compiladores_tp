%{
#include <stdio.h>
#define TOK(t) (printf("%-10s -> %s\n", #t, yytext), t)

enum { GLOBAL_ID = 1, LOCAL_ID, FUNC_ID };

%}

GLOBAL  [A-Z][A-Z0-9_]*
LOCAL   [a-z][a-z0-9_]*
FUNC    [a-z][a-zA-Z0-9]*

%%
{GLOBAL}         {return TOK(GLOBAL_ID);}
{LOCAL}          {return TOK(LOCAL_ID);}
{FUNC}           {return TOK(FUNC_ID);}

[ \t\r\n]+  { }
.           { printf("CARACTERE INVALIDO: %s\n", yytext); }

%%

int yywrap(void)
{
    return 1;
}


int main(void)
{
    while (yylex() != 0);
    return 0;
}