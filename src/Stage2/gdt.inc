;*************************************************
;	Gdt.inc
; 定义了GDT数据和一些例程
;*************************************************

%ifndef GDT_INC
%define GDT_INC

bits	16

;*******************************************
; InstallGDT()
;	- Install our GDT
;*******************************************

InstallGDT:
	cli                  ; clear interrupts
	pusha                ; save registers
	lgdt 	[toc]        ; 载入GDT
	sti	                 ; enable interrupts
	popa                 ; restore registers
	ret	                 ; All done!

;*******************************************
; Global Descriptor Table (GDT)
;*******************************************

gdt_begin: 
; null descriptor
	dd 0                
	dd 0 

; code segment descriptor
	dw 0FFFFh           ; limit low
	dw 0                ; base low
	db 0                ; base middle
	db 10011010b        ; access
	db 11001111b        ; granularity
	db 0                ; base high

; data segment descriptor
	dw 0FFFFh           ; limit low (Same as code)10:56 AM 7/8/2007
	dw 0                ; base low
	db 0                ; base middle
	db 10010010b        ; access
	db 11001111b        ; granularity
	db 0                ; base high
gdt_end:

; toc中的内容将载入GDTR寄存器
; GDTR是一个48位寄存器(6个字节),由GDT的大小(2个字节)和GDT的基址(4个字节)组成
; 注意GDTR基址部分最高一个字节不使用(toc的第6个字节),用0填充
toc: 
	dw gdt_end - gdt_begin - 1 	; GDT大小(limit)
	dd gdt_begin 				; GDT基址

; 定义段描述符在GDT中的偏移,用于设置保护模式下的段选择器(保存在段寄存器中)
%define NULL_DESC 0
%define CODE_DESC 0x8
%define DATA_DESC 0x10

%endif ;GDT_INC




