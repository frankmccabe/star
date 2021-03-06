//
// Created by Francis McCabe on 3/20/20.
//

#ifndef STAR_LIST_H
#define STAR_LIST_H

#include "term.h"

termPo consHead(normalPo p);
termPo consTail(normalPo p);

extern termPo nilEnum;
extern labelPo consCons;

integer consLength(termPo p);

logical isCons(termPo t);
logical isConsNil(termPo t);

#endif //STAR_LIST_H
