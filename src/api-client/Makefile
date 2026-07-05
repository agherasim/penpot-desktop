BIN_SRC := cmd
BIN := penpot-cli
ROOT_ENV := ../../.env

.PHONY: build test clean run

build:
	go build -o $(BIN) ./$(BIN_SRC)

test:
	@echo "tests not implemented yet"

clean:
	rm -f $(BIN)

# Sources the repo-root .env (shared with the app) before running the CLI.
run: build
	@sh -c 'if [ -f $(ROOT_ENV) ]; then set -a; . $(ROOT_ENV); set +a; fi; ./$(BIN) $(ARGS)'
