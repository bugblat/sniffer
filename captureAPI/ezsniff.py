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

import sys, ctypes, time, os.path, platform, struct

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
  print("Python {:s} on {:s}\n".format(sys.version, sys.platform))
  sniffer = None
  try:

    dll_name = "./libsniff_ez"
    if platform.system() == 'Windows':
      # print('Windows')
      try:
        dll = CDLL(dll_name)
      except OSError as err:
        print("OS error: {0}".format(err))
        print(dll_name + '.dll is missing - exiting')
        return
    else:
      # print('Linux assumed')
      try:
        dll = CDLL(dll_name + '.so')
      except OSError as err:
        print("OS error: {0}".format(err))
        print(dll_name + '.so is missing - exiting')
        return
        
    ## if 64-bit, define the argument and result types
    if struct.calcsize("P") == 8:
      dll.setConnect.argtypes            = [c_ulonglong, c_int]
      dll.setRun.argtypes                = [c_ulonglong, c_int]
      dll.setStop.argtypes               = [c_ulonglong, c_int]
      dll.getRun.argtypes                = [c_ulonglong]
      dll.getStop.argtypes               = [c_ulonglong]
      dll.getCaptureDone.argtypes        = [c_ulonglong]
      dll.getDecodeDone.argtypes         = [c_ulonglong]
      dll.getHardwareChanged.argtypes    = [c_ulonglong]
      dll.setNeeded.argtypes             = [c_ulonglong, c_uint]
      dll.getCaptureCount.argtypes       = [c_ulonglong]
      dll.startDecode.argtypes           = [c_ulonglong]
      dll.getDecodedCount.argtypes       = [c_ulonglong]
      dll.getHardwareStatus.argtypes     = [c_ulonglong]
      dll.getSerial.argtypes             = [c_ulonglong, c_char_p, c_uint]
      dll.getSerialX.argtypes            = [c_ulonglong]
      dll.getSerialX.restype             = c_char_p
      dll.getPacketDataRowCount.argtypes = [c_ulonglong]
      dll.getPacketDataRow.argtypes      = [c_ulonglong, c_uint, c_char_p, c_uint]
      dll.getPacketDataRowX.argtypes     = [c_ulonglong, c_uint]
      dll.getPacketDataRowX.restype      = c_char_p
      dll.getBoxStrX.argtypes            = [c_ulonglong, c_uint]
      dll.getBoxStrX.restype             = c_char_p
      dll.linix2rowptr.argtypes          = [c_ulonglong, c_uint]
      dll.linix2rowptr.restype           = c_char_p
      dll.sampleFileRead.argtypes        = [c_ulonglong, c_char_p]
      dll.sniffInit.restype              = c_ulonglong
      dll.sniffEnd.argtypes              = [c_ulonglong]

    buff = create_string_buffer(256)
    rv = dll.version(buff, sizeof(buff))
    print('Using library version: %s\n' % repr(buff.value))

    # beeps from your computer as drivers are loaded :)
    sniffer = dll.sniffInit()
    print(hex(sniffer))
    
    # loop while waiting for the OS to do its thing
    snifferStatus = E_SNIFFER_NOT_FOUND 
    for i in range(0, 6):
      snifferStatus = dll.getHardwareStatus(sniffer)
      if snifferStatus != E_SNIFFER_NOT_FOUND:
        break
      time.sleep(1)    

    if snifferStatus != INIT_OK:        # probably timed out
      print('problem !!!!')
      dll.sniffEnd(sniffer)
      return

    # here when the sniffer is found OK
    # disconnect
    dll.setConnect(sniffer, 0)
    needed = 16 * 1024                  # easily covers setup
    dll.setNeeded(sniffer, needed)  
    # reconnect and run
    dll.setRun(sniffer, 1)

    # loop until finished
    # capture first
    while True:
      cc    = dll.getCaptureCount(sniffer)
      cdone = dll.getCaptureDone(sniffer)
      print(cc, ' ', sep='')
      if cdone:
        break
      time.sleep(1)    

    # then decode
    print(' ---> ')
    dll.startDecode(sniffer);
    while True:
      dc    = dll.getDecodedCount(sniffer)
      ddone = dll.getDecodeDone(sniffer)
      print(dc, ' ', sep='')
      if ddone:
        break
      time.sleep(1)    

    # get packet data plus decoded transactions, etc.
    lineCount = dll.getPacketDataRowCount(sniffer) 
    print(lineCount, 'decoded rows')

    ofile = open('pyoutput.txt', 'wb')
    # a huge buffer..
    rowBuf = create_string_buffer(10 * 1024)    

    for i in range(0, lineCount):
      dll.getPacketDataRow(sniffer, i, rowBuf, sizeof(rowBuf))
      # decoded rows are terminated with \n\0
      # now you can split the data, analyze it any way you want...
      # this program just writes out a file
      ofile.write(rowBuf.value)

    ofile.close()      

    dll.sniffEnd(sniffer)

  except:
    e = sys.exc_info()[0]
    print('\nException caught %s\n' % e)

##---------------------------------------------------------
if __name__ == '__main__':
  print('====================hello==========================')
  main()
  print('\n==================== bye ==========================')

# EOF -----------------------------------------------------
