CC      ?= $(CROSS_COMPILE)gcc
OBJS     = main.o
CFLAGS  += -Wall -I../ta/include -I$(TEEC_EXPORT)/include
LDADD   += -lteec -L$(TEEC_EXPORT)/lib
BINARY   = optee_selftest

.PHONY: all clean
all: $(BINARY)
$(BINARY): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $< $(LDADD)
clean:
	rm -f $(OBJS) $(BINARY)
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@
