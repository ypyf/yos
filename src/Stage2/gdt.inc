;*************************************************
;	Gdt.inc
; ������GDT���ݺ�һЩ����
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
	lgdt 	[toc]        ; ����GDT
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

; toc�е����ݽ�����GDTR�Ĵ���
; GDTR��һ��48λ�Ĵ���(6���ֽ�),��GDT�Ĵ�С(2���ֽ�)��GDT�Ļ�ַ(4���ֽ�)���
; ע��GDTR��ַ�������һ���ֽڲ�ʹ��(toc�ĵ�6���ֽ�),��0���
toc: 
	dw gdt_end - gdt_begin - 1 	; GDT��С(limit)
	dd gdt_begin 				; GDT��ַ

; �������������GDT�е�ƫ��,�������ñ���ģʽ�µĶ�ѡ����(�����ڶμĴ�����)
%define NULL_DESC 0
%define CODE_DESC 0x8
%define DATA_DESC 0x10

%endif ;GDT_INC



