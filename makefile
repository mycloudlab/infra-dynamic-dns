all: build test

build: Dockerfile init.sh
	docker build --rm -t bind . --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy}

test:
	./test.sh
	