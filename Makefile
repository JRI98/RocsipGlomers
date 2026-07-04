.PHONY: challenge1 challenge2 challenge3a challenge3b # challenge3c challenge3d challenge3e challenge4 challenge5a challenge5b challenge5c challenge6a challenge6b challenge6c

mkdir_build:
	mkdir -p build

# https://fly.io/dist-sys/1/
challenge1: mkdir_build
	roc build --output=build/challenge1 challenge1.roc --opt=speed
	./maelstrom/maelstrom test -w echo --bin build/challenge1 --node-count 1 --time-limit 10

# https://fly.io/dist-sys/2/
challenge2: mkdir_build
	roc build --output=build/challenge2 challenge2.roc --opt=speed
	./maelstrom/maelstrom test -w unique-ids --bin build/challenge2 --time-limit 30 --rate 1000 --node-count 3 --availability total --nemesis partition

# https://fly.io/dist-sys/3a/
challenge3a: mkdir_build
	roc build --output=build/challenge3a challenge3a.roc --opt=speed
	./maelstrom/maelstrom test -w broadcast --bin build/challenge3a --node-count 1 --time-limit 20 --rate 10

# https://fly.io/dist-sys/3b/
challenge3b: mkdir_build
	roc build --output=build/challenge3b challenge3b.roc --opt=speed
	./maelstrom/maelstrom test -w broadcast --bin build/challenge3b --node-count 5 --time-limit 20 --rate 10

# https://fly.io/dist-sys/3c/
# challenge3c: mkdir_build
# 	roc build --output=build/challenge3c challenge3c.roc --opt=speed
#	./maelstrom/maelstrom test -w broadcast --bin build/challenge3c --node-count 5 --time-limit 20 --rate 10 --nemesis partition

# https://fly.io/dist-sys/3d/
# challenge3d: mkdir_build
# 	roc build --output=build/challenge3d challenge3d.roc --opt=speed
#	./maelstrom/maelstrom test -w broadcast --bin build/challenge3d --node-count 25 --time-limit 20 --rate 100 --latency 100

# https://fly.io/dist-sys/3e/
# challenge3e: mkdir_build
# 	roc build --output=build/challenge3e challenge3e.roc --opt=speed
#	./maelstrom/maelstrom test -w broadcast --bin build/challenge3e --node-count 25 --time-limit 20 --rate 100 --latency 100

# https://fly.io/dist-sys/4/
# challenge4: mkdir_build
# 	roc build --output=build/challenge4 challenge4.roc --opt=speed
#	./maelstrom/maelstrom test -w g-counter --bin build/challenge4 --node-count 3 --rate 100 --time-limit 20 --nemesis partition

# https://fly.io/dist-sys/5a/
# challenge5a: mkdir_build
# 	roc build --output=build/challenge5a challenge5a.roc --opt=speed
#	./maelstrom/maelstrom test -w kafka --bin build/challenge5a --node-count 1 --concurrency 2n --time-limit 20 --rate 1000

# https://fly.io/dist-sys/5b/
# challenge5b: mkdir_build
# 	roc build --output=build/challenge5b challenge5b.roc --opt=speed
#	./maelstrom/maelstrom test -w kafka --bin build/challenge5b --node-count 2 --concurrency 2n --time-limit 20 --rate 1000

# https://fly.io/dist-sys/5c/
# challenge5c: mkdir_build
# 	roc build --output=build/challenge5c challenge5c.roc --opt=speed
#	./maelstrom/maelstrom test -w kafka --bin build/challenge5c --node-count 2 --concurrency 2n --time-limit 20 --rate 1000

# https://fly.io/dist-sys/6a/
# challenge6a: mkdir_build
# 	roc build --output=build/challenge6a challenge6a.roc --opt=speed
#	./maelstrom/maelstrom test -w txn-rw-register --bin build/challenge6a --node-count 1 --time-limit 20 --rate 1000 --concurrency 2n --consistency-models read-uncommitted --availability total

# https://fly.io/dist-sys/6b/
# challenge6b: mkdir_build
# 	roc build --output=build/challenge6b challenge6b.roc --opt=speed
#	./maelstrom/maelstrom test -w txn-rw-register --bin build/challenge6b --node-count 2 --concurrency 2n --time-limit 20 --rate 1000 --consistency-models read-uncommitted
#   ./maelstrom/maelstrom test -w txn-rw-register --bin build/challenge6b --node-count 2 --concurrency 2n --time-limit 20 --rate 1000 --consistency-models read-uncommitted --availability total --nemesis partition

# https://fly.io/dist-sys/6c/
# challenge6c: mkdir_build
# 	roc build --output=build/challenge6c challenge6c.roc --opt=speed
#	./maelstrom/maelstrom test -w txn-rw-register --bin build/challenge6c --node-count 2 --concurrency 2n --time-limit 20 --rate 1000 --consistency-models read-committed --availability total –-nemesis partition

serve:
	./maelstrom/maelstrom serve
