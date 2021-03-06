.PHONY: all clean test doc

BUILD_LIB=dune build
BUILD_EXAMPLE=\
	dune build example/echo/echo.exe \
	example/echoes/echo.exe \
	example/actor/aecho.exe \
	example/tactor/taecho.exe \
	example/sactor/sactor.exe \
	example/fnactor/fnactor_example.exe \
	example/monad/statem.exe
	

CLEAN= dune clean
TEST=dune runtest -j1 --no-buffer
DOC=dune build --dev @doc
INSTALL=dune install

all:
		${BUILD_LIB}
		${BUILD_EXAMPLE}

test:
		${TEST}

doc:
	${DOC}

install:
		${INSTALL}

clean:
	${CLEAN}
