CC = gcc
CFLAGS = -DGL_GLEXT_PROTOTYPES
INCLUDES = -I./
LDFLAGS = -lSDL2 -lGL


all: renderer

renderer: maprender.c
	$(CC) $(CFLAGS) $(INCLUDES) -o map $^ $(LDFLAGS)
