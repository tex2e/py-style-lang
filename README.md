
Python-style-indented Language
==============================

python みたいな indent 付きの自作言語（with bison + yacc）

実装したのは：

- 整数（int型）のみ
- int型変数
- if, if-else 式（indent）
- print

```
$ make

$ cat tests/test1

result =
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

print result

$ ./bin/py-style-lang tests/test1
>> 2222
```

TODO:

- print を遅延評価にする（現在は構文解析中に出力されてしまう）
