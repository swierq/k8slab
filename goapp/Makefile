.PHONY: build test clean fmt

default: clean test build

build:
	CGO_ENABLED=0 go build -o bin/goapp cmd/main.go	

fmt:
	find . -name \*.go -print0 | xargs -0 -I{} go fmt {}

test:
	go test ./... -coverprofile cover.out -v 2>&1
	go tool cover -func cover.out 2>&1

clean:
	rm -rf bin/goapp

clean-test-cache:
	go clean -testcache

default: clean test build