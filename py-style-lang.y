
%{
#include <cstdio>
#include <iostream>

// stuff from flex that bison needs to know about:
extern "C" int yylex();
extern "C" int yyparse();
extern "C" FILE *yyin;

void yyerror(const char *s);

static const char* black   = "\033[0;30m";
static const char* red     = "\033[0;31m";
static const char* green   = "\033[0;32m";
static const char* yellow  = "\033[0;33m";
static const char* blue    = "\033[0;34m";
static const char* magenta = "\033[0;35m";
static const char* cyan    = "\033[0;36m";
static const char* white   = "\033[0;37m";
static const char* fg      = "\033[0;39m";

#define YYSTYPE int

int it = 0;
%}

%token TOK_INDENT TOK_DEDENT

%token INTNUM TRUE FALSE
%token IF THEN ELSE PRINT
%token TOK_EQ TOK_NE TOK_GE TOK_LE TOK_GT TOK_LT
%token TOK_PLUS TOK_MINUS TOK_MUL TOK_DIV TOK_L_P TOK_R_P

%%
root
    : statements
    ;

statements
    : statements statement { $$ = it = $2; }
    | statement            { $$ = it = $1; }
    ;

statement
    : expr                                  { $$ = $1; }
    | IF cond THEN codeblock                { if ($2 != 0) $$ = $4; }
    | IF cond THEN codeblock ELSE codeblock { if ($2 != 0) $$ = $4; else $$ = $6; }
    | PRINT                                 { printf(">> %d\n", it); }
    ;

codeblock
    : indent statements dedent { $$ = $2; }
    ;

expr
    : term                  { $$ = $1; }
    | expr TOK_PLUS term    { $$ = $1 + $3; }
    | expr TOK_MINUS term   { $$ = $1 - $3; }
    ;

term
    : factor                { $$ = $1; }
    | term TOK_MUL factor   { $$ = $1 * $3; }
    | term TOK_DIV factor   { $$ = $1 / $3; }
    ;

factor
    : INTNUM                { $$ = $1; }
    | TOK_L_P expr TOK_R_P  { $$ = $2; }
    | TRUE                  { $$ = 1; }
    | FALSE                 { $$ = 0; }
    ;

cond
    : expr TOK_EQ expr        { $$ = ($1 == $3); }
    | expr TOK_NE expr        { $$ = ($1 != $3); }
    | expr TOK_GE expr        { $$ = ($1 >= $3); }
    | expr TOK_LE expr        { $$ = ($1 <= $3); }
    | expr TOK_GT expr        { $$ = ($1 > $3); }
    | expr TOK_LT expr        { $$ = ($1 < $3); }
    | expr                    { $$ = $1; }
    ;

indent
    : TOK_INDENT
        {
            FILE *debug = fopen("/dev/null", "w");
            fprintf(debug, "%sindent%s(%d:%d-%d)\n",
                green, fg, @1.first_line, @1.first_column, @1.last_column);
        }

dedent
    : TOK_DEDENT
        {
            FILE *debug = fopen("/dev/null", "w");
            fprintf(debug, "%sdedent%s(%d:%d-%d)\n",
                green, fg, @1.first_line, @1.first_column, @1.last_column);
        }
    ;

%%

const char* g_current_filename = "stdin";

int main(int argc, char *argv[]) {
    yyin = stdin;
#if YYDEBUG
    yydebug = 1;
#endif

    if (argc == 2) {
        yyin = fopen(argv[1], "r");
        g_current_filename = argv[1];
        if (!yyin) {
            perror(argv[1]);
            return 1;
        }
    }

    do {
        yyparse();
    } while (!feof(yyin));
}

void yyerror(const char *s) {
    fprintf(stderr, "%s:%d:%d-%d: syntax error: %s\n",
        g_current_filename, yylloc.first_line,
        yylloc.first_column, yylloc.last_column, s);
    exit(-1);
}
