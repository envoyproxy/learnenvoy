SHELL := /bin/bash
BUNDLE := bundle
THEME_DIR := $(shell bundle show agency-jekyll-theme)
VENDOR_DIR := .
JEKYLL := $(BUNDLE) exec jekyll

PROJECT_DEPS := Gemfile

.PHONY: all clean install update

all : serve

check:
	$(JEKYLL) doctor
	$(HTMLPROOF) --check-html \
		--http-status-ignore 999 \
		--internal-domains localhost:4000 \
		--assume-extension \
		_site

install: $(PROJECT_DEPS)
	$(BUNDLE) install --path vendor/bundler

update: $(PROJECT_DEPS)
	$(BUNDLE) update

include-vendor-deps:
	cp -r $(THEME_DIR)/vendor $(VENDOR_DIR)

build: install include-vendor-deps
	$(JEKYLL) build

serve: install include-vendor-deps
	JEKYLL_ENV=production $(JEKYLL) serve

clean:
	$(JEKYLL) clean
