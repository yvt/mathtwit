
EMCC = emcc
COFFEE = coffee
EMCFLAGS = -w -DAA --memory-init-file 1

default:			all

all:	contents/mathtwit.js contents/mimetex.js

contents/mathtwit.js:	client/mathtwit.coffee
	$(COFFEE) -o contents -c client/mathtwit.coffee

contents/mimetex.js:	client/mimetex.c client/mimetex.h
	$(EMCC) -s EXPORTED_FUNCTIONS="['_MathTwit_Generate','_main']" -o contents/mimetex.js client/mimetex.c $(EMCFLAGS)
