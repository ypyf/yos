
nasm -f bin Boot1.asm -o Boot1.bin

rem 实际上只需要将镜像文件中的部分代码拷贝到磁盘上对应位置即可，其余的是常量(BPB)
PARTCOPY Boot1.bin 0 3 -f0 0
PARTCOPY Boot1.bin 3E 1C2 -f0 3E 

pause