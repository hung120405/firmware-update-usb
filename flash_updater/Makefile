# Makefile for flash_updater
#
# Compile: make
# Clean: make clean
# Install: make install (requires root, installs to /usr/local/bin)

CC = gcc
CFLAGS = -Wall -Wextra -O2 -std=c99
LDFLAGS = 
TARGET = flash_updater
SOURCE = flash_updater.c
INSTALL_DIR = /usr/local/bin

# Default target
all: $(TARGET)

# Build target
$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE) $(LDFLAGS)
	@echo "Build successful: $(TARGET)"

# Clean build artifacts
clean:
	rm -f $(TARGET)
	@echo "Cleaned build artifacts"

# Install to system (requires root)
install: $(TARGET)
	install -m 755 $(TARGET) $(INSTALL_DIR)/
	@echo "Installed $(TARGET) to $(INSTALL_DIR)"

# Uninstall from system (requires root)
uninstall:
	rm -f $(INSTALL_DIR)/$(TARGET)
	@echo "Uninstalled $(TARGET) from $(INSTALL_DIR)"

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: $(TARGET)

# Help
help:
	@echo "Available targets:"
	@echo "  make          - Build flash_updater"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make install  - Install to $(INSTALL_DIR) (requires root)"
	@echo "  make uninstall - Remove from $(INSTALL_DIR) (requires root)"
	@echo "  make debug    - Build with debug symbols"
	@echo "  make help     - Show this help message"

.PHONY: all clean install uninstall debug help

# Test adding a comment for git history