/*
MIT License

Copyright (c) 2018 Scott Petersen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"

#include <unistd.h>
#include <dlfcn.h>

static int cola_dlopen(lua_State *L) {
  const char *path = luaL_checkstring(L, 1);
  int mode = (int)luaL_checkinteger(L, 2);
  void *handle = dlopen(path, mode);

  if(handle)
    lua_pushlightuserdata(L, handle);
  else
    lua_pushnil(L);
  return 1;
}

static int cola_dlclose(lua_State *L) {
  void *handle = lua_touserdata(L, 1);

  if(!handle)
    return luaL_error(L, "invalid handle");

  int result = dlclose(handle);

  lua_pushinteger(L, result);
  return 1;
}

static int cola_dlsym(lua_State *L) {
  void *handle = lua_touserdata(L, 1);

  if(!handle)
    return luaL_error(L, "invalid handle");

  const char *symbol = luaL_checkstring(L, 2);
  void *address = dlsym(handle, symbol);

  if(address)
    lua_pushlightuserdata(L, address);
  else
    lua_pushnil(L);
  return 1;
}

static int cola_dlerror(lua_State *L) {
  const char *error = dlerror();

  if(error)
    lua_pushstring(L, error);
  else
    lua_pushnil(L);
  return 1;
}

static int cola_getpid(lua_State *L) {
  lua_pushinteger(L, getpid());

  return 1;
}

static int cola_cclosure(lua_State *L) {
  void *address = lua_touserdata(L, 1);

  if(!address)
    return luaL_error(L, "invalid address");

  int upvalueCount = lua_gettop(L) - 1;

  if(upvalueCount < 0 || upvalueCount > 255)
    return luaL_error(L, "bad upvalue count");

  for(int i = 0; i < upvalueCount; i++)
    lua_pushvalue(L, 2+i);

  lua_pushcclosure(L, address, upvalueCount);
  return 1;
}

static luaL_Reg colalib[] = {
  {"dlopen", cola_dlopen},
  {"dlclose", cola_dlclose},
  {"dlsym", cola_dlsym},
  {"dlerror", cola_dlerror},
  {"getpid", cola_getpid},
  {"cclosure", cola_cclosure},
  {NULL, NULL}
};

LUALIB_API int luaopen_cola(lua_State *L) {
  luaL_newlib(L, colalib);

  lua_pushinteger(L, RTLD_LAZY);
  lua_setfield(L, -2, "RTLD_LAZY");
  lua_pushinteger(L, RTLD_NOW);
  lua_setfield(L, -2, "RTLD_NOW");
  lua_pushinteger(L, RTLD_GLOBAL);
  lua_setfield(L, -2, "RTLD_GLOBAL");
  lua_pushinteger(L, RTLD_LOCAL);
  lua_setfield(L, -2, "RTLD_LOCAL");
  lua_pushinteger(L, RTLD_NOLOAD);
  lua_setfield(L, -2, "RTLD_NOLOAD");
  lua_pushinteger(L, RTLD_NODELETE);
  lua_setfield(L, -2, "RTLD_NODELETE");

#if __APPLE__
  lua_pushboolean(L, 1);
  lua_setfield(L, -2, "__APPLE__");
#endif

#define STR_(X) #X
#define STR(X) STR_(X)
  lua_pushstring(L, STR(COLA_CC));
  lua_setfield(L, -2, "CC");
  lua_pushstring(L, STR(COLA_LUA_CFLAGS));
  lua_setfield(L, -2, "LUA_CFLAGS");

  return 1;
}

