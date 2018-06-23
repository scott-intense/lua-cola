--[[
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
--]]

local cola = require 'cola-raw'

-- return a string uniquely capturing closures arg names/order and
-- upvalue names/order
local function closureSig(closure)
  local i
  local sig = {}

  i = 1
  while true do
    local n = debug.getupvalue(closure, i)

    if not n then break end

    sig[#sig + 1] = #n
    sig[#sig + 1] = ':'
    sig[#sig + 1] = n
    i = i + 1
  end

  sig[#sig + 1] = '/'

  i = 1
  while true do
    local n = debug.getlocal(closure, i)

    if not n then break end

    sig[#sig + 1] = #n
    sig[#sig + 1] = ':'
    sig[#sig + 1] = n
    i = i + 1
  end

  return table.concat(sig)
end

-- 4 level table indexed by cmd, chead, cimpl, closureSig
local cache = {}

local function cacheGet(cmd, chead, cimpl, clsig)
  local forCmd = cache[cmd]
  local forHead = forCmd and forCmd[chead]
  local forImpl = forHead and forHead[cimpl]

  return forImpl and forImpl[clsig]
end

local function cachePut(cmd, chead, cimpl, clsig, cfunc)
  local forCmd = cache[cmd]

  if not forCmd then
    forCmd = {}
    cache[cmd] = forCmd
  end

  local forHead = forCmd[chead]

  if not forHead then
    forHead = {}
    forCmd[chead] = forHead
  end

  local forImpl = forHead[cimpl]

  if not forImpl then
    forImpl = {}
    forHead[cimpl] = forImpl
  end

  forImpl[clsig] = cfunc
end

local soTmp = os.getenv("TMPDIR") or os.getenv("TMP") or os.getenv("TEMP") or os.getenv("TEMPDIR") or "/tmp"
local soPre = soTmp:gsub('/$', '') .. '/lua.cola.cfunc.' .. cola.getpid() .. '.'
local soId = 1

-- get a temp path for writing a new .so
local function nextSoPath()
  local result = soPre .. soId .. '.so'

  soId = soId + 1
  return result
end

-- open a pipe to the compiler
-- return dlopen-ed so
function cola.copen(cmd)
  local soPath = nextSoPath()
  local pipe = io.popen(cmd .. ' ' .. soPath, 'w')
  local result = {}

  function result:write(s)
    pipe:write(s)
  end
  function result:close(dlopenFlags)
    pipe:close()

    -- open the .so we just created
    local handle = cola.dlopen(soPath, dlopenFlags)

    -- safe to unlink the file (handle dl will reference it if load succeeded)
    os.remove(soPath)

    return handle
  end
  return result
end

-- create a new function given a command, headers, implementation, and closure function (that
-- captures argument names/order and upvalue names/order)
local function cfuncCreate(cmd, chead, cimpl, closure)
  local pipe = cola.copen(cmd)

  pipe:write('#line 100000\n') -- some reference for compile errors in headers
  pipe:write(chead)
  pipe:write('\n#line 200000\n')

  local i

  -- build macros for upvalue access
  i = 1
  while true do
    local n = debug.getupvalue(closure, i)

    if not n then break end
    pipe:write('#define get_' .. n .. ' do { lua_getupvalue(L, lua_upvalueindex(1), ' .. i .. '); } while(0)\n')
    pipe:write('#define set_' .. n .. ' do { lua_setupvalue(L, lua_upvalueindex(1), ' .. i .. '); } while(0)\n')
    i = i + 1
  end

  -- build macros for argument access
  i = 1
  while true do
    local n = debug.getlocal(closure, i)

    if not n then break end
    pipe:write('#define I_' .. n .. ' ' .. i .. '\n')
    pipe:write('#define get_' .. n .. ' do { lua_pushvalue(L, I_' .. n .. '); } while(0)\n')
    i = i + 1
  end

  -- function def w/ #line 1 for compile error reference
  pipe:write('\nLUALIB_API int cfunc(lua_State *L) {\n#line 1\n')
  pipe:write(cimpl)
  pipe:write('\n}\n')

  local handle = pipe:close(cola.RTLD_NOW|cola.RTLD_LOCAL)

  -- return false instead of nil so it will be cached (as failure)
  if not handle then return false end

  -- pull out our function
  local addr = cola.dlsym(handle, 'cfunc')

  if not addr then return false end

  -- build the closure from the c function
  return cola.cclosure(addr, closure)
end

-- given a closure that:
-- a) captures named arguments
-- b) captures upvalues
-- c) returns c headers, implementation when executed
-- build a new lua closure from the c headers and impl!
-- optionally provide the compilation command
function cola.cfunc(closure, cccmd)
  cccmd = cccmd or cola.cccmd or table.concat({ cola.cc, cola.socflags, cola.cflags, cola.copt, cola.cpipe, cola.coutput }, ' ')

  local chead, cimpl = closure()
  local clsig = closureSig(closure)
  local cf = cacheGet(cccmd, chead, cimpl, clsig)

  if cf == nil then
    cf = cfuncCreate(cccmd, chead, cimpl, closure)
    cachePut(cccmd, chead, cimpl, clsig, cf)
  end

  return cf
end

cola.cc = cola.CC
cola.socflags = '-shared -fPIC' .. (cola.__APPLE__ and ' -undefined dynamic_lookup' or '')
cola.cflags = cola.LUA_CFLAGS
cola.copt = '-O2'
cola.cpipe = '-x c -'
cola.coutput = '-o'

return cola
