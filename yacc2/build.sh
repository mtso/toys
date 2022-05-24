#!/bin/sh

lex sql.l
yacc -d sql.y
../zig/zig cc lex.yy.c y.tab.c

