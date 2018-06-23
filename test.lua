local cola = require'cola'

local upv = "updog"

local cfunc = cola.cfunc(function(s)
  return [[

// header
#include "lua.h"
#include <stdio.h>

static int n = 0;

]], [[

// implementation
get_upv;
get_s;
printf("c says %s %s\n", lua_tostring(L, -1), lua_tostring(L, -2));
lua_pop(L, 2);
lua_pushstring(L, "up dog");
set_upv;
lua_pushinteger(L, n++);
return 1;

]], upv
end)

print(cfunc("what's"))
print(cfunc("what is"))
