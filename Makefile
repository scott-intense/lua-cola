ifndef LUA_CFLAGS
  LUA_CFLAGS = $(shell pkg-config --cflags lua)
endif

ifeq ($(shell uname), Darwin)
  CFLAGS += -undefined dynamic_lookup
endif

ALL: cola-raw.so

cola-raw.so: cola-raw.c
	$(CC) $(LUA_CFLAGS) $(CFLAGS) -shared -fPIC -x c -DCOLA_CC="$(CC)" -DCOLA_LUA_CFLAGS="$(LUA_CFLAGS)" cola-raw.c -o cola-raw.so

clean:
	rm cola-raw.so
