
nasm -f bin Boot1.asm -o Boot1.bin

rem ʵ����ֻ��Ҫ�������ļ��еĲ��ִ��뿽���������϶�Ӧλ�ü��ɣ�������ǳ���(BPB)
PARTCOPY Boot1.bin 0 3 -f0 0
PARTCOPY Boot1.bin 3E 1C2 -f0 3E 

pause