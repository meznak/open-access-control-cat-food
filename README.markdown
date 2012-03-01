Open Access Control - Cat Food Edition
======================================

This is a stripped-down version of the 23b hackerspace's Open Access Control system, intended for embedded use with an RFID reader for authenticating cat-implante dWiegand RFID chips to control cat feeding. Please see http://code.google.com/p/open-access-control/ for the main/full version.

For more info, contact @meznak on Twitter.

Structure
---------

* This folder
  * Open Access Control folder
    * Open Access Control.pde (Arduino code -- open from the Arduino IDE.)
  * libraries folder (copy the contents of this folder to your Arduino program's libraries folder.)
    * PCATTACH folder
      * keywords.txt
      * PCATTACH.cpp
      * PCATTACH.h
    * Wiegand26 folder
      * keywords.txt
      * WIEGAND26.cpp
      * WIEGAND26.h
  * hardware folder
    * open-access-interlock.brd (This will change dramatically before it's finished. Currently, it's a control board for a laser.)
