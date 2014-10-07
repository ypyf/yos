;*********************************************
;	Boot1.asm
; boot1是第一阶段的引导程序(bootloader)
; 它的主要工作是搜索并载入引导盘中的内核文件
; 然后开始第二阶段的引导过程
;*********************************************

bits	16	; 16位实模式

org	0	; 映像基址

start:	jmp	main	; 跳转到入口代码

;*********************************************
; BIOS Parameter Block
; BPB描述了磁盘的物理布局 （对于硬盘来说，它描述了分区）
; BPB位于引导扇区（1扇区）
; 当对软盘进行格式化的时候BPB信息就被写入了
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
bsFileSystem: 	        DB "FAT12   " ; 没有什么实际用途

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
; 读扇区中的数据
; CX = 需要读取的扇区数
; AX = 起始扇区
; ES:BX = 目地地址
;************************************************;

ReadSectors:
.MAIN:
		mov di, 0x0005 	; 尝试5次
.SECTORLOOP:
; 保存LBA_TO_CHS将使用的寄存器
		push    ax
		push    bx
		push    cx
		call    LBA_TO_CHS                          ; 转换后的CHS保存在一组变量中
		mov     ah, 0x02                            ; 功能号
		mov     al, 0x01                            ; 一次读取一个扇区
		mov     ch, BYTE [absoluteTrack]            ; 柱面/磁道号
		mov     cl, BYTE [absoluteSector]           ; 扇区号
		mov     dh, BYTE [absoluteHead]             ; 磁头号
		mov     dl, BYTE [bsDriveNumber]            ; 驱动器号
		int     0x13                                ; 中断
		jnc     .SUCCESS   	; 成功后跳转
		xor     ax, ax  	; 否则复位磁盘
		int     0x13		; 中断
		dec     di			; 尝试次数减1
; 恢复寄存器
		pop     cx
		pop     bx
		pop     ax
		jnz     .SECTORLOOP ; di != 0 再次尝试读盘
		int     0x18	; 否则执行ROM-BASIC
.SUCCESS:
		mov     si, msgProgress	; 成功后打印提示信息
		call    Print
; 恢复寄存器
		pop     cx
		pop     bx
		pop     ax
		add     bx, WORD [bpbBytesPerSector]        ; 更新缓冲区指针
		inc     ax                                  ; 扇区号加1
		loop    .MAIN                               ; cx != 0 读下一个扇区
		ret

;************************************************
; 簇号转换为逻辑块寻址(LBA). LBA的偏移从0开始
; 逻辑块是一个或多个扇区
; 我们约定每个逻辑块代表一个扇区
; FAT格式中，数据区的第一个簇的编号总是2
; LBA = (cluster - 2) * sectors per cluster
; AX = LBA
;************************************************

CLUSTER_TO_LBA:
		sub     ax, 0x0002                          ; 先将簇号转换为基于0的
		xor     cx, cx
		mov     cl, BYTE [bpbSectorsPerCluster]
		mul     cx									  ; 簇号乘以SPC
		add     ax, WORD [datasector]                 ; 加上数据区基址
		ret

;************************************************;
; 将LBA转换为CHS
; AX = LBA
; LBA地址存放在AX中
; 算法如下：
; S = (LBA MOD SPT) + 1
; H   = (LBA / SPT) MOD HPC)
; C  = LBA / (SPT* HPC))
; 由于Floppy只有一个盘，所以我们可以不区分Cylinder和Track
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
;	Bootloader入口
;*********************************************
main:

;----------------------------------------------------
; 将数据段寄存器设置到7C00H
;----------------------------------------------------
		cli						; disable interrupts
		mov ax, 0x07C0				; setup registers to point to our segment
		mov ds, ax
		mov es, ax
		mov fs, ax
		mov gs, ax

;----------------------------------------------------
; 创建堆栈
;----------------------------------------------------
		mov ax, 0x0000	; set the stack
		mov ss, ax
		mov sp, 0xFFFF
		sti 			; restore interrupts

;----------------------------------------------------
; 打印载入提示
;----------------------------------------------------
		mov si, msgLoading
		call Print

;----------------------------------------------------
; 载入根目录表(RDT)
;----------------------------------------------------
LOAD_ROOT:

; 计算根目录大小(in blocks)并保存在CX中
		xor cx, cx
		xor dx, dx
		mov ax, 0x0020                 ; 每项32字节
		mul WORD [bpbRootEntries]      ; 乘以目录项数
		div WORD [bpbBytesPerSector]   ; 除以每扇区字节数
		xchg ax, cx					   ; 结果保存到CX中

; 计算根目录位置并保存到AX中
		mov al, BYTE [bpbNumberOfFATs]          ; FAT个数
		mul WORD [bpbSectorsPerFAT]             ; 乘以每个FAT的扇区数
		mov WORD [sizeOfFAT], ax				; 保存以后使用
		add ax, WORD [bpbReservedSectors]       ; 加上保留扇区数
		mov WORD [datasector], ax              	; 用根目录位置加上根目录的大小
		add WORD [datasector], cx				; 将数据区起始位置保存到变量

; 读取根目录并载入到7C00:0200
; 这个位置正好紧接着引导代码
		mov bx, 0x0200
		call ReadSectors

;----------------------------------------------------
; 在根目录表中查找内核映像
;----------------------------------------------------

		mov     cx, WORD [bpbRootEntries] 	; 遍历根目录项
		mov     di, 0x0200   ; di指向根目录基址
.LOOP:
		push    cx	; 保存cx
		mov     cx, 0x000B  ; 文件名长度11
		mov     si, ImageName   ; 指定要查找的文件名
		push    di  ; 保存di
		rep  cmpsb 	; 比较字符串
		pop     di  ; 恢复di
		je      LOAD_FAT ; 若文件存在，载入FAT
		pop     cx ; 恢复循环变量
		add     di, 0x0020  ; 更新di（每个目录项32字节）
		loop    .LOOP ; 查找下一个目录项
		jmp     FAILURE

;----------------------------------------------------
; 载入FAT
;----------------------------------------------------

LOAD_FAT:
; 打印换行符
		mov     si, msgCRLF
		call    Print
; 获得内核映像的第一个簇号
; 这个字段在目录项中的偏移是0x1A
		mov     dx, WORD [di + 0x001A]
		mov     WORD [cluster], dx	; 将簇号保存到变量

; 同载入RDT一样,我们先计算表的大小,然后计算它的位置
; 计算FAT大小保存到CX中
		mov   cx, WORD [sizeOfFAT]

; 计算FAT起始位置
		mov     ax, WORD [bpbReservedSectors] 	; 越过引导扇区就是FAT的位置

; 同样将FAT读到偏移0x0200位置(7C00:0200)
; 实际上我们覆盖了之前存放的RDT的内容, 还记得吗,它原来也是放在这个位置的 但是我们现在已经不再需要它了 :)
		mov     bx, 0x0200
		call    ReadSectors

; 打印换行符
		mov     si, msgCRLF
		call    Print

; 下一步将内核映像载入内存(0050:0000)
;  这个位置正好是无人使用的区域(参见BIOS内存映射)
		mov     ax, 0x0050
		mov     es, ax       	; 初始化数据段寄存器 (ES:DI将指向拷贝的目的缓冲区)
		mov     bx, 0x0000    	; 初始化数据指针
push    bx 			 	; 数据指针入栈

;----------------------------------------------------
; 前面的所有代码都是准备工作
; 现在到了第一阶段最后一步,也是这个阶段的主要目的
; 载入内核映像
;----------------------------------------------------

LOAD_IMAGE:
		mov     ax, WORD [cluster]                  ; 当前簇索引 => ax
		pop     bx                                  ; 恢复数据指针,从新的bx位置开始写读取的磁盘数据
		call    CLUSTER_TO_LBA                      ; 簇号转换为LBA, ax为输入参数
		xor     cx, cx								; cx清零
		mov     cl, BYTE [bpbSectorsPerCluster]     ; 一次要读取的扇区数(即1个簇所占扇区数)
		call    ReadSectors							; 读取一个簇
		push    bx ; 保存数据缓冲区指针

; 计算下一个簇号

; 首先计算给定的簇在FAT中的偏移
; 注意FAT每个表项是12位
; 算法:
; offset = n * 12 / 8 = n/2 + n, 这里n是簇号
		mov     ax, WORD [cluster]                   
		mov     cx, ax                               
		mov     dx, ax                        
		shr     dx, 0x0001       	; n/2
		add     cx, dx              ; n/2 + n
		mov     bx, 0x0200          ; 0x0200是FAT基址
		add     bx, cx              ; bx += 偏移

; 由于fat索引是12位的，超过了一个字节（8位），所以需要一次读取两个字节
		mov     dx, WORD [bx]

; 测试当前簇号的奇偶性
; 如果最低位是1,则是奇数,否则是偶数
		test ax, 0x0001 		
		jnz  .ODD_CLUSTER

; 偶数簇
.EVEN_CLUSTER:
		and     dx, 0000111111111111b 	; 取低12位数据
		jmp     .DONE

; 奇数簇
.ODD_CLUSTER:
		shr     dx, 0x0004 	; 取高12位数据

.DONE:
		mov     WORD [cluster], dx                  ; 保存下一个簇信息
; 如果不是文件结束标志,继续载入下一个簇
		cmp     dx, 0x0FF0                          
		jb      LOAD_IMAGE

; 完成载入任务
DONE:
; 打印换行符
		mov     si, msgCRLF
		call    Print

; 长跳转到0050:0000,这里就是我们新载入的内核映像(stage2)的基址
		push    WORD 0x0050
		push    WORD 0x0000
		retf

; 失败处理
FAILURE:
; 打印错误信息
		mov     si, msgFailure
		call    Print
		mov     ah, 0x00
		int     0x16                                ; 等待用户按键
		int     0x19                                ; 热重启

absoluteSector db 0x00
absoluteHead   db 0x00
absoluteTrack  db 0x00
ImageName   db "KRNLDR  SYS" ; 将要载入的内核文件名(必须正好是11个字节)
sizeOfFAT	dw 0x0000	; FAT的大小
datasector  dw 0x0000	; 磁盘数据区基址
cluster     dw 0x0000
msgLoading  db 0x0D, 0x0A, "Loading Boot Image ", 0x0D, 0x0A, 0x00
msgCRLF     db 0x0D, 0x0A, 0x00
msgProgress db ".", 0x00
msgFailure  db 0x0D, 0x0A, "ERROR : File KRNLDR.SYS Not Found. Press Any Key to Reboot", 0x0A, 0x00

TIMES 510-($-$$) DB 0
DW 0xAA55
