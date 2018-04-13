INSTALL_PATH?=/usr/local/bin
INSTALL_NAME?=swift-nest
DEBUG?=0

all : build
.PHONY: all build install uninstall

build:
ifeq ($(DEBUG),0)
	swift build -c release -Xswiftc -static-stdlib
else
	swift build -Xswiftc "-D" -Xswiftc "DEBUG"
endif

install: build
ifeq ($(DEBUG),0)
	cp .build/release/SwiftNest $(INSTALL_PATH)/$(INSTALL_NAME)
else
	cp .build/debug/SwiftNest $(INSTALL_PATH)/$(INSTALL_NAME)
endif

uninstall:
	@[ -f $(INSTALL_PATH)/$(INSTALL_NAME) ] && rm $(INSTALL_PATH)/$(INSTALL_NAME) || true 
	@echo "Done"
