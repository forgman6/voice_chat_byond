
CC = g++

CFLAGS = -m32 -fPIC -std=c++20 -I../byondapi

LDFLAGS =  -m32 -shared

TARGET = pipes.so

SRC = so_main.cpp

OBJ = $(SRC:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJ)

	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.cpp

	$(CC) $(CFLAGS) -c -o $@ $<

clean:

	rm -f *.o $(TARGET)
