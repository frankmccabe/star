//
// Created by Francis McCabe on 5/12/20.
//

#ifndef STAR_X64OPS_H
#define STAR_X64OPS_H

// GP registers
#define RAX (0)
#define RBX (1)
#define RCX (2)
#define RDX (3)
#define RBP (4)
#define RSI (5)
#define RDI (6)
#define RSP (7)
#define R8 (8)
#define R9 (9)
#define R10 (10)
#define R11 (11)
#define R12 (12)
#define R13 (13)
#define R14 (14)
#define R15 (15)

// Prefixes
#define LOCK_PR (0xF0)
#define REPNZ_PR (0xF2)
#define REP_PR (0xF3)
#define OP_SIZE_PR (0x66)
#define ADD_SIZE_PR (0x67)

#define X64MOV(Dst,Src)
#define X64CMOV(Dst,Src)
#define X64XCHG(Dst,Src)
#define X64PUSH(Src)
#define X64POP(Dst)
#define X64ADD(Dst,Src)
#define X64ADDC(Dst,Src)
#define X64SUB(Dst,Src)
#define X64SBC(Dst,Src)
#define X64MUL(Dst,Src)
#define X64IMUL(Dst,Src)
#define X64INC(Dst,Src)
#define X64DEC(Dst,Src)
#define X64NEG(Dst)
#define X64CMP(Dst,Src)
#define X64AND(Dst,Src)
#define X64OR(Dst,Src)
#define X64XOR(Dst,Src)
#define X64NOT(Dst,Src)
#define X64SHR(Dst,Src)
#define X64SAR(Dst,Src)
#define X64SHL(Dst,Src)
#define X64SAL(Dst,Src)
#define X64ROR(Dst,Src)
#define X64ROL(Dst,Src)
#define X64RCR(Dst,Src)
#define X64RCL(Dst,Src)
#define X64BT(Dst,Src)
#define X64BTS(Dst,Src)
#define X64BTR(Dst,Src)
#define X64JMP(Dst,Src)
#define X64JE(Dst,Src)
#define X64JNE(Dst,Src)
#define X64JC(Dst,Src)
#define X64JNC(Dst,Src)
#define X64J(Dst,Src)
#define X64CALL(Dst,Src)
#define X64RET(Dst,Src)
#define X64NOP(Dst,Src)
#define X64LOOP(Dst,Src)
#define X64LOOPE(Dst,Src)
#define X64LOOPNE(Dst,Src)
#define X64CPUID(Dst)

#endif //STAR_X64OPS_H
