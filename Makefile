APP_NAME     := Penpot
APP_DIR      := $(HOME)/Applications/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR    := $(CONTENTS_DIR)/MacOS
RES_DIR      := $(CONTENTS_DIR)/Resources

SRC_DIR      := src
SWIFT_SRC    := $(SRC_DIR)/menubar/PenpotMenuBar.swift
MENUBAR_BIN  := $(MACOS_DIR)/PenpotMenuBar

LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: all build install clean uninstall status

all: build

build: $(MENUBAR_BIN)

$(MENUBAR_BIN): $(SWIFT_SRC) | $(MACOS_DIR)
	swiftc -O -o $@ $< -framework Cocoa

install: build | $(RES_DIR)
	cp $(SRC_DIR)/app/Info.plist $(CONTENTS_DIR)/Info.plist
	@if [ -f $(MACOS_DIR)/.env ]; then \
		echo ".env already exists, skipping (remove it manually to reset)"; \
	else \
		cp $(SRC_DIR)/app/.env $(MACOS_DIR)/.env; \
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

$(MACOS_DIR) $(RES_DIR):
	mkdir -p $@

clean:
	rm -f $(MENUBAR_BIN)
	@echo "Cleaned build artifacts"

uninstall:
	rm -rf $(APP_DIR)
	@echo "Uninstalled: $(APP_DIR)"

status:
	@test -d $(APP_DIR) && echo "$(APP_DIR) exists" || echo "$(APP_DIR) not found"
	@test -f $(MENUBAR_BIN) && echo "PenpotMenuBar binary: OK" || echo "PenpotMenuBar binary: missing (run make build)"
