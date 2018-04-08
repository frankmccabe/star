//
// Created by Francis McCabe on 3/8/18.
//

#include <strP.h>
#include <arithP.h>
#include <stringBuffer.h>
#include <array.h>
#include <assert.h>
#include <tpl.h>
#include "stringops.h"
#include "arithmetic.h"

ReturnStatus g__str_eq(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen, rlen;
  const char *lhs = stringVal(Arg1, &llen);
  const char *rhs = stringVal(Arg2, &rlen);

  if (llen == rlen) {
    for (integer ix = 0; ix < llen; ix++) {
      if (lhs[ix] != rhs[ix]) {
        ReturnStatus rt = {.ret=Ok, .rslt=falseEnum};
        return rt;
      }
    }
    ReturnStatus rt = {.ret=Ok, .rslt=trueEnum};
    return rt;
  } else {
    ReturnStatus rt = {.ret=Ok, .rslt=falseEnum};
    return rt;
  }
}

// Lexicographic comparison
ReturnStatus g__str_lt(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen, rlen;
  const char *lhs = stringVal(Arg1, &llen);
  const char *rhs = stringVal(Arg2, &rlen);

  integer mlen = minimum(llen, rlen);

  integer li = 0;
  integer ri = 0;

  while (li < llen && ri < rlen) {
    codePoint chl = nextCodePoint(lhs, &li, llen);
    codePoint ch2 = nextCodePoint(rhs, &ri, rlen);

    if (chl < ch2) {
      ReturnStatus rt = {.ret=Ok, .rslt=trueEnum};
      return rt;
    } else if (chl > ch2) {
      ReturnStatus rt = {.ret=Ok, .rslt=falseEnum};
      return rt;
    }
  }
  if (li < llen) { // There is more on the right, so the left counts as being smaller
    ReturnStatus rt = {.ret=Ok, .rslt=trueEnum};
    return rt;
  } else {
    ReturnStatus rt = {.ret=Ok, .rslt=falseEnum};
    return rt;
  }
}

ReturnStatus g__str_ge(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen, rlen;
  const char *lhs = stringVal(Arg1, &llen);
  const char *rhs = stringVal(Arg2, &rlen);

  integer mlen = minimum(llen, rlen);

  integer li = 0;
  integer ri = 0;

  while (li < llen && ri < rlen) {
    codePoint chl = nextCodePoint(lhs, &li, llen);
    codePoint ch2 = nextCodePoint(rhs, &ri, rlen);

    if (chl < ch2) {
      ReturnStatus rt = {.ret=Ok, .rslt=falseEnum};
      return rt;
    } else if (chl > ch2) {
      ReturnStatus rt = {.ret=Ok, .rslt=trueEnum};
      return rt;
    }
  }
  if (ri <= rlen) { // There is more on the right, so it counts as being bigger
    ReturnStatus rt = {.ret=Ok, .rslt=trueEnum};
    return rt;
  } else {
    ReturnStatus rt = {.ret=Ok, .rslt=falseEnum};
    return rt;
  }
}

ReturnStatus g__str_hash(processPo p, ptrPo tos) {
  stringPo lhs = C_STR(tos[0]);

  if (lhs->hash == 0) {
    integer len;
    const char *str = stringVal(tos[0], &len);
    lhs->hash = uniNHash(str, len);
  }

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateInteger(processHeap(p), lhs->hash)};
  return rt;
}

ReturnStatus g__str_len(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateInteger(processHeap(p), len)};
  return rt;
}

ReturnStatus g__str2flt(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);
  double flt;
  retCode ret = parseDouble(str, len, &flt);

  ReturnStatus rt = {.ret=ret, .rslt=(termPo) allocateFloat(processHeap(p), flt)};
  return rt;
}

ReturnStatus g__str2int(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);
  integer ix = parseInteger(str, len);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateInteger(processHeap(p), ix)};
  return rt;
}

ReturnStatus g__str_gen(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);
  char rnd[MAXLINE];

  strMsg(rnd, NumberOf(rnd), "%d", randomInt());

  long bufLn = uniStrLen(rnd) + 1 + len;
  char buff[bufLn];
  uniNCpy(buff, bufLn, str, len);
  uniTack(buff, bufLn, rnd);
  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateString(processHeap(p), buff, uniStrLen(buff))};
  return rt;
}

ReturnStatus g__stringOf(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  termPo t = Arg1;
  integer depth = integerVal(Arg2);

  bufferPo strb = newStringBuffer();
  retCode ret = dispTerm(O_IO(strb), t, depth, False);

  integer oLen;
  const char *buff = getTextFromBuffer(&oLen, strb);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateString(processHeap(p), buff, oLen)};
  return rt;
}

ReturnStatus g__explode(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  integer len;
  const char *str = stringVal(Arg1, &len);
  integer chCount = countCodePoints(str, 0, len);

  heapPo H = processHeap(p);
  listPo list = allocateList(H, chCount, True);
  int root = gcAddRoot(H, (ptrPo) &list);

  integer pos = 0;
  for (integer ix = 0; ix < chCount; ix++) {
    assert(pos < len);
    codePoint cp = nextCodePoint(str, &pos, len);
    termPo el = (termPo) allocateInteger(H, (integer) cp);
    setNthEl(list, ix, el);
  }

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) list};
  gcReleaseRoot(H, 0);
  return rt;
}

ReturnStatus g__implode(processPo p, ptrPo tos) {
  listPo list = C_LIST(tos[0]);

  bufferPo strb = newStringBuffer();

  for (integer ix = 0; ix < listSize(list); ix++) {
    outChar(O_IO(strb), (codePoint) nthEl(list, ix));
  }

  integer oLen;
  const char *buff = getTextFromBuffer(&oLen, strb);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateString(processHeap(p), buff, oLen)};
  return rt;
}

ReturnStatus g__str_find(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  termPo Arg3 = tos[2];
  integer len;
  const char *str = stringVal(Arg1, &len);
  integer tlen;
  const char *tgt = stringVal(Arg2, &tlen);
  integer start = integerVal(Arg3);

  integer found = uniSearch(str, len, start, tgt, tlen);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateInteger(processHeap(p), found)};
  return rt;
}

ReturnStatus g__sub_str(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  termPo Arg3 = tos[2];
  integer len;
  const char *str = stringVal(Arg1, &len);
  integer start = integerVal(Arg2);
  integer count = integerVal(Arg3);

  char buff[count + 1];
  uniNCpy(buff, count + 1, &str[start], count);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateString(processHeap(p), buff, count)};
  return rt;
}

ReturnStatus g__str_split(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer len;
  const char *str = stringVal(Arg1, &len);
  integer start = integerVal(Arg2);

  char buff[len];
  uniNCpy(buff, len, str, len);

  heapPo H = processHeap(p);
  normalPo pair = allocateTpl(H, 2);
  int root = gcAddRoot(H, (ptrPo) &pair);

  termPo lhs = (termPo)allocateString(H, buff, start);
  setArg(pair, 0, lhs);

  termPo rhs = (termPo)allocateString(H, &buff[start], len - start);
  setArg(pair, 1, rhs);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) pair};
  gcReleaseRoot(H,root);
  return rt;
}

ReturnStatus g__str_concat(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen;
  const char *lhs = stringVal(Arg1, &llen);
  integer rlen;
  const char *rhs = stringVal(Arg2, &rlen);

  integer len = llen + rlen;
  char buff[len];
  uniNCpy(buff, len, lhs, llen);
  uniNCpy(&buff[llen], len - llen, rhs, rlen);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateString(processHeap(p), buff, len)};
  return rt;
}

ReturnStatus g__str_start(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen;
  const char *lhs = stringVal(Arg1, &llen);
  integer rlen;
  const char *rhs = stringVal(Arg2, &rlen);

  ReturnStatus rt = {.ret=Ok, .rslt=(uniIsPrefix(lhs, llen, rhs, rlen) ? trueEnum : falseEnum)};
  return rt;
}

ReturnStatus g__str_multicat(processPo p, ptrPo tos) {
  listPo list = C_LIST(tos[0]);

  bufferPo strb = newStringBuffer();

  for (integer ix = 0; ix < listSize(list); ix++) {
    integer elen;
    const char *elTxt = stringVal(nthEl(list, ix), &elen);
    outText(O_IO(strb), elTxt, elen);
  }

  integer oLen;
  const char *buff = getTextFromBuffer(&oLen, strb);

  ReturnStatus rt = {.ret=Ok, .rslt=(termPo) allocateString(processHeap(p), buff, oLen)};
  return rt;
}