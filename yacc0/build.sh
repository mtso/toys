#!/bin/sh

yacc -d calc.y
lex calc.l
../zig/zig cc lex.yy.c y.tab.c
 
