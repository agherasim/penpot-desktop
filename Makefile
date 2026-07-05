APP_NAME     := Penpot
APP_DIR      := $(HOME)/Applications/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR    := $(CONTENTS_DIR)/MacOS
RES_DIR      := $(CONTENTS_DIR)/Resources

SRC_DIR      := src
SWIFT_SRC    := $(wildcard $(SRC_DIR)/menubar/*.swift) Sources/DockerStats/DockerStatsParser.swift
MENUBAR_BIN  := $(MACOS_DIR)/PenpotMenuBar

LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

SHELL_RC     := $(HOME)/.zshrc
ALIAS_LINE   := alias penpot='$(MACOS_DIR)/Penpot'

.PHONY: all build install post-install clean uninstall status test

all: build

build: $(MENUBAR_BIN)

$(MENUBAR_BIN): $(SWIFT_SRC) | $(MACOS_DIR)
	swiftc -O -o $@ $(SWIFT_SRC) -framework Cocoa

install: build | $(RES_DIR)
	cp $(SRC_DIR)/app/Info.plist $(CONTENTS_DIR)/Info.plist
	@if [ -f $(MACOS_DIR)/.env ]; then \
		echo ".env already exists, skipping (remove it manually to reset)"; \
	else \
		cp .env $(MACOS_DIR)/.env; \
	fi
	cp $(SRC_DIR)/app/docker-compose.yaml $(MACOS_DIR)/docker-compose.yaml
	cp $(SRC_DIR)/scripts/Penpot $(MACOS_DIR)/Penpot
	chmod +x $(MACOS_DIR)/Penpot
	cp $(SRC_DIR)/resources/AppIcon.icns $(RES_DIR)/AppIcon.icns
	cp $(SRC_DIR)/resources/MenuBarIconTemplate.png $(RES_DIR)/MenuBarIconTemplate.png
	cp $(SRC_DIR)/resources/MenuBarIconTemplate@2x.png $(RES_DIR)/MenuBarIconTemplate@2x.png
	touch $(APP_DIR)
	$(LSREGISTER) -f $(APP_DIR)
	@echo "Installed: $(APP_DIR)"
	@$(MAKE) post-install

post-install:
	@if grep -qF 'alias penpot=' $(SHELL_RC) 2>/dev/null; then \
		echo "Shell alias already exists in $(SHELL_RC)"; \
	else \
		echo '\n# Penpot Desktop' >> $(SHELL_RC); \
		echo '$(ALIAS_LINE)' >> $(SHELL_RC); \
		echo "Added 'penpot' alias to $(SHELL_RC) — restart your shell or run: source $(SHELL_RC)"; \
	fi

$(MACOS_DIR) $(RES_DIR):
	mkdir -p $@

clean:
	rm -f $(MENUBAR_BIN)
	@echo "Cleaned build artifacts"

uninstall:
	rm -rf $(APP_DIR)
	@if grep -qF 'alias penpot=' $(SHELL_RC) 2>/dev/null; then \
		sed -i '' '/# Penpot Desktop/d;/alias penpot=/d' $(SHELL_RC); \
		echo "Removed 'penpot' alias from $(SHELL_RC)"; \
	fi
	@echo "Uninstalled: $(APP_DIR)"

test:
	swift test

status:
	@test -d $(APP_DIR) && echo "$(APP_DIR) exists" || echo "$(APP_DIR) not found"
	@test -f $(MENUBAR_BIN) && echo "PenpotMenuBar binary: OK" || echo "PenpotMenuBar binary: missing (run make build)"
