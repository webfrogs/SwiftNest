INSTALL_PATH?=/usr/local/bin

.PHONY: debug

debug:
	swift build

release:
	swift build -c release

install: release
	cp .build/release/SwiftNest $(INSTALL_PATH)

uninstall:
	@[ -f $(INSTALL_PATH)/SwiftNest ] && rm $(INSTALL_PATH)/SwiftNest || true 
	@echo "Done"
