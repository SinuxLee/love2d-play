.PHONY: run pack new update-submodules list

LOVE_CMD ?= love
ifeq ($(shell uname),Darwin)
	LOVE_CMD := /Applications/love.app/Contents/MacOS/love
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
