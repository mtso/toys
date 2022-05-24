%{
#include <stdio.h>

void yyerror (const char *str) {
	fprintf(stderr, "error: %s\n", str);
}

int yywrap() {
	return 1;
}

int main() {
	yyparse();
	return 0;
}

%}

%%

%token SELECT FROM IDENTIFIER WHERE AND;

line: select items using condition '\n' { printf("Syntax Correct\n"); };

select: SELECT;

items: '*' | identifiers;

identifiers: IDENTIFIER | IDENTIFIER ',' identifiers;

using: FROM IDENTIFIER WHERE;

condition: IDENTIFIER '=' IDENTIFIER | IDENTIFIER '=' IDENTIFIER AND condition;

%%
