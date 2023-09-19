;****************** Lab3.s ***************
; Program written by: Put your names here
; Date Created: 2/4/2017
; Last Modified: 1/4/2023
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: Two buttons and one LED)
;  Change is Button input  (1 means pressed, 0 means not pressed)
;  Breathe is Button input  (1 means pressed, 0 means not pressed)
;  LED is an output (1 activates external LED)
; Overall functionality of this system is to operate like this
;   1) Make LED an output and make Change and Breathe inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the Change button is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when Breathe Switch is pressed:


; ***********************************************
; CONSTANT DEFINITION 
; ***********************************************

; PortD device registers
GPIO_PORTE_DATA_R  		EQU 0x400243FC
GPIO_PORTE_DIR_R  		EQU 0x40024400
GPIO_PORTE_DEN_R   		EQU 0x4002451C
SYSCTL_RCGCGPIO_R  		EQU 0x400FE608

; LED pin config
GPIO_LED_DATA_R						EQU GPIO_PORTE_DATA_R			
GPIO_LED_PIN_MASK  					EQU 0x20

; CHANGE button config
; duty_cycle = cycle_unit * ratio
; Assuming ratio = percent / 10. This is to avoid using float number in program
; So if cycle_unit = 50, ratio = 3, means:
;		cycle = 50 * 3 = 150ms
;		duty cycle percentage = 10 * 3 = 30 (%)
GPIO_CHANGE_DATA_R					EQU GPIO_PORTE_DATA_R
GPIO_CHANGE_PIN_MASK				EQU	0x1

CHANGE_CYCLE_UNIT_DEFAULT 			EQU	50
CHANGE_DUTYCYCLE_RATIO_DEFAULT		EQU	3

; BREATHE button config
GPIO_BREATHE_DATA_R					EQU GPIO_PORTE_DATA_R
GPIO_BREATHE_PIN_MASK				EQU	0x4

BREATHE_CYCLE_UNIT_DEFAULT 			EQU	1
BREATHE_DUTYCYCLE_RATIO_DEFAULT		EQU	3
BREATHE_DUTYCYCLE_RATIO_INCREMENT	EQU 1


		IMPORT  TExaS_Init
        THUMB
        AREA    DATA, ALIGN=2
; ***********************************************
; GLOBAL VARIABLE
; ***********************************************
CHANGE_cycle_unit SPACE 4
CHANGE_dutycycle_ratio SPACE 4

BREATHE_dutycycle_ratio SPACE 4
BREATHE_brightness_isIncrease SPACE 4

       AREA    |.text|, CODE, READONLY, ALIGN=3
       THUMB
       EXPORT EID1
EID1   DCB "Mint",0  ;replace ABC123 with your EID
       EXPORT EID2
EID2   DCB "Mint",0  ;replace ABC123 with your EID
       ALIGN 4

     EXPORT  Start

	ALIGN 8


; ***********************************************
; Program starts
; ***********************************************
Start
; TExaS_Init sets bus clock at 80 MHz, interrupts, ADC1, TIMER3, TIMER5, and UART0
    MOV R0,#2  ;0 for TExaS oscilloscope, 1 for PORTE logic analyzer, 2 for Lab3 grader, 3 for none
    BL  TExaS_Init ;enables interrupts, prints the pin selections based on EID1 EID2
 ; Your Initialization goes here
	BL	GPIO_init
	BL	VARIABLE_init
	
loop  
	BL 	CHANGE_handle_status
	BL 	BREATHE_handle_status
	BL	LED_on
	BL	CHANGE_get_dutycycle	
	BL	delay_ms

	BL 	CHANGE_handle_status
	BL 	BREATHE_handle_status
	BL	LED_off
	BL	CHANGE_get_idlecycle
	BL	delay_ms

	B	loop

    
; ***********************************************
; Function definition 
; ***********************************************

; ARM Architecture Procedure Call Standard (AAPCS)
;     We use R0,R1,R2,R3 as input parameters
;     We use R0 as the return parameter.
;     We can freely use R0,R1,R2,R3,R12 without needing to push or pop.
;     We can use R4-R11, but must push the values at the start and pop the values at then end.
GPIO_init
	; Enable clock for Port D
	LDR R0,=SYSCTL_RCGCGPIO_R
	LDR R1,[R0]
	ORR R1,R1,#0x10	; bit 4 is PortE
	STR R1,[R0]
	NOP				; wait to stablize the clock
	NOP
	
	; Config PD0, PD2 as input. PD5 as output
	LDR R0,=GPIO_PORTE_DIR_R
	MOV R1,#0x20
	STR R1,[R0]
	
	; Enable PD0, PD2, PD5;
	LDR R0,=GPIO_PORTE_DEN_R
	MOV R1,#0x25
	STR R1,[R0]

	BX LR


VARIABLE_init
	LDR R1,=CHANGE_cycle_unit
	LDR R0,[R1]
	MOV R0,#CHANGE_CYCLE_UNIT_DEFAULT
	STR R0,[R1]

	LDR R1,=CHANGE_dutycycle_ratio
	LDR R0,[R1]
	MOV R0,#CHANGE_DUTYCYCLE_RATIO_DEFAULT
	STR R0,[R1]

	LDR R1,=BREATHE_dutycycle_ratio
	LDR R0,[R1]
	MOV R0,#BREATHE_DUTYCYCLE_RATIO_DEFAULT
	STR R0,[R1]
	
	LDR R1,=BREATHE_brightness_isIncrease
	LDR R0,[R1]
	MOV R0,#1
	STR R0,[R1]

	BX LR


delay_100ns		; Input: R0. Output: delay R0 * 100ns
	NOP
	NOP
	NOP
	NOP
	SUBS R0,R0,#1
	BNE	delay_100ns
	BX LR
	

delay_ms		; Input: R0 (ms)
	CMP R0,#0	; If R0 = 0ms then exit
	BEQ delay_ms_endloop
	PUSH {R4, LR}
	MOV R4,#10000
	MUL R0,R0,R4
delay_ms_loop
	SUBS R0,R0,#1
	BL delay_100ns
	BNE delay_ms_loop
	POP {R4, LR}
	BX LR
delay_ms_endloop


LED_on			; Input: none
	LDR R1,=GPIO_LED_DATA_R
	LDR R0,[R1]
	ORR R0,R0,#GPIO_LED_PIN_MASK
	STR R0,[R1]
	BX LR


LED_off			; Input: none
	LDR R1,=GPIO_LED_DATA_R
	LDR R0,[R1]
	BIC R0,R0,#GPIO_LED_PIN_MASK
	STR R0,[R1]
	BX LR


CHANGE_read		; Input: none. Output: boolean
	LDR R0,=GPIO_CHANGE_DATA_R
	LDR R0,[R0]
	AND R0,R0,#GPIO_CHANGE_PIN_MASK
	BX LR
	
	
	LTORG	; Allocate memory for variable and literal constants


CHANGE_waitRelease	; Input: none
	PUSH {LR}
CHANGE_waitRelease_loop
	BL CHANGE_read
	ANDS R0,#GPIO_CHANGE_PIN_MASK
	BNE CHANGE_waitRelease_loop
	POP {LR}
	BX LR


CHANGE_handle_event	; Input: none
	PUSH {LR}
	LDR R1,=CHANGE_dutycycle_ratio
	LDR R0,[R1]
	ADD R0,#2	; Increase dutycycle by 20%
CHANGE_handle_event_if	; If ratio > 100% then modulo 100
	CMP R0,#10
	BLE CHANGE_handle_event_endif
	SUBS R0,#10
CHANGE_handle_event_endif
	STR R0,[R1]
	POP{LR}
	BX LR


get_dutycycle	; Input: R0 (cycle_unit), R1 (cycle_ratio). Output: number
	MUL R0,R0,R1
	BX LR


get_idlecycle	; Input: R0 (cycle_unit), R1 (cycle_ratio). Output: number
	MOV R2,#10
	SUBS R1,R2,R1
	MUL R0,R0,R1
	BX LR


CHANGE_get_dutycycle	; Input: none. Output: number
	PUSH {LR}
	LDR R0,=CHANGE_cycle_unit
	LDR R0,[R0]
	LDR R1,=CHANGE_dutycycle_ratio
	LDR R1,[R1]
	BL get_dutycycle
	POP {LR}
	BX LR


CHANGE_get_idlecycle	; Input: none. Output: number
	PUSH {LR}
	LDR R0,=CHANGE_cycle_unit
	LDR R0,[R0]
	LDR R1,=CHANGE_dutycycle_ratio
	LDR R1,[R1]
	BL get_idlecycle
	POP{LR}
	BX LR


CHANGE_handle_status	; Input: none
	PUSH {LR}
	BL CHANGE_read
CHANGE_handle_status_if
	ANDS R0,#GPIO_CHANGE_PIN_MASK
	BEQ CHANGE_handle_status_endif
	BL CHANGE_waitRelease
	BL CHANGE_handle_event
CHANGE_handle_status_endif
	POP{LR}
	BX LR


LED_blink
	PUSH {LR}
	PUSH {R0, R1}
	PUSH {R0, R1}

	BL	LED_on
	POP {R0, R1}
	BL	get_dutycycle	
	BL	delay_ms

	BL	LED_off
	POP {R0, R1}
	BL	get_idlecycle
	BL	delay_ms
	POP{LR}
	BX LR


LED_BREATHE_PWM
	PUSH {LR}
	MOV R3,#10
LED_BREATHE_PWM_loop
	SUBS R3,R3,#1
	BEQ LED_BREATHE_PWM_endloop
	MOV R1,R0
	MOV R0,#BREATHE_CYCLE_UNIT_DEFAULT
	BL LED_blink
LED_BREATHE_PWM_endloop
	POP{LR}
	BX LR


BREATHE_read
	LDR R0,=GPIO_BREATHE_DATA_R
	LDR R0,[R0]
	AND R0,R0,#GPIO_BREATHE_PIN_MASK
	BX LR


BREATHE_update_brightness
	PUSH {LR}
	LDR R1,=BREATHE_dutycycle_ratio
	LDR R0,[R1]
	LDR R3,=BREATHE_brightness_isIncrease
	LDR R2,[R3]
BREATHE_update_brightness_if
	CMP R2,#1
	BNE BREATHE_update_brightness_else
	ADD R0,R0,#BREATHE_DUTYCYCLE_RATIO_INCREMENT
	STR R0,[R1]
	CMP R0,#10
	BLT BREATHE_update_brightness_endif
	MOV R2,#0
	STR R2,[R3]
	B 	BREATHE_update_brightness_endif
BREATHE_update_brightness_else
	SUB	R0,R0,#BREATHE_DUTYCYCLE_RATIO_INCREMENT
	STR R0,[R1]
	CMP R0,#0
	BGT BREATHE_update_brightness_endif
	MOV R2,#1
	STR R2,[R3]
BREATHE_update_brightness_endif
	POP{LR}
	BX LR


BREATHE_handle_status
	PUSH {R4, LR}
BREATHE_handle_status_loop
	BL 	BREATHE_read
	ANDS R0,R0,#GPIO_BREATHE_PIN_MASK
	BEQ BREATHE_handle_status_endloop
	LDR R0,=BREATHE_dutycycle_ratio
	LDR R0,[R0]
	BL 	LED_BREATHE_PWM
	BL 	BREATHE_update_brightness
	B 	BREATHE_handle_status_loop
BREATHE_handle_status_endloop
	POP{R4, LR}
	BX LR


   ALIGN 4   
; 256 points with values from 100 to 9900      
PerlinTable
     DCW 5880,6225,5345,3584,3545,674,5115,598,7795,3737,3775,2129,7527,9020,368,8713,5459,1478,4043,1248,2741,5536,406
     DCW 3890,1516,9288,904,483,980,7373,330,5766,9555,4694,9058,2971,100,1095,7641,2473,3698,9747,8484,7871,4579,1440
     DCW 521,1325,2282,6876,1363,3469,9173,5804,2244,3430,6761,866,4885,5306,6646,6531,2703,6799,2933,6416,2818,5230,5421
     DCW 1938,1134,6455,3048,5689,6148,8943,3277,4349,8866,4770,2397,8177,5191,8905,8522,4120,3622,1670,2205,1861,9479
     DCW 1631,9441,4005,5574,2167,2588,1057,2512,6263,138,8369,3163,2895,8101,3009,5153,7259,8063,3507,789,6570,7756,7603
     DCW 5268,5077,4541,7297,6187,3392,6378,3928,4273,7680,6723,7220,215,2550,2091,8407,8752,9670,4847,4809,291,7833,1555
     DCW 5727,4617,4923,9862,3239,3354,8216,8024,7986,2359,8790,1899,713,2320,751,7067,7335,1172,1708,8637,7105,6608,8254
     DCW 4655,9594,5919,177,1784,5995,6340,2780,8560,5957,3966,6034,6493,1746,6684,445,5038,942,1593,9785,827,3852,4234
     DCW 4311,3124,4426,8675,8981,6914,7182,4388,4081,8445,9517,3813,8828,9709,1402,9364,7488,9211,8139,5613,559,7412
     DCW 6952,6302,9326,3201,2052,5651,9096,9632,636,9249,4196,1976,7450,8292,1287,7029,7718,4158,6110,7144,3316,7909
     DCW 6838,4502,4732,2014,1823,4962,253,5842,9823,5383,9134,7948,3660,8598,4464,2665,1210,1019,2856,9402,5498,5000
     DCW 7565,3086,2627,8330,2435,6072,6991
; 100 numbers from 0 to 10000
; sinusoidal shape
  ALIGN 4
SinTable 
  DCW  5000, 5308, 5614, 5918, 6219, 6514, 6804, 7086, 7361, 7626
  DCW  7880, 8123, 8354, 8572, 8776, 8964, 9137, 9294, 9434, 9556
  DCW  9660, 9746, 9813, 9861, 9890, 9900, 9890, 9861, 9813, 9746
  DCW  9660, 9556, 9434, 9294, 9137, 8964, 8776, 8572, 8354, 8123
  DCW  7880, 7626, 7361, 7086, 6804, 6514, 6219, 5918, 5614, 5308
  DCW  5000, 4692, 4386, 4082, 3781, 3486, 3196, 2914, 2639, 2374
  DCW  2120, 1877, 1646, 1428, 1224, 1036,  863,  706,  566,  444
  DCW   340,  254,  187,  139,  110,  100,  110,  139,  187,  254
  DCW   340,  444,  566,  706,  863, 1036, 1224, 1428, 1646, 1877
  DCW  2120, 2374, 2639, 2914, 3196, 3486, 3781, 4082, 4386, 4692  

      
     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file

