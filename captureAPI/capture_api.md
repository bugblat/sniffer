# Capture API

The *Capture API* interface operates identically for the
miniSniffer and the ezSniffer.
For simplicity, examples in this document refer to the
miniSniffer.

The components of the *Capture API* interface are:

  * the API library.
    For the miniSniffer this is *libsniff_min* DLL and SO,
    for the ezSniffer this is *libsniff_ez* DLL and SO.
  * API documentation: *libsniff.h*.
  * minisniff.py and ezSniff.py,
    example Python programs that uses the API.

## Example Program

Complete examples are in the github repo.
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

### Remarks:

- initializing the miniSniffer (sniffInit) involves finding and opening
  the miniSniffer board
- when a capture is started (setRun) a flag is set in a separate thread
  which updates its progress via the getDone() flag.
  The program must sleep until this signals *true*.
- final output is a set of text rows, as documented below.

## API

The API is defined in libsniff.h.

Boolean values for true and false vary between languages.
Regular integers are used for booleans:

    0: false
    not 0: true

sniffHandle is a C void* value.
In other languages this could be represented as an integer,
unsigned if available.

Strings are C char* values,
null-terminated sequences of ASCII characters.

### Library Version

#### unsigned version(char *outStr, unsigned outLen);

If outLen is large enough, copies the version string to the outStr buffer.
Otherwise, outStr is unchanged.

returns: The length of the version string including a terminating null.

example version string: `libminisniff DLL/SO,Feb 27 2019,18:42:03`

#### const char *versionX();

returns: a pointer to a buffer within the library.

### Initialization and Termination

#### sniffHandle sniffInit();

returns: a handle that can be used to query and control the sniffer hardware
and software.

See also `getHardwareStatus()`

#### void sniffEnd(sniffHandle h);

Closes the connection to the sniffer board.
Pass-through connected/disconnected status is not changed.

### Hardware Information

#### unsigned getSerial(sniffHandle h, char *outStr, unsigned outLen);

If outLen is large enough, copies the serial string to the outStr buffer.
Otherwise, outStr is unchanged.

returns: The length of the serial string including a terminating null.

example serial string: `BU2ABCDEFG`

#### const char *getSerialX(sniffHandle h);

returns: a pointer to a buffer within the library.

#### int getHardwareStatus(sniffHandle h);

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

#### int getHardwareChanged(sniffHandle h);

This is a boolean function that reports any change in the hardware status.
Calling this function returns the `changed` status and automatically clears
the status to false (false = 0).

A GUI program will typically call `getHardwareStatus()` from its main loop.

### Connect and Disconnect

The Sniffers implement a connect/disconnect switch between the
host connection and the device connection.
setConnect() opens and closes this switch.
Note that setRun() also connects the host and the device.

#### void setConnect(sniffHandle h, int boolVal);

Connects or disconnects the link between the sniffer's Host and Device
sockets.
Typical use is to disconnect before a data capture;
the capture logic will then reconnect so that startup packets are captured.

### Run and Stop

#### void setNeeded(sniffHandle h, unsigned v);

Set the capture size in compressed bytes.
If needed, the value will be reduced at run time to the maximum possible.

#### void setRun(sniffHandle h, int boolVal);

This function sets a flag that is periodically inspected by a background
thread when it is idling.
Setting the flag to `true` fires off a data acquisition.
Setting the flag to `false` has no effect.

#### int getRun(sniffHandle h);

Returns the state of the internal `run` flag.

#### void setStop(sniffHandle h, int boolVal);

This function sets a flag that is periodically inspected by a background
thread when it is running a data acquisition.
Setting the flag to `true` terminates the acquisition.
Setting the flag to `false` has no effect.

#### int getStop(sniffHandle h);

Returns the state of the internal `stop` flag.

### Get Progress

Note that the 1.08 software release
implements DataCapture - capturing USB line values -
followed by DataDecode - interpreting USB line values as USB events and packets.
This will change in future releases so that DataCapture and DataDecode
are merged.

#### int getDone(sniffHandle h);

When `run` is commanded, background logic will
instruct the sniffer hardware to perform a data capture
and then download the captured data and decompress it.
It then sets a `done` flag and returns to idle.

This function returns and clears the state of the internal `done` flag.

#### unsigned getCaptureCount(sniffHandle h);

Returns the number of bytes of compressed data captured by the hardware.

#### unsigned getDecodedCount(sniffHandle h);

Returns the number of bytes of compressed data downloaded from the
hardware and decoded by the software.

### Get Captured Data

#### unsigned getPacketDataRowCount(sniffHandle h);

Captured data is grouped into rows corresponding broadly to packets.
This function returns the row count.

#### unsigned getPacketDataRow(sniffHandle h, unsigned rowIx, char *outStr, unsigned outLen);

If outLen is large enough, copies the row to the outStr buffer.
Otherwise, outStr is unchanged.

Returns the length of the row string including a terminating null.

See the *FileFormat* documentation for the description of the data rows.

