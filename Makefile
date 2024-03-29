all: shards prebuild build-static strip

shards:
	shards install --production
shards-devel:
	shards install
prebuild:
	mkdir -p bin
build: prebuild
	crystal build --release --no-debug -s -p -t src/crog.cr -o bin/crog
build-static:
	crystal build --release --static --no-debug -s -p -t src/crog.cr -o bin/crog
strip:
	strip bin/crog
run:
	crystal run src/crog.cr
test: shards-devel
	./bin/ameba
docker:
	docker compose up
