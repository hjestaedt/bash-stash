# bash-stash Makefile

INSTALL_DIR ?= $(HOME)/bin
SCRIPT_NAME = stash

MAIN_SCRIPT = stash
LIB_DIR = lib
INSTALLED_LIB_DIR = bash-stash.d
LIB_FILES = $(wildcard $(LIB_DIR)/*.sh)
TEST_SCRIPT = test_stash.sh

.PHONY: install uninstall clean test check show-config

install:
	@echo "installing $(SCRIPT_NAME) to $(INSTALL_DIR)..."
	@mkdir -p "$(INSTALL_DIR)"
	@cp "$(MAIN_SCRIPT)" "$(INSTALL_DIR)/"
	@cp -r "$(LIB_DIR)" "$(INSTALL_DIR)/$(INSTALLED_LIB_DIR)"
	@chmod +x "$(INSTALL_DIR)/$(MAIN_SCRIPT)"
	@echo "installation complete!"

uninstall:
	@echo "uninstalling $(SCRIPT_NAME) from $(INSTALL_DIR)..."
	@rm -f "$(INSTALL_DIR)/$(SCRIPT_NAME)"
	@rm -rf "$(INSTALL_DIR)/$(INSTALLED_LIB_DIR)"
	@echo "uninstallation complete!"

clean:
	@echo "cleaning up temporary files..."
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@rm -rf /tmp/stash_test_* 2>/dev/null || true
	@echo "clean complete!"

check:
	@echo "running shellcheck on all scripts..."
	@shellcheck -e SC1091 "$(MAIN_SCRIPT)"
	@shellcheck -e SC2034 $(LIB_FILES)
	@shellcheck -e SC2317 "$(TEST_SCRIPT)"
	@echo "all checks passed!"

test:
	@echo "running test suite..."
	@if [ -f "$(TEST_SCRIPT)" ]; then \
		./$(TEST_SCRIPT) "./$(MAIN_SCRIPT)"; \
	else \
		echo "error: $(TEST_SCRIPT) not found"; \
		exit 1; \
	fi

show-config:
	@echo "configuration:"
	@echo "  INSTALL_DIR: $(INSTALL_DIR)"
	@echo "  SCRIPT_NAME: $(SCRIPT_NAME)"
	@echo "  MAIN_SCRIPT: $(MAIN_SCRIPT)"
	@echo "  LIB_FILES: $(LIB_FILES)"
	@echo "  INSTALLED_LIB_DIR: $(INSTALLED_LIB_DIR)"
	@echo "  TEST_SCRIPT: $(TEST_SCRIPT)" 