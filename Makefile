
TARGET = printf
PREF_OBJ = ./obj/
PREF_LST = ./lst/

SRC = $(wildcard *.asm)
OBJ = $(patsubst %.asm, $(PREF_OBJ)%.o, $(SRC))

all : $(TARGET)

$(TARGET) : $(OBJ)
	ld -o $(TARGET) $(OBJ) 

$(PREF_OBJ)%.o : %.asm
	nasm -f elf64 -ggdb -F dwarf -o $@ $<

clean :
	rm $(TARGET) $(PREF_OBJ)*.o $(PREF_LST)*lst