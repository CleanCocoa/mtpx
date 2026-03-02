prefix ?= /usr/local
bindir = $(prefix)/bin

version := $(shell git describe --tags 2>/dev/null || echo dev)

.PHONY: build
build:
	swift build --configuration release

.PHONY: install
install: build
	install -d "$(bindir)"
	install ".build/release/mtpx" "$(bindir)"

.PHONY: uninstall
uninstall:
	rm -f "$(bindir)/mtpx"

.PHONY: release
release: release/mtpx-$(version).tar.gz

release/mtpx-$(version).tar.gz: build
	mkdir -p release
	tar czf release/mtpx-$(version).tar.gz -C .build/release mtpx

.PHONY: clean
clean:
	rm -rf release
