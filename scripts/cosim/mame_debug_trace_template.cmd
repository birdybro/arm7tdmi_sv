focus @@CPU@@
trace @@TRACE@@,@@CPU@@,noloop,{tracelog " COSIM pc=%08X cpsr=%08X r0=%08X r1=%08X r2=%08X r3=%08X r4=%08X r5=%08X r6=%08X r7=%08X r8=%08X r9=%08X r10=%08X r11=%08X r12=%08X r13=%08X r14=%08X\n",pc,cpsr,r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14}
g @@STOP@@
trace off,@@CPU@@
quit
