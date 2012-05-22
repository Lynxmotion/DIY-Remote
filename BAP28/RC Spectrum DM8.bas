;Description: Lynxmotion costum RC radio
;Software version: V1.1
;Date: 29-12-2008
;Programmer: Jim Frye (aka RobotDude), Kurt (aka Kurte), Jeroen Janssen (aka Xan)
;
;Hardware setup: ABB2 with ATOM 28 Pro, Spectrum DM8, 2 joysticks, 2 sliders, HEX keypath, display
;
;NEW IN V1.0
;   - As released
;
;NEW IN V1.1
;   - Added calibration sub. Calibrates the joysticks at powerup. (Xan)
;      CAUTION: Be sure that the left joystick is in the outer down position by powerup!
;   - Added small offset at the pulses to decrease the send error. (Xan)
;   - Added Alive meganism. Sends 1000 on the buttons channel every 4 cycles
;
;New in V1.2
;   - More use of arrays and zero index variable names (Kurt)
;   - Assembly language output of pulses - should be vary accurate (Kurt)
;   - Removed alive function
;   - calibrate of left joystick up/down has a little validation.
;   - Add Bind function, set pulses to predefined values to bind with,
;            Once bound with this, this is the values will use if it loses connection
;               with transmitter.
;            If Receiver is powered up without transmitter, all channels will go to default
;               except for channel 0 (Throttle - by manual).  If receiver loses contact with
;               receiver channel 0 will go to default.
;
;KNOWN BUGS:
;   - None at the moment ;)
;
;====================================================================

Display con 8
Speaker con 9
Row0    con 10
Row1    con 11
Row2    con 12
Row3    con 13   

DM8PPM   con 15   ; Spectrum DM8 signal
;DO_IN_BASIC con 1
#ifndef DO_IN_BASIC
PULSE_FIX con 20
#else
PULSE_FIX con 20
#endif

Calibrated   var bit
ChaVals      var word(7)
ChaOffset   var word(6)
iFudge      var byte      ; used as an array index in our fudge values code
wButtonPulseWidth  var word
keypress var byte

col1 var bit
col2 var bit
col3 var bit
col4 var bit

; create variables for averaging code
index var byte
buffer0 var word(8)
buffer1 var word(8)
buffer2 var word(8)
buffer3 var word(8)
buffer4 var word(8)
buffer5 var word(8)
sum0 var word
sum1 var word
sum2 var word
sum3 var word
sum4 var word
sum5 var word

input p4
input p5
input p6
input p7

output p10
output p11
output p12
output p13

; initialize each buffer element, each sum, and then index to 0
for index = 0 to 7
  buffer0(index) = 542
  buffer1(index) = 542
  buffer2(index) = 542
  buffer3(index) = 542
  buffer4(index) = 542
  buffer5(index) = 542
next

sum0 = 4336
sum1 = 4336
sum2 = 4336
sum3 = 4336
sum4 = 4336
sum5 = 4336
index = 0


; chirpy squeak kinda thing
sound Speaker, [100\880, 100\988, 100\1046, 100\1175] ;musical notes, A,B,C,D.

; wake up the Matrix Orbital display module
serout Display ,i19200, [254, 66, 0] ;Backlight on, no timeout.
serout Display ,i19200, [254, 64, "The D-I-Y 2.4ghzRobot Radio Set!"] ;startup screen. Do only once...
pause 3000

; Mark for calibration
Calibrated = 0

; initialize the ppm output signal
low DM8PPM

; check to see if we should do a bind operation
gosub CheckKeypad
if wButtonPulseWidth <> 1100 then
   gosub DoRadioBind
endif


;====================================================================
; --- top of main loop ---
start:

gosub CheckKeypad
ChaVals(6) = wButtonPulseWidth

; averaging expects that the a/d values are < 4096
; for each channel
;   read the a/d
;   subtract the previous value from 8 samples ago from the sum
;   store the new value in the circular buffer
;   add the new value to the sum
;   divide the sum by 8 to get the average value
;   convert joystick values 392 - 692 to servo values 1000uS - 2000uS

adin 2, ChaVals(0) ; right vertical 16
sum0 = sum0 - buffer0(index)
buffer0(index) = ChaVals(0)
sum0 = sum0 + ChaVals(0)
ChaVals(0) = sum0 / 8
ChaVals(0) = (((ChaVals(0)*42)-6500)/10)
ChaVals(0) = ChaVals(0) + chaOffset(0)

adin 3, ChaVals(1) ; right horizontal 17
sum1 = sum1 - buffer1(index)
buffer1(index) = ChaVals(1)
sum1 = sum1 + ChaVals(1)
ChaVals(1) = sum1 / 8
ChaVals(1) = (((ChaVals(1)*42)-6500)/10)
ChaVals(1) = ChaVals(1) + chaOffset(1)

adin 0, ChaVals(2) ; left vertical 18
sum2 = sum2 - buffer2(index)
buffer2(index) = ChaVals(2)
sum2 = sum2 + ChaVals(2)
ChaVals(2) = sum2 / 8
ChaVals(2) = (((ChaVals(2)*42)-6500)/10)
ChaVals(2) = ChaVals(2) + chaOffset(2)

adin 1, ChaVals(3) ; left horizontal 19
sum3 = sum3 - buffer3(index)
buffer3(index) = ChaVals(3)
sum3 = sum3 + ChaVals(3)
ChaVals(3) = sum3 / 8
ChaVals(3) = (((ChaVals(3)*42)-6500)/10)
ChaVals(3) = ChaVals(3) + chaOffset(3)

adin 18, ChaVals(4) ; Left slider
sum4 = sum4 - buffer4(index)
buffer4(index) = ChaVals(4)
sum4 = sum4 + ChaVals(4)
ChaVals(4) = sum4 / 8
ChaVals(4) = ChaVals(4) + 988

adin 19, ChaVals(5) ; Right slider
sum5 = sum5 - buffer5(index)
buffer5(index) = ChaVals(5)
sum5 = sum5 + ChaVals(5)
ChaVals(5) = sum5 / 8
ChaVals(5) = ChaVals(5) + 988

; finally increment the index and limit its range to 0 to 7.
index = (index + 1) & 7

if Calibrated=1 then
   ; update the display module
   branch index, [update1,update2,update3,update4,update5,update6,update7,update8]

   update8:
   update7:
   serout Display, i19200, [254, 71, 11, 1, keypress]
   goto makepulses

   update6:
   if ChaVals(5)<1000 then
      serout Display, i19200, [254, 71, 6, 2, " ", dec ChaVals(5)]
   else
      serout Display, i19200, [254, 71, 6, 2, dec ChaVals(5)]
   endif
   goto makepulses

   update5:
   if ChaVals(4)<1000 then
      serout Display, i19200, [254, 71, 6, 1, " ", dec ChaVals(4)]
   else
      serout Display, i19200, [254, 71, 6, 1, dec ChaVals(4)]
   endif
   goto makepulses

   update4:
   if ChaVals(3)<1000 then
      serout Display, i19200, [254, 71, 1, 2, " ", dec ChaVals(3)]
   else
      serout Display, i19200, [254, 71, 1, 2, dec ChaVals(3)]
   endif
   goto makepulses

   update3:
   if ChaVals(2)<1000 then
      serout Display, i19200, [254, 71, 1, 1, " ", dec ChaVals(2)]
   else
      serout Display, i19200, [254, 71, 1, 1, dec ChaVals(2)]
   endif
   goto makepulses

   update2:
   if ChaVals(1)<1000 then
      serout Display, i19200, [254, 71, 13, 2, " ", dec ChaVals(1)]
   else
      serout Display, i19200, [254, 71, 13, 2, dec ChaVals(1)]
   endif
   goto makepulses

   update1:
   if ChaVals(0)<1000 then
      serout Display, i19200, [254, 71, 13, 1, " ", dec ChaVals(0)]
   else
      serout Display, i19200, [254, 71, 13, 1, dec ChaVals(0)]
   endif
   goto makepulses


   ; build and send the ppm output
   makepulses:

   gosub GeneratePulses
endif

if Calibrated=0 & index=0 then
  gosub Calibrate
endif

; do it again ad infinitum
goto start

;------------------------------------------------------------------------------
; Generate Pulse function
;
; Variables used: ChanVals array has the pulse widths in us

GeneratePulses:
#ifndef DO_IN_BASIC
   ; fudge the values.  It looks like the transmitter may not fully accuratly take
   ; the signals in and give them out 100% correctly.  So try to fudge...
   for iFudge = 0 to 6
      ChaVals(iFudge) = chaVals(iFudge) - 3 + (ChaVals(iFudge)-988)/70
   next
   
      output DM8PPM
   ; The DM8PPM pin should already be configured for output...
      ; This is P15 on BAP which is P87 on the underlying H8/3694
      ; transistion to assembly language.
      ; fist setup loop counters and the like before we manipulate the IO port
   mov.l   #CHAVALS:32, er3      ; er3 has pointer to our array of desired values
   mov.b   #7, r2l            ; r2l has count of how many channels we wish to output
   bset.b   #7,@PCR8:8         ; make sure set to output, basic should have done earlier!
   
_MP_LOOP:   
   bset.b   #7,@PDR8:8         ; (L8)set P15 high (Low over head here 26)
   mov.w   #200, r1         ; (H4) - We want to pause 400 .5us (pauseus does .5 us)
   nop                     ; (H2)
   nop                     ; (H2)
   nop                     ; (H2)
   nop                     ; (H2)
   jsr      @_MP_PAUSE:24      ; (H8) - Call our wait function.

   bclr.b   #7,@PDR8:8         ; (H8) Go low again - so high overhead here (26)
   mov.w   @er3+, r1         ; (L6) Get the wait count for current channel from array and increment array pointer
   sub.w   #400, r1         ; (L4) subtract off our high pulse widths..
   jsr      @_MP_PAUSE:24      ; (L8) call our wait function
   dec.b   r2l               ; (L2) decrement our counter for how many items to output
   bne      _MP_LOOP:8         ; (L4) still more channels to output
;  loop is done, need to do trailing pulse
   bset.b   #7,@PDR8:8         ; (8)set P15 high
   mov.w   #200, r1         ; (4) - We want to pause 400
   jsr      @_MP_PAUSE:24      ; (8) - Call our wait function.
   bclr.b   #7,@PDR8:8         ; (8) Go low again
   bra      _MP_DONE:8         ; we are done!
   
; internal assembly function to wait a number of us
; Overhead of setup and call to here: 28 or 30
; setup and return overhead: 20: so total of 48/16 = 3us
; add/subtract some fudge
_MP_PAUSE:
   sub.w   #3, r1            ; (4) - subtract call/setup overhead from counter
   shal.w   r1               ; (2) - will multply by 16 to get clock cycles
   shal.w   r1               ; (2) - Should be safe max value ~2000
   shal.w   r1               ; (2)
   shal.w   r1               ; (2)
   nop                     ; fudge
   nop                     ;
   
_MP_PAUSE_LOOP:
   sub.w   #8, r1            ; (4) - decrement the time per loop cycle from loop
   bne      _MP_PAUSE_LOOP:8   ; (4) - hard spin in the loop. - since round number can simply test for zero

   rts                     ; (8) - return

_MP_DONE:
   ; will fall through to return and transition back into basic
#else
   ChaVals(0) = (((ChaVals(0)-PULSE_FIX)*2)-800) ; right vertical
   ChaVals(1) = (((ChaVals(1)-PULSE_FIX)*2)-800) ; right horizontal
   ChaVals(2) = (((ChaVals(2)-PULSE_FIX)*2)-800) ; left vertical
   ChaVals(3) = (((ChaVals(3)-PULSE_FIX)*2)-800) ; left horizontal
   ChaVals(4) = (((ChaVals(4)-PULSE_FIX)*2)-800)
   ChaVals(5) = (((ChaVals(5)-PULSE_FIX)*2)-800)
   ChaVals(6) = ((ChaVals(6)*2)-800)
   
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(0)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(1)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(2)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(3)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(4)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(5)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
   pauseus ChaVals(6)
   high DM8PPM ;pulsout 15,800
   pauseus 400
   low DM8PPM
#endif
   return

;------------------------------------------------------------------------------
; CheckKeypad function
;
; Variables updated:
;      wButtonPulseWidth - The pulse width
;      keypress - the ascii value associated with that key.
CheckKeypad:
   low  Row0
   high Row1
   high Row2
   high Row3
   
   col1 = in4
   col2 = in5
   col3 = in6
   col4 = in7

   ;Read buttons
   if col1 = 0 then
       wButtonPulseWidth  = 1200;   1
       keypress = "1"
   elseif col2 = 0
       wButtonPulseWidth  = 1250;   2
       keypress = "2"
   elseif col3 = 0
       wButtonPulseWidth  = 1300;   3
       keypress = "3"
   elseif col4 = 0
       wButtonPulseWidth  = 1650;   A
       keypress = "A"
   else
       high Row0
       low  Row1
       col1 = in4
       col2 = in5
       col3 = in6
       col4 = in7
       if col1 = 0 then
           wButtonPulseWidth  = 1350;   4
           keypress = "4"
       elseif col2 = 0
           wButtonPulseWidth  = 1400;   5
           keypress = "5"
       elseif col3 = 0
           wButtonPulseWidth  = 1450;   6
           keypress = "6"
       elseif col4 = 0
           wButtonPulseWidth  = 1700;   B
           keypress = "B"
       else
           high Row1
           low  Row2
           col1 = in4
           col2 = in5
           col3 = in6
           col4 = in7
           if col1 = 0 then
               wButtonPulseWidth  = 1500;   7
               keypress = "7"
           elseif col2 = 0
               wButtonPulseWidth  = 1550;   8
               keypress = "8"
           elseif col3 = 0
               wButtonPulseWidth  = 1600;    9
               keypress = "9"
           elseif col4 = 0
               wButtonPulseWidth  = 1750;   C
               keypress = "C"
           else
               high Row2
               low  Row3
               col1 = in4
               col2 = in5
               col3 = in6
               col4 = in7
               if col1 = 0 then
                   wButtonPulseWidth  = 1150;   0
                   keypress = "0"
               elseif col2 = 0
                   wButtonPulseWidth  = 1900;   F
                   keypress = "F"
               elseif col3 = 0
                   wButtonPulseWidth  = 1850 ;   E
                   keypress = "E"
               elseif col4 = 0
                   wButtonPulseWidth  = 1800;   D
                   keypress = "D"
               else
                   wButtonPulseWidth = 1100;   None is pushed
                   keypress = " "
               endif
           endif
       endif
   endif


   return
   
;====================================================================
;Calibrates middle positions of the sticks to 1500
;Calibrates left vertical stick to be total down
Calibrate:
   serout Display, i19200, [254, 88] ;clear screen     
   serout Display, i19200, [254, 0, "Calibrating..."]
   pause 1000     
   
   ChaOffset(0) = 1500 - ChaVals(0) ; right vertical 16
   ChaOffset(1) = 1500 - ChaVals(1) ; right horizontal 17

; special care for this one as user(me) may forget to put down to bottom
;   if (chaVals(2) > 975) and (chaVals(2) < 1125) then
      ChaOffset(2) = 1000 - ChaVals(2) ; left vertical 18
;   else
;      ChaOffset(2) = 0
;   endif
   
   ChaOffset(3) = 1500 - ChaVals(3) ; left horizontal 19
   
   serout Display, i19200, [254, 88] ;clear screen
   
   ; Mark as calibrated
     Calibrated=1
return

;------------------------------------------------------------------------------
; DoRadioBind function
;
;      This function will set the 7 channels to fixed values that are transmitted
;       This is used when the user is trying to bind the transmitter to the receiver
;      Once bound, the receiver will use these values whenever it loses contact
;      with the transmitter.  This will allow us to have code on the receiver side
;      that can detect this and put the robot into a safe state.
;
;      TBD: Could allow the values to be set by each user, by where the sticks are, or
;      could use keypad to enter...
;
;      This function does not return.
DoRadioBind:

   serout Display, i19200, [254, 88] ;clear screen     
   serout Display ,i19200, [254, 0, ">>Radio Bind!<<"] ;startup screen. Do only once...

   while 1
      ChaVals = 1500, 1500, 800, 1500, 988, 988, 2000
      gosub GeneratePulses      ; output pulses.
      pause 6               ; not sure
   wend

   return   ; will never happen!