/* Automatically generated, do not edit */
#ifndef _CAFE_OPCODE_H_
#define _CAFE_OPCODE_H_
typedef enum {
  Halt,
  Call,
  Escape,
  Tail,
  Enter,
  Ret,
  Jmp,
  Drop,
  Dup,
  Pull,
  Rot,
  LdI,
  LdC,
  LdA,
  LdL,
  LdE,
  StL,
  StA,
  StE,
  Nth,
  StNth,
  Case,
  Alloc,
  I2f,
  F2i,
  AddI,
  AddF,
  LAdd,
  IncI,
  SubI,
  SubF,
  LSub,
  DecI,
  MulI,
  MulF,
  LMul,
  DivI,
  DivF,
  LDiv,
  RemI,
  RemF,
  LRem,
  Lft,
  LLft,
  Asr,
  Rgt,
  CmpI,
  LCmp,
  CmpF,
  Bz,
  Bnz,
  Bf,
  Bnf,
  Blt,
  Ble,
  Bge,
  Bgt,
  Cas,
  label,
  frame,
  illegalOp
} OpCode;

#endif //_CAFE_OPCODE_H_
