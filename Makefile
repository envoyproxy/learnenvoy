# Copyright 2018 Turbine Labs, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SHELL := /bin/bash
BUNDLE := bundle
VENDOR_DIR := .
JEKYLL := $(BUNDLE) exec jekyll

PROJECT_DEPS := Gemfile

.PHONY: \
	all \
	build \
	check \
	clean \
	include-vendor-deps \
	install \
	update \
	serve \
	test

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
	cp -r $(shell bundle show agency-jekyll-theme)/vendor $(VENDOR_DIR)

build: install include-vendor-deps
	$(JEKYLL) build

serve: install include-vendor-deps
	JEKYLL_ENV=production $(JEKYLL) serve

test: build
	$(BUNDLE) exec htmlproofer ./_site --check-html --disable-external

clean:
	$(JEKYLL) clean
	$(BUNDLE) clean
	rm -rf vendor
