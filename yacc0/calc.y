%{
 #include <stdio.h>
 int yylex(void);
 void yyerror(char *);
%}

%token INTEGER

%%

program:
  expr '\n'    { printf("%d\n", $1); }
  ;

expr:
 INTEGER { $$ = $1; }
 ;

%%
void yyerror(char *s) {
 fprintf(stderr, "%s\n", s);
}
int main(void) {
 yyparse();
 return 0;
} 
