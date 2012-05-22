;====================================================================
; DIY - Radio Receiver Test Program
;
; Currently this program assumes all 7 inputs are hooked up to P0-P6
; TBD - Make more general purpose, to allow different input pins.
;       For P1-P7 change mask from 0x7f to 0xfe and make pulse_values word(8)
;       For P8,10-15 change mask to 0xFD, PDR5 to PDR8, and pulse_values to word(8)
; BUGBUG - Need to check how PCR5 and PMR5 are used...

awPulsesIn          var word(7)
bPulseTimeout      var byte

awPulsesPrev      var   word(7)
fPulseChanged      var bit      ; we had a channel change
fNoTransmitter      var bit      ; did we detect no transmitter...
fLostTransmitter   var   bit      ; We lost contact with transmitter

i               var   byte
keypress          var byte
pulse_slop         con 2

;--------------------------------------------------------------------
; Init code
;====================================================================
   ; Make sure all 7 pins are marked for input...
   input p0
   input p1
   input p2
   input p3
   input p4
   input p5
   input p6
   
   fNoTransmitter = 0      ; assume we have a transmitter.
   fLostTransmitter = 0
   
start:
   gosub Pulsein7
   
   

   ; if we get a timeout and it is channel 0 then we now the receiver is not on...
   if (bPulseTimeout) then
      ; we detected no tranmitter at startup...
      if fNoTransmitter = 0 then
         serout s_out, i9600, ["No Transmitter at power up(",hex bPulseTimeout, ")", 13 ]
         fNoTransmitter = 1
      endif
   elseif awPulsesIn(0) < 950
      ; On Bind we set channel 1 to about 800 normal is usually > 1000 so if under 950
      ; we probably lost our connection with the transmitter
      if fLostTransmitter = 0 then
         serout s_out, i9600, ["Lost contact with transmitter", 13]
         fLostTransmitter = 1
      endif
   
   else
      ; Ok we hamve a message so reset our error codes
       fNoTransmitter = 0      ; assume we have a transmitter.
      fLostTransmitter = 0

      fPulseChanged = 0
      for i = 0 to 6
         if (awPulsesIn(i) > (awPulsesPrev(i)+pulse_slop)) or (awPulsesIn(i) < (awPulsesPrev(i)-pulse_slop)) then
            fPulseChanged = 1
            awPulsesPrev(i) = awPulsesIn(i)
         endif
      next
      
      if fPulseChanged or bPulseTimeout  then
         if awPulsesIn(6) < 1135 then 
            keypress = 0xff
         else
            keypress = (awPulsesIn(6)+15 - 1150) / 50  ; add in some slope as we could be slight
         endif
    
         serout s_out, i9600, [hex bPulseTimeout, ":", hex keypress, ":" ]
         for i = 0 to 6
            serout s_out, i9600, [dec awPulsesIn(i)," "]
         next
         serout s_out, i9600,[13]
   
         if keypress = 0xA then
           low 12
         else
           input p12
         endif
         
         if keypress = 0xB then
           low 13
         else
           input p13
         endif
         
         if keypress = 0xC then
           low 14
         else
           input p14
         endif
      endif
   endif

goto start

;==============================================================================
; Read in all 7 servo values in one pass.
;   
;-------------------------------------------------------------------
Pulsein7:
    ; Make sure all 7 IOs are set to input.
    PMR5 = 0 ; all IO lines are general IO
    PCR5 = 0 ; All are input  (may want to leave bit 7 alone...
   
    ; Ok now lets transisiton to assembly language.
    ;
;    bMask = 0x7f                      ; set a mask of which bits we are needing...
;                                 ; Mask could be 0xFE for pins 1-7, need to make array 8 not 7
    mov.b   #0x7f, r1l                  ; Ok R1l will be our mask for outstanding IO port bytes.

    ; wait until none of the IO lines are high...
;    while PDR5 & bMask
;        ;
;    wend
   mov.l   #250000,er2                  ;(4) - setup timeout counter   
_PI7_WAIT_FOR_ALL_LOW:
   mov.b   @PDR5:8, r0l
   and.b   r1l, r0l         ; see if any of the IO bits is still on...
   beq      _PI7_WAIT_FOR_NEXT_IO_TO_GO_HIGH:8   ; all zero go to wait for one to go high...
   dec.l   #1,er2                     ;(2)   
   bne      _PI7_WAIT_FOR_ALL_LOW:8   ; an IO pin is high and we have not timed out, keep looping until none are high
   ; We timed out waiting for all inputs to be low, so error out...
   bra      _P17_RETURN_STATUS:16         ; will return status that all timed out...

;    while bMask   

_PI7_WAIT_FOR_NEXT_IO_TO_GO_HIGH:
   mov.l   #250000,er2                  ;(4) - setup timeout counter
   
_PI7_WAIT_FOR_NEXT_IO_TO_GO_HIGH2:
        ; we still need some 1 or more of the pulses...
;        while (PDR5 & bMask) = 0          ; waiting for a pulse to go high.
   mov.b   @PDR5:8, r0l               ;(4)
   and.b   r1l, r0l                  ;(*2) see if any of the IO bits is still on...
   bne      _P17_IO_WENT_HIGH:8            ;(*4) One went high so go process
   dec.l   #1,er2                     ;(2)   
   bne      _PI7_WAIT_FOR_NEXT_IO_TO_GO_HIGH2:8   ; (4) Not a timeout go try again.
; we timed out...
   bra      _P17_RETURN_STATUS:16         ; will return status of what timed out...
   
;      wend
;        iPin = ???; TBD: convert which bit is high to IO line number 0-6
;   see which bit is on in the mask
_P17_IO_WENT_HIGH:
   xor.w   r2,r2                     ;(*2)
   xor.b   r0h, r0h                  ;(*2)
   mov.l   #AWPULSESIN,er3               ;(*6)
_P17_WHICH_BIT_LOOP:   
   shlr.b   r0l                        ;(@2)
   bcs      _P17_WHICH_BIT_LOOP_DONE:8      ;(@4)
   inc.b   r0h                        ;(@2)
   inc.l   #2, er3                     ;(@2)  - point to the next place in the array.
   add.w   #18,r2                     ;(@4)  - we do 18 clocks for each pass through this loop
   bra      _P17_WHICH_BIT_LOOP:8         ;(@4)
_P17_WHICH_BIT_LOOP_DONE:
;        bMaskBit = 1 << iPin   ; get the mask for which pin...
   xor.b   r1h,r1h                     ;(*2)
   bset.b   r0h,r1h                     ;(*2) ok we have the mask
   bclr.b   r0h,r1l                     ;(*2) and clear it from our global mask of ones we are waiting for

                                 ; = (22) - count so far of clocks after went high
   
;       iPinLoopCnt = 0          ; This may be replaced with time calculations...
;        while (PDR5 & bMaskBit)
;            iPinLoopCnt = iPinLoopCnt + 1  ; how long until it goes low again
;        wend
_P17_WAIT_FOR_IO_GO_BACK_LOW:
   mov.b   @PDR5:8, r0l               ;(#4)
   and.b   r1h, r0l                  ;(#2)
   beq      _P17_IO_WENT_BACK_LOW:8         ;(#4)
   add.w   #18,r2                     ;(#4) - number of cyles per loop
   bcc      _P17_WAIT_FOR_IO_GO_BACK_LOW:8   ;(#4)
   
   ; we had a timeout return the status.
   bset.b   r0h, r1l                  ; turn back on the bit we were waiting for...
   bra      _P17_RETURN_STATUS:8         ;

_P17_IO_WENT_BACK_LOW:
   ; need to calculate the pulse width in ms... need to divide calculated clocks by 16
   add.w   #22,r2                     ; (4) ; need to add the rest of the overhead(*-1 loop above) in...
   shlr.w   r2                        ; (2)
   shlr.w   r2                        ; (2)
   shlr.w   r2                        ; (2)
   shlr.w   r2                        ; (2) / 16 (for clock speed)
   
;        aPulses(iPin) = iPinLoopCnt ; convert loop count to pulse width...
   mov.w   r2,@er3                     ; Save away the value
   
;       bMask = bMask & ~bMaskBit    ; turn off waiting for this one...
   or      r1l,r1l                     ; (2) see if we are done or not
;     wend
   bne      _PI7_WAIT_FOR_NEXT_IO_TO_GO_HIGH:16 ;(6)our mask has not gone to zero so wait for the next one.
   
_P17_RETURN_STATUS:   
   mov.b   r1l,@BPULSETIMEOUT
; finally transisition back to basic and return.
    return 