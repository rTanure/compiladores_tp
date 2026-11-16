# Compilador (Flex + Bison)

Análise léxica, sintática e semântica, com geração de código de três endereços (quádruplas).

## Dependências
- gcc, make, cmake >= 3.10
- flex >= 2.6
- bison >= 3.6

## Como rodar
- `make` — compila e roda `inputs/input.txt`
- `make INPUT=inputs/ok.txt` — roda outro arquivo
- `make test` — roda todos os testes em `inputs/`

## A linguagem
Tipos: `int`, `float` (e `void` como retorno). Comandos: declaração, atribuição, `if`/`else`,
`while`, `return` e chamada de função. A função de entrada é `principal`.

| Elemento        | Convenção                  | Exemplo         |
|-----------------|----------------------------|-----------------|
| Global          | MAIÚSCULAS                 | `SOMA`, `MAX_N` |
| Local/parâmetro | minúsculas (snake_case)    | `total_geral`   |
| Função          | verbo + Termo (camelCase)  | `calcularSoma`  |

Operadores: `+ - * / %`, `== != < > <= >=`, `&& || !`, `-` unário.

## Estrutura
- `src/lexer.l` — analisador léxico (erros com dicas)
- `src/parser.y` — gramática, verificações semânticas e geração de código
- `src/tabela.c` — escopos, tabela de símbolos e tabela de funções
- `src/quad.c` — quádruplas, temporários (`t1`...) e rótulos (`L1`...)

## Verificações semânticas
Variável/função declarada antes do uso, declaração duplicada no escopo, compatibilidade de
tipos (`int` → `float` é implícito, o inverso é erro), `%` e operadores lógicos só com `int`,
quantidade e tipos dos argumentos, `return` coerente com o tipo da função, função `void` fora de
expressão e existência de `principal`. Se houver erro léxico ou sintático, a análise semântica
não é executada; se houver qualquer erro, nenhum código é gerado.

## Quádruplas `(op, arg1, arg2, result)`
| op                   | arg1  | arg2 | result | texto              |
|----------------------|-------|------|--------|--------------------|
| `+ - * / % < ...`    | a     | b    | t      | `t = a + b`        |
| `-` `!` `inttofloat` | a     | –    | t      | `t = - a`          |
| `=`                  | a     | –    | x      | `x = a`            |
| `label`              | –     | –    | L      | `L:`               |
| `goto`               | –     | –    | L      | `goto L`           |
| `ifFalse`            | c     | –    | L      | `ifFalse c goto L` |
| `param`              | a     | –    | –      | `param a`          |
| `call`               | f     | n    | t / –  | `t = call f, n`    |
| `return`             | a / – | –    | –      | `return a`         |

Condições relacionais viram uma temporária (`t = a > b`) e o `ifFalse` testa essa temporária.
`&&` e `||` avaliam os dois lados (sem curto-circuito).
