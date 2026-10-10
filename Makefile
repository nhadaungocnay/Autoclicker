.PHONY: all build install run clean

all: build

build:
	@chmod +x build.sh
	@./build.sh

install:
	@chmod +x install.sh
	@./install.sh

run: build
	@open "build/Auto Clicker.app"

clean:
	@rm -rf build .cache Resources/AppIcon.iconset
