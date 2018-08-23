
%{
#include <stack>
#include <iostream>

// --- indent ---

/* globals to track current indentation */
int g_current_line_indent = 0;   /* indentation of the current line */
std::stack<size_t> g_indent_levels;
int g_is_fake_dedent_symbol = 0;

/* TODO: error-out on tabs/spaces mix? */
static const unsigned int TAB_WIDTH = 2;

extern const char* g_current_filename;

/* Don't mangle yylex please! */
#define YY_DECL extern "C" int yylex()
#include "py-style-lang.tab.h"

#define YY_USER_INIT { \
        g_indent_levels.push(0); \
        BEGIN(initial); \
    }

int yycolumn = 1;
void set_yycolumn(int val) {
    yycolumn = val;
    yylloc.first_column = yycolumn;
    yylloc.last_column = yycolumn + yyleng - 1;
}

%}

/* This is a sub-parser (state) for indentation-sensitive scoping */
%x initial
%x indent
%s normal

/* %option 8bit reentrant bison-bridge */
%option warn
%option nodefault
%option yylineno
%option noyywrap

white       [ \t]*

%%

    int indent_caller = normal;

#.*\n { REJECT; }

 /* This helps to keep track of the column number.
  * Note that it won't work if you have a rule which includes a newline and is
  * longer than one character because in that case that rule will be favored
  * and this one here won't get called.
  * TL;DR: If you have a rule which includes \n and more, you need to reset
  *        yycolumn inside that rule!
  */
<*>\n       { set_yycolumn(0); yylineno--; REJECT; }

 /* Everything runs in the <normal> mode and enters the <indent> mode
    when a newline symbol is encountered.
    There is no newline symbol before the first line, so we need to go
    into the <indent> mode by hand there.
 */
<initial>.  { set_yycolumn(yycolumn-1); indent_caller = normal; yyless(0); BEGIN(indent); }
<initial>\n { indent_caller = normal; yyless(0); BEGIN(indent); }

 /* The following are the rules that keep track of indentation. */
<indent>" "     { g_current_line_indent++; }
<indent>\t      { g_current_line_indent = (g_current_line_indent + TAB_WIDTH) & ~(TAB_WIDTH-1); }
<indent>\n      { g_current_line_indent = 0; /* ignoring blank line */ }
<indent><<EOF>> {
                    // When encountering the end of file, we want to emit an
                    // dedent for all indents currently left.
                    if (g_indent_levels.top() != 0) {
                        g_indent_levels.pop();

                        // See the same code below (<indent>.) for a rationale.
                        if (g_current_line_indent != g_indent_levels.top()) {
                            unput('\n');
                            for(size_t i = 0 ; i < g_indent_levels.top() ; ++i) {
                                unput(' ');
                            }
                        } else {
                            BEGIN(indent_caller);
                        }

                        return TOK_DEDENT;
                    } else {
                        yyterminate();
                    }
                }

<indent>.       {
                    if(!g_is_fake_dedent_symbol) {
                        unput(*yytext);
                    }
                    set_yycolumn(yycolumn-1);
                    g_is_fake_dedent_symbol = 0;

                    // Indentation level has increased. It can only ever
                    // increase by one level at a time. Remember how many
                    // spaces this level has and emit an indentation token.
                    if (g_current_line_indent > g_indent_levels.top()) {
                        g_indent_levels.push(g_current_line_indent);
                        BEGIN(indent_caller);
                        return TOK_INDENT;
                    } else if (g_current_line_indent < g_indent_levels.top()) {
                        // Outdenting is the most difficult, as we might need to
                        // dedent multiple times at once, but flex doesn't allow
                        // emitting multiple tokens at once! So we fake this by
                        // 'unput'ting fake lines which will give us the next
                        // dedent.
                        g_indent_levels.pop();

                        if (g_current_line_indent != g_indent_levels.top()) {
                            // Unput the rest of the current line, including the newline.
                            // We want to keep it untouched.
                            for (size_t i = 0 ; i < g_current_line_indent ; ++i) {
                                unput(' ');
                            }
                            unput('\n');
                            // Now, insert a fake character indented just so
                            // that we get a correct dedent the next time.
                            unput('.');
                            // Though we need to remember that it's a fake one
                            // so we can ignore the symbol.
                            g_is_fake_dedent_symbol = 1;
                            for (size_t i = 0 ; i < g_indent_levels.top() ; ++i) {
                                unput(' ');
                            }
                            unput('\n');
                        } else {
                            BEGIN(indent_caller);
                        }

                        return TOK_DEDENT;
                    } else {
                        // No change in indentation, not much to do here...
                        BEGIN(indent_caller);
                    }
                }

<normal>\n  { g_current_line_indent = 0; indent_caller = YY_START; BEGIN(indent); }

if{white}    { return IF; }
:{white}     { return THEN; }
else:{white} { return ELSE; }

{white}={white}    { return ASSIGN; }
{white}=={white}   { return TOK_EQ; }
{white}!={white}   { return TOK_NE; }
{white}>={white}   { return TOK_GE; }
{white}<={white}   { return TOK_LE; }
{white}>{white}    { return TOK_GT; }
{white}<{white}    { return TOK_LT; }
{white}\+{white}   { return TOK_PLUS; }
{white}\-{white}   { return TOK_MINUS; }
{white}\*{white}   { return TOK_MUL; }
{white}\/{white}   { return TOK_DIV; }
{white}\({white}   { return TOK_L_P; }
{white}\){white}   { return TOK_R_P; }
"\n"             { return LF; }

[0-9]+      {
                yylval.int_value = atoi(yytext);
                return INTNUM;
            }

true        { yylval.int_value = 1; return TRUE; }
false       { yylval.int_value = 0; return FALSE; }

print{white} { return PRINT; }

[a-zA-Z_]+[0-9a-zA-Z_]  {
                yylval.string = strdup(yytext);
                return VAR;
            }

.           {
                fprintf(stderr, "%s:%d:%d: Unexpected character: %s",
                    g_current_filename, yylineno, yycolumn, yytext);
                exit(1);
            }

%%
