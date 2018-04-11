INSTALL_PATH?=/usr/local/bin
INSTALL_NAME?=swift-nest

.PHONY: debug

debug:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/SwiftNest $(INSTALL_PATH)/$(INSTALL_NAME)

uninstall:
	@[ -f $(INSTALL_PATH)/$(INSTALL_NAME) ] && rm $(INSTALL_PATH)/$(INSTALL_NAME) || true 
	@echo "Done"
