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
release: release/mtpx-$(version).tar.bz2

release/mtpx-$(version).tar.bz2: build
	mkdir -p release
	tar --create --bzip2 --file release/mtpx-$(version).tar.bz2 --directory .build/release mtpx

.PHONY: clean
clean:
	rm -rf release
