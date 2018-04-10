all: build test

build: Dockerfile init.sh
	docker build --rm -t mycloudlab/infra-dynamic-dns  . --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy}

test:
	./test.sh
	