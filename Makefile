
lexlib=l
yacclib=y
bindir=bin
target=py-style-lang

all: $(target)

$(target): $(target).y $(target).lex Makefile
	flex -o$@.lex.c $@.lex
	bison -o$@.tab.c -d $<
	g++ -w $@.tab.c $@.lex.c -l$(yacclib) -l$(lexlib) -o $(bindir)/$@
	$(RM) $@.tab.c $@.tab.h $@.lex.c

clean:
	$(RM) $(target)
	$(RM) *.tab.h *.tab.c *.lex.c
	$(RM) *.pyc
