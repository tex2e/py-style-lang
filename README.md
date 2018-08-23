
Python-style-indented Language
==============================

python みたいな indent 付きの自作言語（with bison + yacc）

```
$ make

$ cat tests/test1

if 2 != 3:
  if 5 >= 7 + 11:
    1111
  else:
    if 13 < 17 + 19:
      2222
    else:
      3333
else:
  4444

print

$ ./bin/py-style-lang tests/test1
>> 2222
```
