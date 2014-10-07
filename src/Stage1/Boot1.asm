;*********************************************
;	Boot1.asm
; boot1�ǵ�һ�׶ε���������(bootloader)
; ������Ҫ�����������������������е��ں��ļ�
; Ȼ��ʼ�ڶ��׶ε���������
;*********************************************

bits	16	; 16λʵģʽ

org	0	; ӳ���ַ

start:	jmp	main	; ��ת����ڴ���

;*********************************************
; BIOS Parameter Block
; BPB�����˴��̵������� ������Ӳ����˵���������˷�����
; BPBλ������������1������
; �������̽��и�ʽ����ʱ��BPB��Ϣ�ͱ�д����
;*********************************************

; BPB Begins 3 bytes from start. We do a far jump, which is 3 bytes in size.
; If you use a short jump, add a "nop" after it to offset the 3rd byte.

bpbOEM			db "My OS   "			; OEM identifier (Cannot exceed 8 bytes!)
bpbBytesPerSector:  	DW 512
bpbSectorsPerCluster: 	DB 1
bpbReservedSectors: 	DW 1
bpbNumberOfFATs: 	DB 2
bpbRootEntries: 	DW 224
bpbTotalSectors: 	DW 2880
bpbMedia: 		DB 0xf8  ;; 0xF1
bpbSectorsPerFAT: 	DW 9
bpbSectorsPerTrack: 	DW 18
bpbHeadsPerCylinder: 	DW 2
bpbHiddenSectors: 	DD 0
bpbTotalSectorsBig:     DD 0
bsDriveNumber: 	        DB 0
bsUnused: 		DB 0
bsExtBootSignature: 	DB 0x29
bsSerialNumber:	        DD 0xa0a1a2a3
bsVolumeLabel: 	        DB "MOS FLOPPY "
bsFileSystem: 	        DB "FAT12   " ; û��ʲôʵ����;

;************************************************;
;	Prints a string
;	DS=>SI: 0 terminated string
;************************************************;
Print:
		lodsb				; load next byte from string from SI to AL
		or	al, al			; Does AL=0?
		jz	PrintDone		; Yep, null terminator found-bail out
		mov	ah, 0eh			; Nope-Print the character
		int	10h
		jmp	Print			; Repeat until null terminator found
PrintDone:
		ret				; we are done, so return

;************************************************;
; �������е�����
; CX = ��Ҫ��ȡ��������
; AX = ��ʼ����
; ES:BX = Ŀ�ص�ַ
;************************************************;

ReadSectors:
.MAIN:
		mov di, 0x0005 	; ����5��
.SECTORLOOP:
; ����LBA_TO_CHS��ʹ�õļĴ���
		push    ax
		push    bx
		push    cx
		call    LBA_TO_CHS                          ; ת�����CHS������һ�������
		mov     ah, 0x02                            ; ���ܺ�
		mov     al, 0x01                            ; һ�ζ�ȡһ������
		mov     ch, BYTE [absoluteTrack]            ; ����/�ŵ���
		mov     cl, BYTE [absoluteSector]           ; ������
		mov     dh, BYTE [absoluteHead]             ; ��ͷ��
		mov     dl, BYTE [bsDriveNumber]            ; ��������
		int     0x13                                ; �ж�
		jnc     .SUCCESS   	; �ɹ�����ת
		xor     ax, ax  	; ����λ����
		int     0x13		; �ж�
		dec     di			; ���Դ�����1
; �ָ��Ĵ���
		pop     cx
		pop     bx
		pop     ax
		jnz     .SECTORLOOP ; di != 0 �ٴγ��Զ���
		int     0x18	; ����ִ��ROM-BASIC
.SUCCESS:
		mov     si, msgProgress	; �ɹ����ӡ��ʾ��Ϣ
		call    Print
; �ָ��Ĵ���
		pop     cx
		pop     bx
		pop     ax
		add     bx, WORD [bpbBytesPerSector]        ; ���»�����ָ��
		inc     ax                                  ; �����ż�1
		loop    .MAIN                               ; cx != 0 ����һ������
		ret

;************************************************
; �غ�ת��Ϊ�߼���Ѱַ(LBA). LBA��ƫ�ƴ�0��ʼ
; �߼�����һ����������
; ����Լ��ÿ���߼������һ������
; FAT��ʽ�У��������ĵ�һ���صı������2
; LBA = (cluster - 2) * sectors per cluster
; AX = LBA
;************************************************

CLUSTER_TO_LBA:
		sub     ax, 0x0002                          ; �Ƚ��غ�ת��Ϊ����0��
		xor     cx, cx
		mov     cl, BYTE [bpbSectorsPerCluster]
		mul     cx									  ; �غų���SPC
		add     ax, WORD [datasector]                 ; ������������ַ
		ret

;************************************************;
; ��LBAת��ΪCHS
; AX = LBA
; LBA��ַ�����AX��
; �㷨���£�
; S = (LBA MOD SPT) + 1
; H   = (LBA / SPT) MOD HPC)
; C  = LBA / (SPT* HPC))
; ����Floppyֻ��һ���̣��������ǿ��Բ�����Cylinder��Track
;************************************************;

LBA_TO_CHS:
		xor     dx, dx                              ; prepare dx:ax for operation
		div     WORD [bpbSectorsPerTrack]           ; calculate
		inc     dl                                  ; adjust for sector 0
		mov     BYTE [absoluteSector], dl
		xor     dx, dx                              ; prepare dx:ax for operation
		div     WORD [bpbHeadsPerCylinder]          ; calculate
		mov     BYTE [absoluteHead], dl
		mov     BYTE [absoluteTrack], al
		ret

;*********************************************
;	Bootloader���
;*********************************************
main:

;----------------------------------------------------
; �����ݶμĴ������õ�7C00H
;----------------------------------------------------
		cli						; disable interrupts
		mov ax, 0x07C0				; setup registers to point to our segment
		mov ds, ax
		mov es, ax
		mov fs, ax
		mov gs, ax

;----------------------------------------------------
; ������ջ
;----------------------------------------------------
		mov ax, 0x0000	; set the stack
		mov ss, ax
		mov sp, 0xFFFF
		sti 			; restore interrupts

;----------------------------------------------------
; ��ӡ������ʾ
;----------------------------------------------------
		mov si, msgLoading
		call Print

;----------------------------------------------------
; �����Ŀ¼��(RDT)
;----------------------------------------------------
LOAD_ROOT:

; �����Ŀ¼��С(in blocks)��������CX��
		xor cx, cx
		xor dx, dx
		mov ax, 0x0020                 ; ÿ��32�ֽ�
		mul WORD [bpbRootEntries]      ; ����Ŀ¼����
		div WORD [bpbBytesPerSector]   ; ����ÿ�����ֽ���
		xchg ax, cx					   ; ������浽CX��

; �����Ŀ¼λ�ò����浽AX��
		mov al, BYTE [bpbNumberOfFATs]          ; FAT����
		mul WORD [bpbSectorsPerFAT]             ; ����ÿ��FAT��������
		mov WORD [sizeOfFAT], ax				; �����Ժ�ʹ��
		add ax, WORD [bpbReservedSectors]       ; ���ϱ���������
		mov WORD [datasector], ax              	; �ø�Ŀ¼λ�ü��ϸ�Ŀ¼�Ĵ�С
		add WORD [datasector], cx				; ����������ʼλ�ñ��浽����

; ��ȡ��Ŀ¼�����뵽7C00:0200
; ���λ�����ý�������������
		mov bx, 0x0200
		call ReadSectors

;----------------------------------------------------
; �ڸ�Ŀ¼���в����ں�ӳ��
;----------------------------------------------------

		mov     cx, WORD [bpbRootEntries] 	; ������Ŀ¼��
		mov     di, 0x0200   ; diָ���Ŀ¼��ַ
.LOOP:
		push    cx	; ����cx
		mov     cx, 0x000B  ; �ļ�������11
		mov     si, ImageName   ; ָ��Ҫ���ҵ��ļ���
		push    di  ; ����di
		rep  cmpsb 	; �Ƚ��ַ���
		pop     di  ; �ָ�di
		je      LOAD_FAT ; ���ļ����ڣ�����FAT
		pop     cx ; �ָ�ѭ������
		add     di, 0x0020  ; ����di��ÿ��Ŀ¼��32�ֽڣ�
		loop    .LOOP ; ������һ��Ŀ¼��
		jmp     FAILURE

;----------------------------------------------------
; ����FAT
;----------------------------------------------------

LOAD_FAT:
; ��ӡ���з�
		mov     si, msgCRLF
		call    Print
; ����ں�ӳ��ĵ�һ���غ�
; ����ֶ���Ŀ¼���е�ƫ����0x1A
		mov     dx, WORD [di + 0x001A]
		mov     WORD [cluster], dx	; ���غű��浽����

; ͬ����RDTһ��,�����ȼ����Ĵ�С,Ȼ���������λ��
; ����FAT��С���浽CX��
		mov   cx, WORD [sizeOfFAT]

; ����FAT��ʼλ��
		mov     ax, WORD [bpbReservedSectors] 	; Խ��������������FAT��λ��

; ͬ����FAT����ƫ��0x0200λ��(7C00:0200)
; ʵ�������Ǹ�����֮ǰ��ŵ�RDT������, ���ǵ���,��ԭ��Ҳ�Ƿ������λ�õ� �������������Ѿ�������Ҫ���� :)
		mov     bx, 0x0200
		call    ReadSectors

; ��ӡ���з�
		mov     si, msgCRLF
		call    Print

; ��һ�����ں�ӳ�������ڴ�(0050:0000)
;  ���λ������������ʹ�õ�����(�μ�BIOS�ڴ�ӳ��)
		mov     ax, 0x0050
		mov     es, ax       	; ��ʼ�����ݶμĴ��� (ES:DI��ָ�򿽱���Ŀ�Ļ�����)
		mov     bx, 0x0000    	; ��ʼ������ָ��
push    bx 			 	; ����ָ����ջ

;----------------------------------------------------
; ǰ������д��붼��׼������
; ���ڵ��˵�һ�׶����һ��,Ҳ������׶ε���ҪĿ��
; �����ں�ӳ��
;----------------------------------------------------

LOAD_IMAGE:
		mov     ax, WORD [cluster]                  ; ��ǰ������ => ax
		pop     bx                                  ; �ָ�����ָ��,���µ�bxλ�ÿ�ʼд��ȡ�Ĵ�������
		call    CLUSTER_TO_LBA                      ; �غ�ת��ΪLBA, axΪ�������
		xor     cx, cx								; cx����
		mov     cl, BYTE [bpbSectorsPerCluster]     ; һ��Ҫ��ȡ��������(��1������ռ������)
		call    ReadSectors							; ��ȡһ����
		push    bx ; �������ݻ�����ָ��

; ������һ���غ�

; ���ȼ�������Ĵ���FAT�е�ƫ��
; ע��FATÿ��������12λ
; �㷨:
; offset = n * 12 / 8 = n/2 + n, ����n�Ǵغ�
		mov     ax, WORD [cluster]                   
		mov     cx, ax                               
		mov     dx, ax                        
		shr     dx, 0x0001       	; n/2
		add     cx, dx              ; n/2 + n
		mov     bx, 0x0200          ; 0x0200��FAT��ַ
		add     bx, cx              ; bx += ƫ��

; ����fat������12λ�ģ�������һ���ֽڣ�8λ����������Ҫһ�ζ�ȡ�����ֽ�
		mov     dx, WORD [bx]

; ���Ե�ǰ�غŵ���ż��
; ������λ��1,��������,������ż��
		test ax, 0x0001 		
		jnz  .ODD_CLUSTER

; ż����
.EVEN_CLUSTER:
		and     dx, 0000111111111111b 	; ȡ��12λ����
		jmp     .DONE

; ������
.ODD_CLUSTER:
		shr     dx, 0x0004 	; ȡ��12λ����

.DONE:
		mov     WORD [cluster], dx                  ; ������һ������Ϣ
; ��������ļ�������־,����������һ����
		cmp     dx, 0x0FF0                          
		jb      LOAD_IMAGE

; �����������
DONE:
; ��ӡ���з�
		mov     si, msgCRLF
		call    Print

; ����ת��0050:0000,�������������������ں�ӳ��(stage2)�Ļ�ַ
		push    WORD 0x0050
		push    WORD 0x0000
		retf

; ʧ�ܴ���
FAILURE:
; ��ӡ������Ϣ
		mov     si, msgFailure
		call    Print
		mov     ah, 0x00
		int     0x16                                ; �ȴ��û�����
		int     0x19                                ; ������

absoluteSector db 0x00
absoluteHead   db 0x00
absoluteTrack  db 0x00
ImageName   db "KRNLDR  SYS" ; ��Ҫ������ں��ļ���(����������11���ֽ�)
sizeOfFAT	dw 0x0000	; FAT�Ĵ�С
datasector  dw 0x0000	; ������������ַ
cluster     dw 0x0000
msgLoading  db 0x0D, 0x0A, "Loading Boot Image ", 0x0D, 0x0A, 0x00
msgCRLF     db 0x0D, 0x0A, 0x00
msgProgress db ".", 0x00
msgFailure  db 0x0D, 0x0A, "ERROR : File KRNLDR.SYS Not Found. Press Any Key to Reboot", 0x0A, 0x00

TIMES 510-($-$$) DB 0
DW 0xAA55
