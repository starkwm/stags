build:
	@swift build

format:
	@swift format format -r -i Sources Tests Package.swift

lint:
	@swift format lint --strict -r Sources Tests Package.swift

test:
	@swift test

.DEFAULT_GOAL := build
.PHONY: build format lint test
