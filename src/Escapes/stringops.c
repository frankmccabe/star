//
// Created by Francis McCabe on 3/8/18.
//

#include <strP.h>
#include <arithP.h>
#include <stringBuffer.h>
#include <array.h>
#include <assert.h>
#include <tpl.h>
#include <globals.h>
#include "stringops.h"
#include "arithmetic.h"

ReturnStatus g__str_eq(processPo p, ptrPo tos) {
  stringPo Arg1 = C_STR(tos[0]);
  stringPo Arg2 = C_STR(tos[1]);

  logical eq = sameString(Arg1, Arg2);

  return (ReturnStatus) {.ret=Ok, .result=(eq ? trueEnum : falseEnum)};
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
      return (ReturnStatus) {.ret=Ok, .result=trueEnum};
    } else if (chl > ch2) {
      return (ReturnStatus) {.ret=Ok, .result=falseEnum};
    }
  }
  if (li < llen) { // There is more on the right, so the left counts as being smaller
    return (ReturnStatus) {.ret=Ok, .result=trueEnum};
  } else {
    return (ReturnStatus) {.ret=Ok, .result=falseEnum};
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
      return (ReturnStatus) {.ret=Ok, .result=falseEnum};
    } else if (chl > ch2) {
      return (ReturnStatus) {.ret=Ok, .result=trueEnum};
    }
  }
  if (ri <= rlen) { // There is more on the right, so it counts as being bigger
    return (ReturnStatus) {.ret=Ok, .result=trueEnum};
  } else {
    return (ReturnStatus) {.ret=Ok, .result=falseEnum};
  }
}

ReturnStatus g__str_hash(processPo p, ptrPo tos) {
  stringPo lhs = C_STR(tos[0]);

  if (lhs->hash == 0) {
    integer len;
    const char *str = stringVal(tos[0], &len);
    lhs->hash = uniNHash(str, len);
  }

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateInteger(processHeap(p), lhs->hash)};
}

ReturnStatus g__str_len(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateInteger(processHeap(p), len)};
}

ReturnStatus g__str2flt(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);
  double flt;
  retCode ret = parseDouble(str, len, &flt);

  return (ReturnStatus) {.ret=ret,
    .result=(termPo) allocateFloat(processHeap(p), flt)};
}

ReturnStatus g__str2int(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);
  integer ix = parseInteger(str, len);

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateInteger(processHeap(p), ix)};
}

ReturnStatus g__str_gen(processPo p, ptrPo tos) {
  integer len;
  const char *str = stringVal(tos[0], &len);
  char rnd[MAXLINE];

  strMsg(rnd, NumberOf(rnd), "%S%d", str, minimum(len, NumberOf(rnd) - INT64_DIGITS), randomInt());

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateString(processHeap(p), rnd, uniStrLen(rnd))};
}

ReturnStatus g__stringOf(processPo p, ptrPo tos) {
  termPo Arg2 = tos[1];
  termPo t = tos[0];
  integer depth = integerVal(Arg2);

  bufferPo strb = newStringBuffer();
  retCode ret = dispTerm(O_IO(strb), t, 0, depth, False);

  integer oLen;
  const char *buff = getTextFromBuffer(strb, &oLen);

  ReturnStatus result = {.ret=ret,
    .result=(termPo) allocateString(processHeap(p), buff, oLen)};

  closeFile(O_IO(strb));
  return result;
}

ReturnStatus g__explode(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  integer len;
  const char *str = stringVal(Arg1, &len);
  integer chCount = countCodePoints(str, 0, len);

  heapPo H = processHeap(p);
  listPo list = allocateList(H, chCount);
  int root = gcAddRoot(H, (ptrPo) &list);

  integer pos = 0;
  for (integer ix = 0; ix < chCount; ix++) {
    assert(pos < len);
    codePoint cp = nextCodePoint(str, &pos, len);
    termPo el = (termPo) allocateInteger(H, (integer) cp);
    setNthEl(list, ix, el);
  }

  gcReleaseRoot(H, root);
  return (ReturnStatus) {.ret=Ok, .result=(termPo) list};
}

ReturnStatus g__implode(processPo p, ptrPo tos) {
  listPo list = C_LIST(tos[0]);

  bufferPo strb = newStringBuffer();

  for (integer ix = 0; ix < listSize(list); ix++) {
    outChar(O_IO(strb), (codePoint) integerVal(nthEl(list, ix)));
  }

  integer oLen;
  const char *buff = getTextFromBuffer(strb, &oLen);

  termPo result = (termPo) allocateString(processHeap(p), buff, oLen);

  closeFile(O_IO(strb));

  return (ReturnStatus) {.ret=Ok, .result=result};
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

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateInteger(processHeap(p), found)};
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

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateString(processHeap(p), buff, count)};
}

ReturnStatus g__str_hdtl(processPo p, ptrPo tos) {
  stringPo src = C_STR(tos[0]);
  integer len = stringLength(src);
  char str[len + 1];
  copyString2Buff(src, str, len + 1);
  heapPo H = processHeap(p);

  integer offset = 0;
  codePoint ch;
  retCode ret = nxtPoint(str, &offset, len, &ch);

  if (ret == Ok) {
    intPo chCode = allocateInteger(H, ch);
    int mark = gcAddRoot(H, (ptrPo) &chCode);
    stringPo rest = allocateString(H, &str[offset], len - offset);
    gcAddRoot(H, (ptrPo) &rest);
    normalPo pair = allocateTpl(H, 2);
    setArg(pair, 0, (termPo) chCode);
    setArg(pair, 1, (termPo) rest);
    gcReleaseRoot(H, mark);
    return (ReturnStatus) {.ret=Ok, .result=(termPo) pair};
  } else {
    return (ReturnStatus) {.ret=ret, .result=voidEnum};
  }
}

ReturnStatus g__str_cons(processPo p, ptrPo tos) {
  integer ch = integerVal(tos[0]);
  stringPo src = C_STR(tos[1]);
  integer len = stringLength(src);
  integer offset = 0;
  char str[len + 16];
  appendCodePoint(str, &offset, len + 16, (codePoint) ch);
  retCode ret = copyString2Buff(src, &str[offset], len + 16);
  heapPo H = processHeap(p);

  return (ReturnStatus) {.ret=ret,
    .result=(termPo) allocateString(processHeap(p), str, offset + len)};
}

ReturnStatus g__str_apnd(processPo p, ptrPo tos) {
  integer ch = integerVal(tos[1]);
  stringPo src = C_STR(tos[0]);
  integer len = stringLength(src);
  integer offset = len;
  char str[len + 16];
  copyString2Buff(src, str, len + 16);
  heapPo H = processHeap(p);

  retCode ret = appendCodePoint(str, &offset, len + 16, (codePoint) integerVal(tos[0]));

  return (ReturnStatus) {.ret=ret,
    .result=(termPo) allocateString(processHeap(p), str, offset)};
}

ReturnStatus g__str_back(processPo p, ptrPo tos) {
  stringPo src = C_STR(tos[0]);
  integer len = stringLength(src);
  char str[len + 1];
  copyString2Buff(src, str, len + 1);
  heapPo H = processHeap(p);

  integer offset = len;
  codePoint ch;
  retCode ret = prevPoint(str, &offset, &ch);

  if (ret == Ok) {
    intPo chCode = allocateInteger(H, ch);
    int mark = gcAddRoot(H, (ptrPo) &chCode);
    stringPo rest = allocateString(H, str, offset);
    gcAddRoot(H, (ptrPo) &rest);
    normalPo pair = allocateTpl(H, 2);
    setArg(pair, 0, (termPo) rest);
    setArg(pair, 1, (termPo) chCode);
    gcReleaseRoot(H, mark);
    return (ReturnStatus) {.ret=Ok, .result=(termPo) pair};
  } else {
    return (ReturnStatus) {.ret=ret, .result=voidEnum};
  }
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

  termPo lhs = (termPo) allocateString(H, buff, start);
  setArg(pair, 0, lhs);

  termPo rhs = (termPo) allocateString(H, &buff[start], len - start);
  setArg(pair, 1, rhs);

  gcReleaseRoot(H, root);
  return (ReturnStatus) {.ret=Ok, .result=(termPo) pair};
}

ReturnStatus g__str_concat(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen;
  const char *lhs = stringVal(Arg1, &llen);
  integer rlen;
  const char *rhs = stringVal(Arg2, &rlen);

  integer len = llen + rlen + 1;
  char buff[len];
  uniNCpy(buff, len, lhs, llen);
  uniNCpy(&buff[llen], len - llen, rhs, rlen);

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateString(processHeap(p), buff, llen + rlen)};
}

ReturnStatus g__str_splice(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  integer from = integerVal(tos[1]);
  integer cnt = integerVal(tos[2]);
  termPo Arg4 = tos[3];

  integer llen;
  const char *lhs = stringVal(Arg1, &llen);
  integer rlen;
  const char *rhs = stringVal(Arg4, &rlen);

  // Clamp the from and cnt values
  if (from < 0)
    from = 0;
  if (cnt < 0)
    cnt = 0;
  if (from > llen)
    from = llen;
  if (from + cnt > llen)
    cnt = llen - from;

  integer len = llen + rlen - cnt;
  char buff[len];
  uniNCpy(buff, len, lhs, from);
  uniNCpy(&buff[from], len - from, rhs, rlen);
  uniNCpy(&buff[from + rlen], len - from - rlen, &lhs[from + cnt], llen - from - cnt);

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateString(processHeap(p), buff, len)};
}

ReturnStatus g__str_start(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  termPo Arg2 = tos[1];
  integer llen;
  const char *lhs = stringVal(Arg1, &llen);
  integer rlen;
  const char *rhs = stringVal(Arg2, &rlen);

  return (ReturnStatus) {.ret=Ok,
    .result=(uniIsPrefix(lhs, llen, rhs, rlen) ? trueEnum : falseEnum)};
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
  const char *buff = getTextFromBuffer(strb, &oLen);

  ReturnStatus rt = {.ret=Ok,
    .result=(termPo) allocateString(processHeap(p), buff, oLen)};
  closeFile(O_IO(strb));
  return rt;
}

static retCode flatten(bufferPo str, normalPo ss) {
  integer cx = termArity(ss);
  retCode ret = Ok;

  for (integer ix = 0; ret == Ok && ix < cx; ix++) {
    termPo arg = nthArg(ss, ix);
    if (isString(arg)) {
      integer len;
      const char *elTxt = stringVal(arg, &len);
      ret = outText(O_IO(str), elTxt, len);
    } else if (isNormalPo(arg)) {
      ret = flatten(str, C_TERM(arg));
    } else if (isInteger(arg))
      ret = outChar(O_IO(str), integerVal(arg));
  }
  return ret;
}

ReturnStatus g__str_flatten(processPo p, ptrPo tos) {
  normalPo ss = C_TERM(tos[0]);
  bufferPo str = newStringBuffer();

  retCode ret = flatten(str, ss);

  if (ret == Ok) {
    integer oLen;
    const char *buff = getTextFromBuffer(str, &oLen);

    ReturnStatus rt = {.ret=Ok,
      .result=(termPo) allocateString(processHeap(p), buff, oLen)};
    closeFile(O_IO(str));
    return rt;
  } else {
    closeFile(O_IO(str));
    return (ReturnStatus) {.ret=ret, .result = voidEnum};
  }
}

ReturnStatus g__str_reverse(processPo p, ptrPo tos) {
  termPo Arg1 = tos[0];
  integer len;
  const char *lhs = stringVal(Arg1, &len);

  char buff[len];
  uniNCpy(buff, len, lhs, len);

  uniReverse(buff, len);

  return (ReturnStatus) {.ret=Ok,
    .result=(termPo) allocateString(processHeap(p), buff, len)};
}
