/*
 * Open Source RFID Access Controller - CAT FOOD EDITION
 *
 * 2/29/2012 v0.01
 * Last build test with Arduino v00.22
 *
 * Cat Food Edition by:
 * Nate Plamondon - nplamondon@gmail.com
 * See: https://github.com/meznak/open-access-control-cat-food
 *
 * Based on Minimal HTTP Edition by:
 * Will Bradley - bradley.will@gmail.com
 * See: https://github.com/zyphlar/open-access-control-minimal-http
 *
 * Based on Open Source RFID Access Controller code by:
 * Arclight - arclight@23.org
 * Danozano - danozano@gmail.com
 * See: http://code.google.com/p/open-access-control/
 *
 * Notice: This is free software and is probably buggy. Use it at
 * at your own peril. Use of this software may result in your
 * doors being left open, your stuff going missing, or buggery by
 * high seas pirates. No warranties are expressed on implied.
 * You are warned.
 *
 *
 *
 * This program interfaces the Arduino to RFID
 * using the Wiegand-26 Communications Protocol.
 * Outputs go to motors for food distribution and access control.
 *
 * Relay outputs on digital pins 6,7,8,9 //TODO: fix this conflict -WB
 * Reader 1: pins 2,3
 * Ethernet: pins 10,11,12,13 (reserved for the Ethernet shield)
 * Warning buzzer: 8
 * Warning led: 9
 *
 * Quickstart tips:
 * Compile and upload the code, then log in via serial console at 57600,8,N,1
 *
 */

/////////////////
// Includes
/////////////////

#include <EEPROM.h> // Needed for saving to non-voilatile memory on the Arduino.

#include <Ethernet.h>
#include <SPI.h>
//#include <Server.h>
//#include <Client.h>

#include <WIEGAND26.h> // Wiegand 26 reader format libary
#include <PCATTACH.h> // Pcint.h implementation, allows for >2 software interupts.
//#include <ShiftLCD.h> // LCD via shift register

// Create an instance of the various C++ libraries we are using.
WIEGAND26 wiegand26; // Wiegand26 (RFID reader serial protocol) library
PCATTACH pcattach; // Software interrupt library

/////////////////
// Global variables
/////////////////

// pin assignments
byte reader1Pins[]={2,3}; // Reader 1 pins
byte reader2Pins[]={4,5}; // Reader 2 pins
byte door1 = 7; // relay to open food cover
byte door2 = 8;
byte hopper1 = 9; // motor to move food to bowl
byte hopper2 = 10;
byte beam1 = 11; // IR beam sensor to detect cat presence
byte beam2 = 12;
byte buzzerPin = 12;
byte warningLED = 13;
// TODO: add food level sensors
//byte extendButton = A5;
//byte logoutButton = A4;

// initialize the ShiftLCD library with the numbers of the interface pins
//ShiftLCD lcd(4, 6, 5);

// statics
#define RELAYDELAY 5000 // How long to wait for cat to break IR beam (1000 = 1sec)

// Serial terminal buffer (needs to be global)
char inString[40]={0}; // Size of command buffer (<=128 for Arduino)
byte inCount=0;
boolean privmodeEnabled = false; // Switch for enabling "priveleged" commands

// variables for storing system status
volatile long reader1 = 0;
volatile long reader2 = 0;
volatile int reader1Count = 0;
volatile int reader2Count = 0;
bool cat1 = false;
bool cat2 = false;
bool relay1high = false;
bool relay2high = false;
bool beam1low = false;
bool beam2low = false;
unsigned long relay1timer=0;
unsigned long relay2timer=0;
long cat1id = 1;
long cat2id = 2;

void setup(){ // Runs once at Arduino boot-up

	/* Attach pin change interrupt service routines from the Wiegand RFID readers
	 */
	pcattach.PCattachInterrupt(reader1Pins[0], callReader1Zero, CHANGE);
	pcattach.PCattachInterrupt(reader1Pins[1], callReader1One, CHANGE);
	pcattach.PCattachInterrupt(reader2Pins[0], callReader2Zero, CHANGE);
	pcattach.PCattachInterrupt(reader2Pins[1], callReader2One, CHANGE);


	//Clear and initialize readers
	wiegand26.initReaderOne(); //Set up Reader 1 and clear buffers.
	wiegand26.initReaderTwo(); //Set up Reader 2 and clear buffers.

	// Initialize beam inputs
	pinMode(beam1, INPUT);
	pinMode(beam2, INPUT);

	// Initialize led and buzzer
	pinMode(warningLED, OUTPUT);
	digitalWrite(warningLED, LOW);
	pinMode(buzzerPin, OUTPUT);
	digitalWrite(buzzerPin, LOW);

	//Initialize output relays
	pinMode(door1, OUTPUT);
	pinMode(door2, OUTPUT);
	digitalWrite(door1, LOW); // Sets the relay outputs to LOW (relays off)
	digitalWrite(door2, LOW);

	//Initialize output motors
	pinMode(hopper1, OUTPUT);
	pinMode(hopper2, OUTPUT);
	digitalWrite(hopper1, LOW);
	digitalWrite(hopper2, LOW);

	Serial.begin(57600); // Set up Serial output at 8,N,1,57600bps


}
void loop() // Main branch, runs over and over again
{

	//////////////////////////
	// Normal operation section
	//////////////////////////

	// Cat 1 //
	if (cat1 && relay1high) {
		// calculate current time elapsed
		long cat1time = millis() - relay1timer;
		// if time entirely elapsed, watch IR beam.
		if(cat1time >= RELAYDELAY && !beam1) {
			cat1 = false;
		}
	}

	if (!cat1 && relay1high) {
		// not cat1 -- turn off relay
		relayLow(1);
		wiegand26.initReaderOne(); // Reset for next tag scan
	}

	if (cat1 && !relay1high) {
		// cat1 -- turn on relay
		relayHigh(1);
		wiegand26.initReaderOne(); // Reset for next tag scan
	}

	// Cat 2 //
	if (cat2 && relay2high) {
		// calculate current time elapsed
		long cat2time = millis() - relay2timer;
		// if time entirely elapsed, watch IR beam.
		if(cat2time >= RELAYDELAY && !beam2) {
			cat2 = false;
		}
	}

	if (!cat2 && relay2high) {
		// not cat2 -- turn off relay
		relayLow(2);
		wiegand26.initReaderTwo(); // Reset for next tag scan
	}

	if (cat2 && !relay2high) {
		// cat2 -- turn on relay
		relayHigh(2);
		wiegand26.initReaderTwo(); // Reset for next tag scan
	}

	//////////////////////////
	// Reader input/authentication section
	//////////////////////////
	if (reader1Count >= 26)
	{ // When tag presented to reader1 (No keypad on this reader)

		Serial.println("checking...");

		if (reader1 == cat1id) {
			cat1 = true;
			Serial.println("cat1");
		}
		else {
			cat1 = false;
			Serial.println("Not cat1");
		}
		wiegand26.initReaderOne(); // Reset for next tag scan
	}

	if (reader2Count >= 26)
	{ // When tag presented to reader1 (No keypad on this reader)

		Serial.println("checking...");

		if (reader2 == cat2id) {
			cat2 = true;
			Serial.println("cat2");
		}
		else {
			cat2 = false;
			Serial.println("Not cat2");
		}
		wiegand26.initReaderTwo(); // Reset for next tag scan
	}
} // End of loop()

/* Access System Functions - Modify these as needed for your application.
   These function control lock/unlock and user lookup.
 */

void relayHigh(int input) { //Send an unlock signal to the door and flash the Door LED
	byte dp = 1;

	if (input == 1) {
		dp = door1; 
		relay1high = true;
		relay1timer = millis();
	}
	else if (input == 2) {
		dp = door2;
		relay2high = true;
		relay2timer = millis(); }

	digitalWrite(dp, HIGH);

	Serial.print("Relay ");
	Serial.print(input,DEC);
	Serial.println(" high");

}

void relayLow(int input) { //Send an unlock signal to the door and flash the Door LED
	byte dp = 1;

	if (input == 1) {
		dp=door1; }
	else if (input == 2) {
		dp=door2; }

	digitalWrite(dp, LOW);

	if (input == 1) {
		relay1high = false; }
	else if (input == 2) {
		relay2high = false; }

	Serial.print("Relay ");
	Serial.print(input,DEC);
	Serial.println(" low");

}

/* Wrapper functions for interrupt attachment
   Could be cleaned up in library?
 */
void callReader1Zero(){wiegand26.reader1Zero();}
void callReader1One(){wiegand26.reader1One();}
void callReader2Zero(){wiegand26.reader2Zero();}
void callReader2One(){wiegand26.reader2One();}
//void callReader3Zero(){wiegand26.reader3Zero();}
//void callReader3One(){wiegand26.reader3One();}
