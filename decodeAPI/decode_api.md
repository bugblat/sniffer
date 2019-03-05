# Decode API

Warning: This is an early version of the Decode API.

When the app starts it scans the *scripts* subdirectory,
looking for scripts/init.lua, which it then loads and calls.

Of course init.lua can then load additional scripts -
at the time of writing, init.lua contains these load commands:

    local defs          = require("usb_defs")
    local stdRequestMod = require("usb_std_request")
    local descriptorMod = require("usb_descriptor")

Routines within these scripts are then called when a row has
to be displayed on the screen.

For instance, the entry point when data packet has to be
displayed is this:

    function data_decode(params)
    --local handle = params["handle"]
      local parent = params["parent"]
      local pid    = params["pid"]
      local data   = params["data"]
    --local crc16  = params["crc16"]
      local crcOK  = params["crcOK"]

The commented out lines are for parameters that are not used
in this implementation.
For this example, the meaning of the pid, data, crc16, and crcOK
parameters will be obvious.
For the others:

- the **handle** parameter is the equivalent of *this*,
a handle on the current node in the rows list.

- the **parent** parameter can be used to get information on the transaction
of which the example data packet will be a part.

Further down in data_decode we see:

    local owner = getParent(parent)
    if owner and (owner["type"]=="transaction")
                              and (owner["subType"] == "SETUP") then
    ...

## Return Value

String returns from the various *x_decode* functions are used to fill in the
*Decode* pane of the display.
The return string is a series of sections separated by ";" characters.

Sections starting with `S` render as plain text.
For instance:

    "SSETUP transaction\n"

Sections starting with `T` render as tables.
For instance:

    "TStandard Request\n
     Value#Description\n
     0x80#bmRequestType D2H, Std., Device\n
     6#bmRequest (Get Descriptor)\n
     0x0100#wValue (Descriptor: Device/0)\n
     0#wIndex\n
     64#wLength\n"

The Table string has been split into lines for ease of reading,
correct usage does not have extra lines.

The two display types can be used together.
For instance:

    "SSETUP transaction\n;TStandard Request\nValue#Description\n...."

## Script Debugging

Scripts can be interactively debugged via the excellent Zerobrane
debugger (https://studio.zerobrane.com/).

To enable debugging, uncomment `require("mobdebug").start()` in init.lua.
