# Capture API

The components of the *Capture API* interface are:

  * the API library: *libminisniff.dll* or *libminisniff.so*
  * API documentation: *libminisniff.h*.
    API function descriptions are included with the C declarations.
  * minisniff.py, an example Python program that uses the API.

## Example Program

The essence of minisniff.py is shown here:

    buff = create_string_buffer(256)
    rv = mini.version(buff, sizeof(buff))
    print('Using library version: %s\n' % repr(buff.value))

    # beeps from your computer as drivers are loaded :)
    sniffer = c_int(mini.sniffInit())

    # loop while waiting for the OS to do its thing
    snifferStatus = E_SNIFFER_NOT_FOUND
    for i in range(0, 6):
      stat = c_int(mini.getHardwareStatus(sniffer))
      snifferStatus = stat.value
      if snifferStatus != E_SNIFFER_NOT_FOUND:
        break
      time.sleep(1)

    if snifferStatus != INIT_OK:        # probably timed out
      print('problem !!!!')
      mini.sniffEnd(sniffer)
      return

    rv = mini.getSerial(sniffer, buff, sizeof(buff))
    print('Serial string: %s\n' % repr(buff.value))

    # here when the sniffer is found OK
    # disconnect
    mini.setConnect(sniffer, 0)
    needed = 16 * 1024                  # easily covers setup
    mini.setNeeded(sniffer, needed)
    # reconnect and run
    mini.setRun(sniffer, 1)

    # loop until finished
    while True:
      done = mini.getDone(sniffer)
      cc   = mini.getCaptureCount(sniffer)
      dc   = mini.getDecodedCount(sniffer)
      print(cc, '/', dc, sep='')
      if done:
        break
      time.sleep(2)

    # get packet data plus decoded transactions, etc.
    lineCount = mini.getPacketDataRowCount(sniffer)
    print(lineCount, 'decoded rows')

    ofile = open('pyoutput.txt', 'w')
    # a huge buffer..
    rowBuf = create_string_buffer(10 * 1024)

    for i in range(0, lineCount):
      mini.getPacketDataRow(sniffer, i, rowBuf, sizeof(rowBuf))
      # decoded rows are terminated with \n\0
      # now you can split the data, analyze it any way you want...
      # this program just writes out a file
      ofile.write(rowBuf.value)

    ofile.close()

    mini.sniffEnd(sniffer)

#### Remarks:

- initializing the miniSniffer (sniffInit) involves finding and opening the miniSniffer board
- when a capture is started (setRun) a flag is set in a separate thread which updates its
progress via the getDone() flag.
The program must sleep until this signals *true*.
- final output is a set of text rows, as documented below.

## API

The API is defined in minisniff.h.

Boolean values for true and false vary between languages.
Regular integers are used for booleans:

    0: false
    not 0: true

sniffHandle is a C void* value.
In other languages this could be represented as an integer,
unsigned if available.

Strings are C char* values,
null-terminated sequences of ASCII characters.

#### Version

##### unsigned version(char *outStr, unsigned outLen);

If outLen is large enough, copies the version string to the outStr buffer.
Otherwise, outStr is unchanged.

returns: The length of the version string including a terminating null.

example version string: `libminisniff DLL/SO,Feb 27 2019,18:42:03`

#### Initialize and terminate

##### sniffHandle sniffInit();

returns: a handle that can be used to query and control the sniffer hardware
and software.
It also starts a background thread that will be attempting to connect to
the sniffer hardware, but it does not mean that the software has succeeded
(or failed) in opening the hardware.
See also `getHardwareStatus()`

##### void sniffEnd(sniffHandle h);

Closes the connection to the sniffer board.
Pass-through connected/disconnected status is not changed.

##### unsigned getSerial(sniffHandle h, char *outStr, unsigned outLen);

If outLen is large enough, copies the serial string to the outStr buffer.
Otherwise, outStr is unchanged.

returns: The length of the serial string including a terminating null.

example serial string: `BU2ABCDEFG`

##### int getHardwareStatus(sniffHandle h);

`sniffInit()` starts a background process that repeatedly attempts
to connect to the sniffer hardware.
At the time of writing, a failed connection is retried every second.

This function queries the success or failure of the background process.
Return codes are:

    INIT_OK                       =  0
    E_SNIFFER_NOT_FOUND           = -1
    E_CANNOT_CONFIGURE_HARDWARE   = -2
    E_SNIFFER_LICENSE_INVALID     = -3
    E_NOT_INITIALIZED             = -4
    E_BUFFER_ALLOCATION_FAILED    = -5

##### int getHardwareChanged(sniffHandle h);

This is a boolean function that reports any change in the hardware status.
Calling this function returns the `changed` status and automatically clears
the status to false (false = 0).

A GUI program will typically call `getHardwareStatus()` from its main loop.

#### Connect and Disconnect

##### void setConnect(sniffHandle h, int boolVal);

Connects or disconnects the link between the sniffer's Host and Device
sockets.
Typical use is to disconnect before a data capture;
the capture logic will then reconnect so that startup packets are captured.

#### Run and Stop

##### void setNeeded(sniffHandle h, unsigned v);

Set the capture size in compressed bytes.
If needed, the value will be reduced at run time to the maximum possible.

##### void setRun(sniffHandle h, int boolVal);

This function sets a flag that is periodically inspected by a background
thread when it is idling.
Setting the flag to `true` fires off a data acquisition.
Setting the flag to `false` has no effect.

##### int getRun(sniffHandle h);

Returns the state of the internal `run` flag.

##### void setStop(sniffHandle h, int boolVal);

This function sets a flag that is periodically inspected by a background
thread when it is running a data acquisition.
Setting the flag to `true` terminates the acquisition.
Setting the flag to `false` has no effect.

##### int getStop(sniffHandle h);

Returns the state of the internal `stop` flag.

#### Get Progress

##### int getDone(sniffHandle h);

When `run` is commanded, background logic will
instruct the sniffer hardware to perform a data capture
and then download the captured data and decompress it.
It then sets a `done` flag and returns to idle.

This function returns and clears the state of the internal `done` flag.

##### unsigned getCaptureCount(sniffHandle h);

Returns the number of bytes of compressed data captured by the hardware.

##### unsigned getDecodedCount(sniffHandle h);

Returns the number of bytes of compressed data downloaded from the
hardware and decoded by the software.

#### Get Captured Data

##### unsigned getPacketDataRowCount(sniffHandle h);

Captured data is grouped into rows corresponding broadly to packets.
This function returns the row count.

##### unsigned getPacketDataRow(sniffHandle h, unsigned rowIx, char *outStr, unsigned outLen);

If outLen is large enough, copies the row to the outStr buffer.
Otherwise, outStr is unchanged.

Returns the length of the row string including a terminating null.

See below for examples of the data rows.

## Text Row Format

Lines starting with '--' are comments.

For CRC decodes, P=Pass, F=Fail.

Fields are split with ';' characters.

Each row starts with an *indentation level* and is terminated with "\n\0".
Rows which represent USB packets include the decimal packet type ID;
for instance H:2 because 2 is the ID for a handshake packet.

Times and durations are shown as decimal counts in 12MHz ticks.
i.e. each tick is 1/12 microseconds.

### Packets

#### K: Token Packet

Example: `2;K:13;TI:3467647;AD:3;EP:0;5P:0a;TL:5`

#### D: Data Packet

Example: `2;D:11;TI:3468567;DA:4b,00,00;6P:00;TL:5`

#### H: Handshake Packet

Example: `2;H:2;TI:3318368;TL:7`

#### S: SOF Packet

Example: `1;S:5;TI:3070276;FR:1202;5P:1a;TL:11967`


### Non-packet Events

#### Y: Reset

Example: `0;Y:Reset;TI:1206414;RL:658533;TL:5239`


### Groupings

#### G: SOF group

Example: `0;G:SOFgroup;X:33`

#### T: Transaction

Example: `1;T:SETUP;X:3`

#### C: Control Transfer

Example: `0;C:Control;X:4`


### Fields

#### X: Repetition count

Example: `0;G:SOFgroup;X:33`
The count (33 in this case) is in decimal.

#### 5P: CRC_5 Pass and 5F: CRC5 Fail

Example: `1;S:5;TI:3070276;FR:1202;5P:1a;TL:11967`
The CRC (1a in this case) is in hexadecimal.

#### 6P: CRC16 Pass and 6F: CRC16 Fail

Example: `2;D:3;TI:1864548;DA:80,06,00,01,00,00,40,00;6P:94dd;TL:5`
The CRC (94dd in this case) is in hexadecimal.

#### AD: Address

Example: `2;K:9;TI:2437451;AD:5;EP:0;5P:1a;TL:5`
The Address (5 in this case) is in decimal.

#### DA: Data

Example: `2;D:11;TI:3468567;DA:4b,00,00;6P:00;TL:5`
The data values are comma separated hexadecimal values.

#### EP: Endp

Example: `2;K:9;TI:2593006;AD:5;EP:0;5P:1a;TL:5`
The Endpoint (0 in this case) is in decimal.

#### FR: Frame

Example: `0;S:5;TI:2484305;FR:1165;5P:16;TL:7`
The Frame number (1165 in this case) is in decimal.

#### RL: Reset length

Example: `0;Y:Reset;TI:1249543;RL:180095;TL:10645`
The decimal Reset Length (180095 in this case) is a count in 12MHz ticks.

#### TI: Tick

Example: `1;S:5;TI:1824315;FR:1110;5P:11;TL:11967`
The decimal Start Time (1824315 in this case) for this packet or event in 12MHz ticks.

#### TL: Tail length

Example: `2;H:10;TI:2522009;TL:67`
The decimal Idle Time (67 in this case) after the packet is a count in 12MHz ticks.
