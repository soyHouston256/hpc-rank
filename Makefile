# Makefile simple para compilar el programa MPI

CXX=mpicxx
CXXFLAGS=-O3 -std=c++17
TARGET=rank
SRC=main.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $^

clean:
	rm -f $(TARGET)

.PHONY: all clean
