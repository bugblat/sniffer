
local defs = require("usb_defs")

local format = string.format

local function hex4(v) return format("0x%04x", v) end

--============================================
local function requestTypeStr(v)
  local dirStr
  if bit32.btest(v, 0x80) then dirStr = "D2H" else dirStr = "H2D" end

  local typStr
  local typ = bit32.band(3, bit32.rshift(v, 5))
  if     typ == 0 then typStr = "Std."
  elseif typ == 1 then typStr = "Class"
  elseif typ == 2 then typStr = "Vendor"
  else                 typStr = "Reserved"
  end

  local recipStr
  local recip = bit32.band(31, v)
  if     recip == 0 then recipStr = "Device"
  elseif recip == 1 then recipStr = "Interface"
  elseif recip == 2 then recipStr = "Endpoint"
  elseif recip == 3 then recipStr = "Other"
  else                   recipStr = "Reserved"
  end

  return format("%s, %s, %s\n", dirStr, typStr, recipStr)
end

--============================================
local function stdDefaultRequestStr(d)
  local t = {}
  t[#t + 1] = format("0x%04x#wValue\n",  d[3] + 256*d[4])
  t[#t + 1] = format("%d#wIndex\n",      d[5] + 256*d[6])
  t[#t + 1] = format("%d#wLength\n",     d[7] + 256*d[8])
  return table.concat(t);
end

--============================================
local function stdDeviceRequestStr(d)
  local req = d[2]
  local ok = (req == defs.GET_STATUS) or
             (req == defs.CLEAR_FEATURE) or
             (req == defs.SET_FEATURE) or
             (req == defs.SET_ADDRESS) or
             (req == defs.GET_DESCRIPTOR) or
             (req == defs.SET_DESCRIPTOR) or
             (req == defs.GET_CONFIG) or
             (req == defs.SET_CONFIG)
  if not ok then return stdDefaultRequestStr(d) end

  local t = {}

  -- wValue field
  local val = d[3] + 256*d[4]
  local valStr = hex4(val)
  if (req == defs.CLEAR_FEATURE) or (req == defs.SET_FEATURE) then
    t[#t + 1] = valStr .. format("#wValue (Feature: %d)\n", val)
  elseif req == defs.SET_ADDRESS then
    t[#t + 1] = valStr .. format("#wValue (Address: %d)\n", val)
  elseif (req == defs.GET_DESCRIPTOR) or (req == defs.SET_DESCRIPTOR) then
    local s = valStr .. format("#wValue (Descriptor: %s/%d)\n", defs.descriptorName(d[4]), d[3])
    t[#t + 1] = s
  elseif req == defs.SET_CONFIG then
    t[#t + 1] = valStr .. format("#wValue (Config: %d)\n", val)
  else
    t[#t + 1] = valStr .. "#wValue\n"
  end

  -- wIndex field
  local ix = d[5] + 256*d[6]
  if (ix > 0) and ((req == defs.GET_DESCRIPTOR) or (req == defs.SET_DESCRIPTOR)) then
    t[#t + 1] = format("0x%04x#wIndex (Language: 0x%04x)\n", ix, ix)
  else
    t[#t + 1] = tostring(ix) .. "#wIndex\n"
  end

  -- wLength field
  local len = d[7] + 256*d[8]
  t[#t + 1] = tostring(len) .. "#wLength\n"

  return table.concat(t);
end

--============================================
local function stdInterfaceRequestStr(d)
  local req = d[2]
  local ok = (req == defs.GET_STATUS) or
             (req == defs.CLEAR_FEATURE) or
             (req == defs.SET_FEATURE) or
             (req == defs.GET_INTERFACE) or
             (req == defs.SET_INTERFACE)
  if not ok then return stdDefaultRequestStr(d) end

  local t = {}

  -- wValue field
  local val = d[3] + 256*d[4]
  if (req == defs.SET_FEATURE) or (req == defs.CLEAR_FEATURE) then
    t[#t + 1] = format("0x%04x#wValue (Feature: %d)\n", val, val)
  elseif req == defs.SET_INTERFACE then
    t[#t + 1] = format("0x%04x#wValue (Alt. Setting: %d)\n", val, val)
  else
    t[#t + 1] = format("0x%04x#wValue\n", val)
  end

  -- wIndex field
  local ix = d[5] + 256*d[6]
  t[#t + 1] = format("%d#wIndex (Interface: %d)\n", ix, ix)

  -- wLength field
  local len = d[7] + 256*d[8]
  t[#t + 1] = format("%d#wLength\n", len)

  return table.concat(t);
end

--============================================
local function stdEndpointRequestStr(d)
  local req = d[2]
  local ok = (req == defs.GET_STATUS) or
             (req == defs.CLEAR_FEATURE) or
             (req == defs.SET_FEATURE) or
             (req == defs.SYNC_FRAME)
  if not ok then return stdDefaultRequestStr(d) end

  local t = {}

  -- wValue field
  local val = d[3] + 256*d[4]
  if (req == defs.SET_FEATURE) or (req == defs.CLEAR_FEATURE) then
    if val == 0 then
      t[#t + 1] = "0#wValue (Feature: 0)\n"
    else
      t[#t + 1] = format("0x%04x#wValue (Feature: %d)\n", val, val)
    end
  else
    t[#t + 1] = hex4(val) .. "#wValue\n"
  end

  -- wIndex field
  local ix  = d[5] + 256*d[6]
  t[#t + 1] = format("0x%02x#wIndex (Endpoint 0x%02x)\n", ix, ix)

  -- wLength field
  local len = d[7] + 256*d[8]
  t[#t + 1] = format("%d#wLength\n", len)

  return table.concat(t);
end

--============================================
local usb_std_request = {

  stdRequest = function(d)
    if #d ~= 8 then
      return format(
        "SStandard Request data must be 8 bytes long (%d bytes detected)", #d)
    end

    local t = {}
    t[#t + 1] = "T"   -- table
    t[#t + 1] = "Standard Request\n"
    t[#t + 1] = "Value#Description\n"

    t[#t + 1] = format("0x%02x#bmRequestType %s",
                                  d[1], requestTypeStr(d[1]))
    t[#t + 1] = format("%d#bmRequest (%s)\n",
                                  d[2], defs.stdRequestName(d[2]))

    local typ = bit32.band(31, d[1])
    if     typ == 0 then t[#t + 1] = stdDeviceRequestStr(d)
    elseif typ == 1 then t[#t + 1] = stdInterfaceRequestStr(d)
    elseif typ == 2 then t[#t + 1] = stdEndpointRequestStr(d)
    else                 t[#t + 1] = stdDefaultRequestStr(d)
    end

    return table.concat(t);
  end

  }

return usb_std_request

-- EOF ---------------------------------------
