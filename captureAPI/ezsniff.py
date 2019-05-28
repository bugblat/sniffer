#!/usr/bin/env python

#----------------------------------------------------------------------
# Name:        ezsniff.py
# Purpose:     example of running the sniffer hardware via a DLL/SO
#
# Author:      Tim
#
# Created:     01/10/2018
# Copyright:   (c) Tim 2018
# Licence:     see the LICENSE.txt file
#----------------------------------------------------------------------

from __future__ import print_function

import sys, ctypes, time, os.path

from ctypes import *

##---------------------------------------------------------
INIT_OK                       =  0
E_SNIFFER_NOT_FOUND           = -1
E_CANNOT_CONFIGURE_HARDWARE   = -2
E_SNIFFER_LICENSE_INVALID     = -3
E_NOT_INITIALIZED             = -4
E_BUFFER_ALLOCATION_FAILED    = -5

##---------------------------------------------------------
# note that this DLL/SO uses false=0, true=1
def main():
  sniffer = None
  try:

    dll_name = "libsniff_ez.dll"
    # dllabspath = os.path.dirname(os.path.abspath(__file__))
    # dllabspath += os.path.sep + dll_name
    try:
      sniff = ctypes.CDLL(dll_name)    # or dllabspath
    except OSError:
      try:
        sniff = ctypes.CDLL("libsniff_ez.so")
      except OSError:
        print('libsniff_ez.dll or libsniff_ez.so is missing - exiting')
        return

    buff = create_string_buffer(256)
    rv = sniff.version(buff, sizeof(buff))
    print('Using library version: %s\n' % repr(buff.value))

    # beeps from your computer as drivers are loaded :)
    sniffer = c_int(sniff.sniffInit())
    
    # loop while waiting for the OS to do its thing
    snifferStatus = E_SNIFFER_NOT_FOUND 
    for i in range(0, 6):
      stat = c_int(sniff.getHardwareStatus(sniffer))
      snifferStatus = stat.value
      if snifferStatus != E_SNIFFER_NOT_FOUND:
        break
      time.sleep(1)    

    if snifferStatus != INIT_OK:        # probably timed out
      print('problem !!!!')
      sniff.sniffEnd(sniffer)
      return

    # here when the sniffer is found OK
    # disconnect
    sniff.setConnect(sniffer, 0)
    needed = 16 * 1024                  # easily covers setup
    sniff.setNeeded(sniffer, needed)  
    # reconnect and run
    sniff.setRun(sniffer, 1)

    # loop until finished
    # capture first
    while True:
      cc    = sniff.getCaptureCount(sniffer)
      cdone = sniff.getCaptureDone(sniffer)
      print(cc, ' ', sep='')
      if cdone:
        break
      time.sleep(1)    

    # then decode
    print(' ---> ')
    sniff.startDecode(sniffer);
    while True:
      dc    = sniff.getDecodedCount(sniffer)
      ddone = sniff.getDecodeDone(sniffer)
      print(dc, ' ', sep='')
      if ddone:
        break
      time.sleep(1)    

    # get packet data plus decoded transactions, etc.
    lineCount = sniff.getPacketDataRowCount(sniffer) 
    print(lineCount, 'decoded rows')

    ofile = open('pyoutput.txt', 'w')
    # a huge buffer..
    rowBuf = create_string_buffer(10 * 1024)    

    for i in range(0, lineCount):
      sniff.getPacketDataRow(sniffer, i, rowBuf, sizeof(rowBuf))
      # decoded rows are terminated with \n\0
      # now you can split the data, analyze it any way you want...
      # this program just writes out a file
      ofile.write(rowBuf.value)

    ofile.close()      

    sniff.sniffEnd(sniffer)

  except:
    e = sys.exc_info()[0]
    print('\nException caught %s\n' % e)

##---------------------------------------------------------
if __name__ == '__main__':
  print('====================hello==========================')
  main()
  print('\n==================== bye ==========================')

# EOF -----------------------------------------------------
