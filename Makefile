make:
	flex pipeline.l
	gcc -pthread lex.yy.c cache.c main.c -o processor_cache_simulator