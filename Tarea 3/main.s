
GPIOA_BASE       EQU  0x40010800
GPIOA_CRL        EQU  0x00
GPIOA_IDR        EQU  0x08
GPIOA_ODR        EQU  0x0C

RCC_BASE         EQU  0x40021000
RCC_APB2ENR      EQU  0x18

SRAM_START       EQU  0x20000100
NUM_COUNT        EQU  100

    AREA    |.data|, DATA, READWRITE
    ALIGN   4

flag_generated   DCD   0
flag_sorted      DCD   0
current_state    DCD   0
random_seed      DCD   0x12345678

    AREA    |.text|, CODE, READONLY
    THUMB
    EXPORT  main
    ENTRY

main PROC
    BL      System_Init
    BL      GPIO_Init
    BL      Variables_Init

Main_Loop
    BL      Read_Input_State
    
    LDR     R0, =current_state
    LDR     R1, [R0]
    
    CMP     R1, #0
    BEQ     Process_Init_State
    
    CMP     R1, #1
    BEQ     Process_Generate_State
    
    CMP     R1, #2
    BEQ     Process_Sort_State
    
    B       Main_Loop
    ENDP

System_Init PROC
    LDR     R0, =RCC_BASE
    LDR     R1, =RCC_APB2ENR
    ADD     R0, R0, R1
    LDR     R1, [R0]
    ORR     R1, R1, #0x04
    STR     R1, [R0]
    BX      LR
    ENDP

GPIO_Init PROC
    ; Configurar PA0 y PA1 como entradas
    LDR     R0, =GPIOA_BASE
    LDR     R1, =GPIOA_CRL
    ADD     R2, R0, R1
    LDR     R1, [R2]
    BIC     R1, R1, #0xFF
    ORR     R1, R1, #0x44
    STR     R1, [R2]
    
    ; Configurar PA5 como salida
    LDR     R1, [R2]
    BIC     R1, R1, #0xF00000
    ORR     R1, R1, #0x200000
    STR     R1, [R2]
    
    ; Apagar LED
    LDR     R1, =GPIOA_ODR
    ADD     R2, R0, R1
    LDR     R1, [R2]
    BIC     R1, R1, #0x20
    STR     R1, [R2]
    BX      LR
    ENDP

Variables_Init PROC
    LDR     R0, =flag_generated
    MOVS    R1, #0
    STR     R1, [R0]
    
    LDR     R0, =flag_sorted
    STR     R1, [R0]
    
    LDR     R0, =current_state
    STR     R1, [R0]
    BX      LR
    ENDP

Read_Input_State PROC
    LDR     R0, =GPIOA_BASE
    LDR     R1, =GPIOA_IDR
    ADD     R0, R0, R1
    LDR     R1, [R0]
    AND     R1, R1, #0x03
    
    LDR     R0, =current_state
    STR     R1, [R0]
    BX      LR
    ENDP

Process_Init_State PROC
    BL      LED_Off
    
    LDR     R0, =flag_generated
    MOVS    R1, #0
    STR     R1, [R0]
    
    LDR     R0, =flag_sorted
    STR     R1, [R0]
    
    BL      Delay
    B       Main_Loop
    ENDP

Process_Generate_State PROC
    LDR     R0, =flag_generated
    LDR     R1, [R0]
    CMP     R1, #1
    BEQ     Generate_Already_Done
    
    BL      Generate_Random_Numbers
    
    MOVS    R1, #1
    STR     R1, [R0]
    BL      LED_On

Generate_Already_Done
    BL      Read_Input_State
    LDR     R0, =current_state
    LDR     R1, [R0]
    CMP     R1, #0
    BEQ     Process_Init_State
    
    BL      Delay
    B       Main_Loop
    ENDP

Process_Sort_State PROC
    LDR     R0, =flag_generated
    LDR     R1, [R0]
    CMP     R1, #1
    BNE     Sort_Not_Ready
    
    LDR     R0, =flag_sorted
    LDR     R1, [R0]
    CMP     R1, #1
    BEQ     Sort_Already_Done
    
    BL      Sort_Numbers
    
    MOVS    R1, #1
    STR     R1, [R0]
    BL      LED_On
    B       Sort_Check_Return

Sort_Already_Done
    BL      LED_On

Sort_Check_Return
    BL      Read_Input_State
    LDR     R0, =current_state
    LDR     R1, [R0]
    CMP     R1, #0
    BEQ     Process_Init_State
    
    BL      Delay
    B       Main_Loop

Sort_Not_Ready
    B       Process_Init_State
    ENDP

Generate_Random_Numbers PROC
    PUSH    {R4-R7,LR}
    
    LDR     R4, =SRAM_START
    LDR     R5, =random_seed
    LDR     R6, [R5]
    MOVS    R7, #100

Generate_Loop
    LDR     R0, =1103515245
    MUL     R1, R6, R0
    LDR     R0, =12345
    ADD     R1, R1, R0
    
    LSRS    R0, R1, #16
    LDR     R2, =0xFFFF
    ANDS    R0, R0, R2
    
    STRH    R0, [R4], #2
    
    MOV     R6, R1
    
    SUBS    R7, R7, #1
    BNE     Generate_Loop
    
    STR     R6, [R5]
    POP     {R4-R7,PC}
    ENDP

Sort_Numbers PROC
    PUSH    {R4-R9,LR}
    
    LDR     R4, =SRAM_START
    MOVS    R5, #100
    
    SUBS    R6, R5, #1
    BEQ     Sort_End

Outer_Loop
    MOVS    R7, #0
    MOVS    R8, #0

Inner_Loop
    LDRH    R0, [R4, R7, LSL #1]
    ADDS    R9, R7, #1
    LDRH    R1, [R4, R9, LSL #1]
    
    CMP     R0, R1
    BLE     No_Swap
    
    STRH    R1, [R4, R7, LSL #1]
    STRH    R0, [R4, R9, LSL #1]
    MOVS    R8, #1

No_Swap
    ADDS    R7, R7, #1
    CMP     R7, R6
    BLT     Inner_Loop
    
    CMP     R8, #0
    BEQ     Sort_End
    
    SUBS    R6, R6, #1
    BNE     Outer_Loop

Sort_End
    POP     {R4-R9,PC}
    ENDP

LED_On PROC
    LDR     R0, =GPIOA_BASE
    LDR     R1, =GPIOA_ODR
    ADD     R0, R0, R1
    LDR     R1, [R0]
    ORR     R1, R1, #0x20
    STR     R1, [R0]
    BX      LR
    ENDP

LED_Off PROC
    LDR     R0, =GPIOA_BASE
    LDR     R1, =GPIOA_ODR
    ADD     R0, R0, R1
    LDR     R1, [R0]
    BIC     R1, R1, #0x20
    STR     R1, [R0]
    BX      LR
    ENDP

Delay PROC
    LDR     R0, =0x00010000
Delay_Loop
    SUBS    R0, R0, #1
    BNE     Delay_Loop
    BX      LR
    ENDP

    ALIGN
    END