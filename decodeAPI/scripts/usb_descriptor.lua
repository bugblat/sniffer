
local defs = require("usb_defs")

local format = string.format

local function hex2(v) return format("0x%02x", v) end
local function hex4(v) return format("0x%04x", v) end

--============================================
local function errorDescStr(d, ix)
  local t = {}
  t[#t + 1] = "S"
  t[#t + 1] = format("Undeciphered Descriptor (length %d/type %d) at Offset %d\n",
                            d[ix], d[ix+1], ix-1);
  t[#t + 1] = ";"
  return table.concat(t);
end

--============================================
local function descStrHeader(d, ix)
  local t = {}
  if ix >= #d then return "" end
  t[#t + 1] = "T"
  t[#t + 1] = defs.descriptorName(d[ix+1]) .. " Descriptor\n"
  t[#t + 1] = "Value#Description\n"
  t[#t + 1] = format("%d#bLength\n", d[ix])
  t[#t + 1] = format("%d#bDescriptorType\n", d[ix+1])
  return table.concat(t);
end

--============================================
local function tabTail(t)
  t[#t + 1] = ";"
  return table.concat(t);
end

--============================================
local function deviceDescStr(d, ix)
  local t = {}
  t[#t + 1] = descStrHeader(d, ix)
  local pos = ix+2;

    if (pos+1) > #d then return tabTail(t) end
    local v   = d[pos] + 256 * d[pos+1]
  t[#t + 1] = hex4(v)          .. "#bcdUSB\n";            pos = pos + 2
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bDeviceClass\n";      pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bDeviceSubClass\n";   pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bDeviceProtocol\n";   pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bMaxPacketSize0\n";   pos = pos + 1
    if (pos+1) > #d then return tabTail(t) end
    v = d[pos] + 256 * d[pos+1]
  t[#t + 1] = hex4(v)          .. "#idVendor\n";          pos = pos + 2
    if (pos+1) > #d then return tabTail(t) end
    v = d[pos] + 256 * d[pos+1]
  t[#t + 1] = hex4(v)          .. "#idProduct\n";         pos = pos + 2
    if (pos+1) > #d then return tabTail(t) end
    v = d[pos] + 256 * d[pos+1]
  t[#t + 1] = hex4(v)          .. "#bcdDevice\n";         pos = pos + 2
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#iManufacturer\n";     pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#iProduct\n";          pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#iSerialNumber\n";     pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bNumConfigurations";

  return tabTail(t);
end

--============================================
local function configDescStr(d, ix)
  local t = {}
  t[#t + 1] = descStrHeader(d, ix)
  local pos = ix+2;

    if (pos+1) > #d then return tabTail(t) end
    local v   = d[pos] + 256 * d[pos+1]
  t[#t + 1] = tostring(v)      .. "#wTotalLength\n";      pos = pos + 2
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bNumInterfaces\n";    pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#iConfigurationValue\n";pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#iConfiguration\n";    pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = hex2(d[pos])     .. "#bmAttributes\n";      pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bMaxPower\n";

  return tabTail(t)
end

--============================================
local function stringDescStr(d, ix, stringIndex)
  local t = {}
  t[#t + 1] = descStrHeader(d, ix)
  local pos = ix+2;

  if stringIndex == 0 then              -- list supported languages
    while pos < #d do
      local v   = d[pos] + 256 * d[pos+1]
      t[#t + 1] = hex4(v) .. "#wLANGID\n";
      pos = pos + 2
    end
  else                                  -- get Unicode string
    local nChars = 0
    while pos < #d do
      local v = d[pos] + 256 * d[pos+1] -- not good for complex Unicode
      t[#t + 1] = string.char(v)
      pos = pos + 2
      nChars = nChars + 1
    end
    if nChars > 0 then t[#t + 1] = "#bString (also see Raw Data)\n" end
  end

  return tabTail(t)
end

--============================================
local function interfaceDescStr(d, ix)
  local t = {}
  t[#t + 1] = descStrHeader(d, ix)
  local pos = ix+2;

    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bInterfaceNumber\n";    pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bAlternateSetting\n";   pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bNumEndpoints\n";       pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bInterfaceClass\n";     pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bInterfaceSubClass\n";  pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = hex2(d[pos])     .. "#bInterfaceProtocol\n";  pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#iInterface\n";

  return tabTail(t)
end

--============================================
local function endpointDescStr(d, ix)
  local t = {}
  t[#t + 1] = descStrHeader(d, ix)
  local pos = ix+2;

    if pos > #d then return tabTail(t) end
  t[#t + 1] = hex2(d[pos])     .. "#bEndpointAddress\n";    pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = hex2(d[pos])     .. "#bmAttributes\n";        pos = pos + 1
    if (pos+1) > #d then return tabTail(t) end
    local v = d[pos] + 256 * d[pos+1]
  t[#t + 1] = tostring(v)      .. "#wMaxPacketSize\n";      pos = pos + 2
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bInterval\n";

  return tabTail(t)
end

--============================================
local function deviceQualifDescStr(d, ix)
  local t = {}
  t[#t + 1] = descStrHeader(d, ix)
  local pos = ix+2;

    if (pos+1) > #d then return tabTail(t) end
    local v   = d[pos] + 256 * d[pos+1]
  t[#t + 1] = hex4(v)          .. "#bcdUSB\n";              pos = pos + 2
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bDeviceClass\n";        pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bDeviceSubClass\n";     pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bDeviceProtocol\n";     pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bMaxPacketSize0\n";     pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bNumConfigurations\n";  pos = pos + 1
    if pos > #d then return tabTail(t) end
  t[#t + 1] = tostring(d[pos]) .. "#bReserved\n";

  return tabTail(t)
end

--============================================
local usb_descriptor = {

  descriptorStr = function(d, stringIndex)
    local t = {}
    local ix = 1
    while ix < #d do
      local len = d[ix]
      local typ = d[ix+1]
      if (len < 2) or (typ > defs.MAX_KNOWN_DESCRIPTOR) then  -- something wacky here
        break
      end
      if     typ == defs.DEVICE_DESC    then t[#t + 1] = deviceDescStr(d, ix)
      elseif typ == defs.CFG_DESC       then t[#t + 1] = configDescStr(d, ix)
      elseif typ == defs.STRING_DESC    then t[#t + 1] = stringDescStr(d, ix, stringIndex)
      elseif typ == defs.INTERFACE_DESC then t[#t + 1] = interfaceDescStr(d, ix)
      elseif typ == defs.ENDPOINT_DESC  then t[#t + 1] = endpointDescStr(d, ix)
      elseif typ == defs.DEV_QUAL_DESC  then t[#t + 1] = deviceQualifDescStr(d, ix)
      else                                   t[#t + 1] = errorDescStr(d, ix)
      end
      ix = ix + len
    end

    return table.concat(t);
  end

  }

return usb_descriptor

-- EOF ---------------------------------------
