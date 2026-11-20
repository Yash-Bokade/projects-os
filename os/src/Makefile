CC      ?= gcc
CFLAGS  := -std=c11 -O2 -Wall -Wextra -s $(shell pkg-config --cflags gtk4)
LIBS    := $(shell pkg-config --libs gtk4)

BINARIES := projects-wizard projects-settings

all: $(BINARIES)

projects-wizard: projects-wizard.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

projects-settings: projects-settings.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

clean:
	rm -f $(BINARIES)

.PHONY: all clean
