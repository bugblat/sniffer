# File Format(s)

## bud Files

The *.bud* files that can be saved from Sniffer applications
are ZIP files of the decoded data from getPacketDataRow().
See the libsniff documentation for getPacketDataRow().
Decoded data is saved in text with one line per packet.

Here are the first few lines of a typical file:

    BUFMT01
    185755
    0;Y:Reset;TI:0;RL:2;TL:1205524
    0;Y:Reset;TI:1205526;RL:658534;TL:4797
    0;G:SOFgroup;X:33
      1;S:5;TI:1868857;FR:1376;5P:09;TL:11967

Line 1: file format ID

~~~{note}
  We expect we will extend this format in future releases.
  Always check the file format ID.
~~~

Line 2: data length in bytes - i.e. file length not including the first two lines

Lines 3 to end: one line per decoded packet or event, as below.

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

