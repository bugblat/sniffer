package.path  = './?.lua;./scripts/?.lua;'  -- could add .. package.path
package.cpath = './?.dll;./scripts/?.dll;'  -- could add .. package.cpath

--io.write( package.path .. '\n\n')
--io.write( package.cpath .. '\n\n')

--require("mobdebug").start()

local defs          = require("usb_defs")
local stdRequestMod = require("usb_std_request")
local descriptorMod = require("usb_descriptor")

local format = string.format  -- save a bit of typing :)

--============================================
function myAdd(a, b)
  return a+b
end

--============================================
function getParent(parent)
  if parent then return getNode(parent) else return nil end
end

--============================================
function reset_decode(params)
  local duration  = params["duration"]
--local idleTicks = params["idleTicks"]

  local dur, units = duration * 1000/12, "ns"
  if dur > 1000 then
    dur = dur/1000; units = "mus"
    if dur > 1000 then
      dur = dur/1000; units = "ms"
      if dur > 1000 then
        dur = dur/1000; units = "s"
      end
    end
  end

  local t = {}
  t[#t + 1] = "S"   -- string
  t[#t + 1] = format("A USB Reset for %d ticks ", duration)
  t[#t + 1] = format("(%.3f %s).\n\n", dur, units)
  t[#t + 1] = "The host signals a valid Reset by pulling both USB lines"
  t[#t + 1] = " (D+ and D-) low for at least 10ms."
  t[#t + 1] = " Short Resets are invalid and often occur when a device is"
  t[#t + 1] = " plugged in or powered up."
  return table.concat(t);
end

--============================================
function sof_decode(params)
--local handle = params["handle"]
--local parent = params["parent"]
--local frame  = params["frame"]
--local crc5   = params["crc5"]
  local crcOK  = params["crcOK"]

  local t = {}
  t[#t + 1] = "S"   -- string
  t[#t + 1] = "A single SOF (Start Of Frame) packet."
  if not crcOK then
    t[#t + 1] = "\n\nCRC is incorrect."
  end
  return table.concat(t);
end

--============================================
function token_decode(params)
--local handle = params["handle"]
--local parent = params["parent"]
  local pid    = params["pid"]
--local addr   = params["addr"]
--local endp   = params["endp"]
--local crc5   = params["crc5"]
  local crcOK  = params["crcOK"]

  local t = {}
  t[#t + 1] = "S"   -- string
  if     pid == defs.PID_SETUP then t[#t + 1] = "A SETUP"
  elseif pid == defs.PID_IN    then t[#t + 1] = "An IN"
  elseif pid == defs.PID_OUT   then t[#t + 1] = "An OUT"
  else                              t[#t + 1] = "An unrecognized"
  end
  t[#t + 1] = " token packet."
  if not crcOK then
    t[#t + 1] = "\n\nCRC is incorrect."
  end
  return table.concat(t);
end

--============================================
function data_decode(params)
--local handle = params["handle"]
  local parent = params["parent"]
  local pid    = params["pid"]
  local data   = params["data"]
--local crc16  = params["crc16"]
  local crcOK  = params["crcOK"]

  local t = {}
  t[#t + 1] = "S"   -- string
  if     pid == defs.PID_DATA0 then t[#t + 1] = "A DATA0"
  elseif pid == defs.PID_DATA1 then t[#t + 1] = "A DATA1"
  elseif pid == defs.PID_DATA2 then t[#t + 1] = "A DATA2"
  elseif pid == defs.PID_MDATA then t[#t + 1] = "An MDATA"
  else                              t[#t + 1] = "An unrecognized"
  end
  t[#t + 1] = " data packet"

  if     pid == defs.PID_DATA0 then t[#t + 1] = " (data toggle = 0)"
  elseif pid == defs.PID_DATA1 then t[#t + 1] = " (data toggle = 1)"
  end

  t[#t + 1] = ". The raw data in this packet is shown in the Data pane.";

  if not crcOK then
    t[#t + 1] = "\n\nCRC is incorrect."
  end

  local owner = getParent(parent)
  if owner and (owner["type"]=="transaction")
                              and (owner["subType"] == "SETUP") then
    t[#t + 1] = "\nThe packet carries the 8 data bytes for a SETUP transaction"
    t[#t + 1] =  " - click on the transaction to see the data bytes decoded."
    t[#t + 1] = ";"
    t[#t + 1] = stdRequestMod.stdRequest(data)
  end

  return table.concat(t);
end

--============================================
function handshake_decode(params)
--local handle = params["handle"]
--local parent = params["parent"]
  local pid    = params["pid"]

  local t = {}
  t[#t + 1] = "S"   -- string
  if     pid == defs.PID_ACK   then t[#t + 1] = "An ACK"
  elseif pid == defs.PID_NAK   then t[#t + 1] = "A NAK"
  elseif pid == defs.PID_STALL then t[#t + 1] = "A STALL"
  elseif pid == defs.PID_NYET  then t[#t + 1] = "A NYET"
  else                              t[#t + 1] = "An unrecognized"
  end
  t[#t + 1] = " handshake packet."

  return table.concat(t);
end

--============================================
local function transaxIsAck(transax)
  if transax and (transax.type == "transaction") then
    local children = transax["children"]
    for ix = 1, #children do
      local child = getNode(children[ix])
      if child and (child.type == "handshake") then
        return child.pid == defs.PID_ACK
      end
    end
  end
  return false
end

--============================================
local function transferGetTransax(transfer, subType)
  if transfer and (transfer.type == "transfer") then
    local children = transfer["children"]
    for ix = 1, #children do
      local child = getNode(children[ix])
      if child and (child.type == "transaction")
               and (child.subType == subType)
               and transaxIsAck(child) then
        return child
      end
    end
  end
  return nil
end

--============================================
local function transaxGetPacket(transax, packetType)
  if transax and (transax.type == "transaction") then
    local children = transax["children"]
    for ix = 1, #children do
      local child = getNode(children[ix])
      if child and (child.type == packetType) then
        return child
      end
    end
  end
  return nil
end

--============================================
function transaction_decode(params)
--local handle   = params["handle"  ]
  local parent   = params["parent"  ]
  local children = params["children"]
  local subType  = params["subType" ]

  local t = {}
  t[#t + 1] = "S"   -- string
  t[#t + 1] = subType .. " transaction\n"
  t[#t + 1] = ";"

  if transaxIsAck(params) then
    if subType == "SETUP" then
      for ix = 1, #children do
        local child = getNode(children[ix])
        if child and (child.type == 'data') then
          t[#t + 1] = stdRequestMod.stdRequest(child.data)
          break
        end
      end
    elseif subType == "IN" then
      local stringIndex = 0
      local setup = transferGetTransax(getParent(parent), "SETUP")
      local sdata = transaxGetPacket(setup, "data")
      if sdata and sdata.data and (#sdata.data == 8) then
        stringIndex = sdata.data[3]
      end
      local inData = transaxGetPacket(params, "data")
      if inData then
        t[#t + 1] = descriptorMod.descriptorStr(inData.data, stringIndex)
      end
    end
  end

  return table.concat(t)
end

--============================================
function transfer_decode(params)
--local handle   = params["handle"  ]
--local parent   = params["parent"  ]
--local children = params["children"]
  local subType  = params["subType" ]

  local t = {}
  t[#t + 1] = "S"   -- string
  t[#t + 1] = subType .. " transfer\n"
  t[#t + 1] = ";"

  if subType ~= "CONTROL" then
    return table.concat(t)
  end

  local stringIndex = 0
  local setupTransax = transferGetTransax(params, "SETUP")
  local setupDataPkt = transaxGetPacket(setupTransax, "data")
  local d2h = false
  if setupDataPkt and setupDataPkt.data and (#setupDataPkt.data == 8) then
    t[#t + 1] = stdRequestMod.stdRequest(setupDataPkt.data)
    t[#t + 1] = ";"
    d2h = bit32.btest(setupDataPkt.data[1], 0x80)
    stringIndex = setupDataPkt.data[3]
  end

  if d2h then
    local inTransax = transferGetTransax(params, "IN")
    local inDataPkt = transaxGetPacket(inTransax, "data")
    if inDataPkt then
      t[#t + 1] = descriptorMod.descriptorStr(inDataPkt.data, stringIndex)
      t[#t + 1] = ";"
    end
  end

  return table.concat(t)
end

-- EOF ---------------------------------------

--[[
local v = {0x80, 0x06, 0x00, 0x01, 0x00, 0x00, 0x40, 0x00}
local s = stdRequestMod.stdRequest(v)
print(s)

local v2 = {0x12, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x40,
            0x81, 0x07, 0x67, 0x55, 0x27, 0x01, 0x01, 0x02,
            0x03, 0x01}
local s2 = descriptorMod.descriptorStr(v2, 0)
print(s2)
--]]
