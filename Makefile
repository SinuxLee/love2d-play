.PHONY: run pack new update-submodules list test unit-test love-unit-test integration-test test-all

LOVE_CMD ?= love
ifeq ($(shell uname),Darwin)
	LOVE_CMD := /Applications/love.app/Contents/MacOS/love
endif

LUA_CMD ?= luajit
ifeq ($(shell which luajit 2>/dev/null),)
	LUA_CMD := lua
endif

run:
ifndef GAME
	$(error Usage: make run GAME=<game_name>)
endif
	$(LOVE_CMD) games/$(GAME)

pack:
ifndef GAME
	$(error Usage: make pack GAME=<game_name>)
endif
	bash tools/pack.sh $(GAME)

new:
ifndef GAME
	$(error Usage: make new GAME=<game_name>)
endif
	bash tools/new_project.sh $(GAME)

update-submodules:
	bash tools/submodule_update.sh

list:
	@echo "Available games:"
	@ls -1 games/ | grep -v '\.gitkeep'

test:
ifndef GAME
	$(error Usage: make test GAME=<game_name>)
endif
	@$(MAKE) unit-test GAME=$(GAME)
	@$(MAKE) integration-test GAME=$(GAME)

unit-test:
ifndef GAME
	$(error Usage: make unit-test GAME=<game_name>)
endif
	@$(LUA_CMD) shared/testing/runner.lua games/$(GAME)/tests games/$(GAME)/src

# love-unit-test: runs unit tests via Love2D headless mode.
# Use this on Windows where standalone luajit/lua is unavailable.
love-unit-test:
ifndef GAME
	$(error Usage: make love-unit-test GAME=<game_name>)
endif
	@$(LOVE_CMD) shared/testing/unit_runner --game=$(GAME)

integration-test:
ifndef GAME
	$(error Usage: make integration-test GAME=<game_name>)
endif
	@$(LOVE_CMD) shared/testing/love_runner --game=$(GAME)

test-all:
	@failed=0; \
	for game in $$(ls -1 games/ | grep -v '\.gitkeep'); do \
		if [ -d "games/$$game/tests" ]; then \
			echo "=== Testing $$game ==="; \
			$(MAKE) test GAME=$$game || failed=1; \
			echo ""; \
		fi; \
	done; \
	exit $$failed
