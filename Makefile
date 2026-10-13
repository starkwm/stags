VERSION_TMPL=Sources/Stags/Version.swift.tmpl
VERSION_FILE=Sources/Stags/Version.swift

build:
	@swift build

format:
	@swift format format -r -i Sources Tests Package.swift

lint:
	@swift format lint --strict -r Sources Tests Package.swift

test:
	@swift test

bump_version:
	@test -n "$(NEW_VERSION)" || (echo 'Set NEW_VERSION' >&2; exit 1)
	@sed 's/__VERSION__/$(NEW_VERSION)/g' $(VERSION_TMPL) > $(VERSION_FILE)

.DEFAULT_GOAL := build
.PHONY: build format lint test bump_version
