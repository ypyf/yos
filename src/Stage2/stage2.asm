
;*******************************************************
;
;	Stage2.asm
;		Stage2 Bootloader
;
;	OS Development Series
;*******************************************************

bits	16

; 根据BIOS的内存映射,0x500到0x7bff是未使用数据区
; stage1将stage2载入到0x500这个位置
org 0x500

jmp	main				; 跳转到入口点

;*******************************************************
; 预处理指令包含文件
;*******************************************************

%include "stdio.inc"		; 基本I/O例程
%include "gdt.inc"			; GDT例程
%include "a20.inc"			; 开启a20地址线的例程

;*******************************************************
;	提示字符串
;*******************************************************

		LoadingMsg db "Preparing to load operating system...", 0x0D, 0x0A, 0x00

;*******************************************************
;	STAGE 2 ENTRY POINT
;
;		-Store BIOS information
;		-Load Kernel
;		-Install GDT; go into protected mode (pmode)
;		-Jump to Stage 3
;*******************************************************

main:

;-------------------------------;
;  设置段寄存器与堆栈				;
;-------------------------------;

		cli					; 清除中断
		xor	ax, ax			; 数据段指向0
		mov	ds, ax			; ds = 0
		mov	es, ax			; es = 0
		mov	ax, 0x9000		; 堆栈范围:0x9000-0xffff
		mov	ss, ax			; ss = 0x9000
		mov	sp, 0xFFFF		; sp = 0xffff
		sti					; 开启中断(我们需要调用BIOS中断)

;-------------------------------;
;  打印提示消息					;
;-------------------------------;

		mov	si, LoadingMsg
		call Puts16

;-------------------------------;
;  安装GDT						;
;-------------------------------;

		call InstallGDT

;-------------------------------;
;   开启A20地址线					;
;-------------------------------;

		call EnableA20_KKbrd_Out

;-------------------------------;
;  进入保护模式					;
;-------------------------------;

		cli					; 清除中断
		mov	eax, cr0		; cr0 => eax
		or	eax, 1			; 设置cr0的PE_BIT(bit 0)进入保护模式
		mov	cr0, eax

		jmp	CODE_DESC:Stage3	; 通过jmp指令更新CS,从而进入32位代码段

; 注意，此时请不要开启中断,否则将产生Triple Fault

;******************************************************
;	stage3(32bit)入口点
;******************************************************

bits 32

Stage3:

;-------------------------------;
;  设置寄存器						;
;-------------------------------;

		mov ax, DATA_DESC		; 设置新的数据段选择器
		mov ds, ax
		mov ss, ax
		mov es, ax
		mov esp, 90000h			; 设置栈顶

		; 通过VGA硬件输出消息
		call   ClrScr32         ; 清屏
		mov    ebx, msg
		call   Puts32
		cli
		hlt


msg db  0x0A, 0x0A, 0x0A, "                           <[ Y OS ]>"
    db  0x0A, 0x0A,             "           Basic 32 bit graphics demo in Assembly Language", 0
