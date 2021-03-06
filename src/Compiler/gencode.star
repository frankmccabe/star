star.compiler.gencode{
  import star.
  import star.multi.
  import star.pkg.
  import star.sort.

  import star.compiler.assem.
  import star.compiler.core.
  import star.compiler.errors.
  import star.compiler.escapes.
  import star.compiler.intrinsics.
  import star.compiler.meta.
  import star.compiler.misc.
  import star.compiler.peephole.
  import star.compiler.ltipe.
  import star.compiler.types.

  import star.compiler.location.
  import star.compiler.terms.

  srcLoc ::= lclVar(integer,tipe) |
    argVar(integer,tipe) |
    glbVar(string,tipe) |
    glbFun(string,tipe).

  Cont ::= cont{
    C:(codeCtx,multi[assemOp],option[cons[tipe]],reports)=>either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
    L:option[assemLbl].
    Simple:boolean
  }.

  codeCtx ::= codeCtx(map[string,srcLoc],locn,integer,integer).

  emptyCtx:(locn,map[string,srcLoc])=>codeCtx.
  emptyCtx(Lc,Glbs) => codeCtx(Glbs,Lc,0,0).

  ctxLbls:(codeCtx,codeCtx)=>codeCtx.
  ctxLbls(codeCtx(Vrs,Lc,Mx1,Lb1),codeCtx(_,_,Mx2,Lb2))=>
    codeCtx(Vrs,Lc,max(Mx1,Mx2),max(Lb1,Lb2)).

  implementation display[codeCtx] => {.
    disp(codeCtx(Vrs,_,Depth,Stk)) => ssSeq([ss("depth "),disp(Depth),ss(" stack "),disp(Stk)]).
  .}

  implementation sizeable[codeCtx] => {.
    isEmpty(codeCtx(Vars,_,_,_))=>isEmpty(Vars).
    size(codeCtx(Vars,_,_,_))=>size(Vars).
  .}

  implementation display[srcLoc] => {.
    disp(lclVar(Off,Tpe)) =>ssSeq([ss("lcl "),disp(Off),ss(":"),disp(Tpe)]).
    disp(argVar(Off,Tpe)) =>ssSeq([ss("arg "),disp(Off),ss(":"),disp(Tpe)]).
    disp(glbVar(Off,Tpe)) =>ssSeq([ss("glb "),disp(Off),ss(":"),disp(Tpe)]).
    disp(glbFun(Off,Tpe)) =>ssSeq([ss("fun "),disp(Off),ss(":"),disp(Tpe)]).
  .}

  public compCrProg:(pkg,cons[crDefn],cons[(string,tipe)],compilerOptions,reports)=>
    either[reports,cons[codeSegment]].
  compCrProg(Pkg,Defs,Globals,Opts,Rp) => do{
    compDefs(Defs,localFuns(Defs,foldRight(((Pk,Tp),G)=>G[Pk->glbVar(Pk,Tp)],[],Globals)),
      Opts,genBoot(Pkg,Defs),Rp)
  }.

  localFuns:(cons[crDefn],map[string,srcLoc])=>map[string,srcLoc].
  localFuns(Defs,Vars) => foldRight(defFun,Vars,Defs).

  defFun(fnDef(Lc,Nm,Tp,_,_),Vrs) => Vrs[Nm->glbFun(Nm,Tp)].
  defFun(glbDef(Lc,crId(Nm,Tp),_),Vrs) => Vrs[Nm->glbVar(Nm,Tp)].
  defFun(rcDef(_,_,_,_),Vrs) => Vrs.
  
  compDefs:(cons[crDefn],map[string,srcLoc],compilerOptions,cons[codeSegment],reports)=>
    either[reports,cons[codeSegment]].
  compDefs([],_,_,Cs,_)=>either(Cs).
  compDefs([D,..Dfs],Glbs,Opts,Cs,Rp) => do{
    Code<-compDefn(D,Glbs,Opts,Rp);
    compDefs(Dfs,Glbs,Opts,[Code,..Cs],Rp)
  }

  compDefn:(crDefn,map[string,srcLoc],compilerOptions,reports) => either[reports,codeSegment].
  compDefn(fnDef(Lc,Nm,Tp,Args,Val),Glbs,Opts,Rp) => do{
    if Opts.showCode then
      logMsg("compile $(fnDef(Lc,Nm,Tp,Args,Val))");
    Ctx .= emptyCtx(Lc,Glbs);
    Ctxa .= argVars(Args,Ctx,0);
    (Ctxx,Code,Stk) <- compExp(Val,Opts,retCont(Lc),Ctxa,[],some([]),Rp);
    valis method(tLbl(Nm,size(Args)),Tp,peepOptimize(Code::cons[assemOp]))
  }
  compDefn(glbDef(Lc,crId(Nm,Tp),Val),Glbs,Opts,Rp) => do{
    if Opts.showCode then
      logMsg("compile global $(Nm)\:$(Tp) = $(Val))");
    Ctx .= emptyCtx(Lc,Glbs);
    (Ctxx,Code,Stk) <- compExp(Val,Opts,bothCont(stoGlb(Nm),retCont(Lc)),Ctx,[],some([]),Rp);
    valis global(tLbl(Nm,0),Tp,peepOptimize(Code::cons[assemOp]))
  }

  compExp:(crExp,compilerOptions,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compExp(Exp,_,_,_,_,.none,Rp) => other(reportError(Rp,"$(Exp) is dead code",locOf(Exp))).
  compExp(Exp,_,Cont,Ctx,Cde,some(Stk),Rp) where (Const,Tp)^=isLiteral(Exp) =>
    Cont.C(Ctx,Cde++[iLdC(Const)],some([typeOf(Exp),..Stk]),Rp).
  compExp(crInt(Lc,Ix),_,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdC(intgr(Ix))],some([intType,..Stk]),Rp).
  compExp(crFlot(Lc,Dx),_,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdC(flot(Dx))],some([fltType,..Stk]),Rp).
  compExp(crStrg(Lc,Sx),_,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdC(strg(Sx))],some([strType,..Stk]),Rp).
  compExp(crVoid(_,Tp),_,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[.iLdV],some([Tp,..Stk]),Rp).
  compExp(crLbl(Lc,Nm,Tp),_,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdC(symb(tLbl(Nm,0)))],some([Tp,..Stk]),Rp).
  compExp(crVar(Lc,crId(Vr,Tp)),Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    if Loc^=locateVar(Vr,Ctx) then {
      compVar(Lc,Vr,Loc,Opts,Cont,Ctx,Cde,Stk,Rp)
    } else
    throw reportError(Rp,"cannot locate variable $(Vr)\:$(Tp)",Lc)
  }
  compExp(crTerm(Lc,Nm,Args,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExps(Args,Opts,bothCont(allocCont(tLbl(Nm,size(Args)),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).
  compExp(crECall(Lc,Op,Args,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) where (_,Ins)^=intrinsic(Op) =>
    compExps(Args,Opts,bothCont(asmCont(Ins,size(Args),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).
  compExp(crECall(Lc,Nm,Args,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExps(Args,Opts,bothCont(escCont(Nm,size(Args),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).
  compExp(crCall(Lc,Nm,Args,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExps(Args,Opts,bothCont(callCont(Nm,size(Args),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).
  compExp(crCall(Lc,Nm,Args,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExps(Args,Opts,bothCont(callCont(Nm,size(Args),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).
  compExp(crOCall(Lc,Op,Args,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExps(Args,Opts,bothCont(expCont(Op,Opts,oclCont(size(Args)+1,Tp,Stk)),Cont),Ctx,Cde,Stk,Rp).
  compExp(crRecord(Lc,Nm,Fields,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    Sorted .= sort(Fields,((F1,_),(F2,_))=>F1<F2);
    Args .= (Sorted//((_,V))=>V);
    compExps(Args,Opts,bothCont(allocCont(tRec(Nm,Sorted//((F,V))=>(F,typeOf(V))),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).    
  }
  compExp(crDot(Lc,Rc,Field,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExp(Rc,Opts,bothCont(fldCont(Field,Tp),Cont),Ctx,Cde,Stk,Rp).
  compExp(crTplOff(Lc,Rc,Ix,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    compExp(Rc,Opts,bothCont(tplOffCont(Ix,Tp),Cont),Ctx,Cde,Stk,Rp)}
  compExp(crTplUpdate(Lc,Rc,Ix,E),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compExp(Rc,Opts,
      bothCont(dupCont,expCont(E,Opts,bothCont(tplUpdateCont(Ix),Cont))),Ctx,Cde,Stk,Rp).
  compExp(crLtt(Lc,V,Val,Exp),Opts,Cont,Ctx,Cde,Stk,Rp) => 
    compExp(Val,Opts,
      bothCont(stoCont(V),expCont(Exp,Opts,Cont)),Ctx,Cde,Stk,Rp).

  compExp(crLtRec(Lc,V,Vl,Exp),Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    (Nxt,Ctx0) .= defineLbl("E",Ctx);
    (Off,Ctxb) .= defineLclVar(V,Ctx0);
    (Ctx1,Cde1,Stk1,FCont) <- compFrTerm(Vl,[V],V,[],Opts,
      bothCont(stoLcl(V,Off),jmpCont(Nxt)),Ctxb,[iStV(Off)],Stk,Rp);
    (Ctx2,Cde2,Stk2) <- FCont.C(Ctx1,Cde1++[iLbl(Nxt)],Stk1,Rp);
    compExp(Exp,Opts,Cont,Ctx2,Cde++Cde2,Stk,Rp)
  }
  compExp(crCase(Lc,Exp,Cases,Deflt,Tp),Opts,Cont,Ctx,Cde,Stk,Rp) =>
    compCase(Lc,Exp,Cases,Deflt,Tp,Opts,Cont,Ctx,Cde,Stk,Rp).
  compExp(crAbort(Lc,Msg,Tp),Opts,_,Ctx,Cde,Stk,Rp) =>
    compExps([Lc::crExp,crStrg(Lc,Msg)],Opts,
      escCont("_abort",2,Tp,.none), Ctx,Cde,Stk,Rp).
  compExp(crCnd(Lc,T,L,R),Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    CtxC .= ptnVars(T,Ctx);
    logMsg("conditional exp $(crCnd(Lc,T,L,R)) @ $(Lc), Stk=$(Stk)");
    (Nxt,Ctx0) .= defineLbl("L",CtxC);
    (Ctx1,Cd1,Stk1) <- compCond(T,Opts,
      expCont(L,Opts,jmpCont(Nxt)),
      expCont(R,Opts,jmpCont(Nxt)),
      Ctx0,Cde,Stk,Rp);
    logMsg("stack after conditional $(Stk1)");
    Cont.C(Ctx1,Cd1++[iLbl(Nxt)],Stk1,Rp)
  }
  compExp(C,Opts,Cont,Ctx,Cde,Stk,Rp) where isCrCond(C) => do{
    OS .= onceCont(locOf(C),Cont);
    compCond(C,Opts,bothCont(resetCont(Stk,
	  litCont(enum("star.core#true"),boolType)),OS),
      bothCont(resetCont(Stk,
	  litCont(enum("star.core#false"),boolType)),OS),
      Ctx,Cde,Stk,Rp).
  }

  -- compute elements to go in free tuple
  compFrTerm:(crExp,set[crVar],crVar,cons[either[integer,string]],compilerOptions,Cont,codeCtx,
    multi[assemOp],
    option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]],Cont)].
  compFrTerm(crVar(Lc,Vr),Roots,Base,Pth,Opts,Cont,Ctx,Cde,some(Stk),Rp) => do{
    if Vr.<.Roots then {
      FCont .= fixupCont(Base,Pth,Vr,[]);
      (Ctx1,Cde1,Stk1) <- Cont.C(Ctx,Cde++[.iLdV],some([typeOf(Vr),..Stk]),Rp);
      valis (Ctx1,Cde1,Stk1,FCont)
    }
    else{
      (Ctxx,Cdex,Stkx) <- compExp(crVar(Lc,Vr),Opts,Cont,Ctx,Cde,some(Stk),Rp);
      valis (Ctxx,Cdex,Stkx,nullCont)
    }
  }
  compFrTerm(crInt(Lc,Ix),_,_,_,_,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Ctxx,Cdex,Stkx) <- Cont.C(Ctx,Cde++[iLdC(intgr(Ix))],some([intType,..Stk]),Rp);
    valis (Ctxx,Cdex,Stkx,nullCont)
  }
  compFrTerm(crFlot(Lc,Dx),_,_,_,_,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Ctxx,Cdex,Stkx) <- Cont.C(Ctx,Cde++[iLdC(flot(Dx))],some([fltType,..Stk]),Rp); 
    valis (Ctxx,Cdex,Stkx,nullCont)
  }
  compFrTerm(crStrg(Lc,Sx),_,_,_,_,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Ctxx,Cdex,Stkx) <- Cont.C(Ctx,Cde++[iLdC(strg(Sx))],some([strType,..Stk]),Rp);
    valis (Ctxx,Cdex,Stkx,nullCont)
  }
  compFrTerm(crLbl(Lc,Nm,Tp),_,_,_,_,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Ctxx,Cdex,Stkx) <- Cont.C(Ctx,Cde++[iLdC(symb(tLbl(Nm,0)))],some([Tp,..Stk]),Rp);
    valis (Ctxx,Cdex,Stkx,nullCont)
  }
  compFrTerm(crVoid(Lc,Tp),_,_,_,_,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Ctxx,Cdex,Stkx) <- Cont.C(Ctx,Cde++[.iLdV],some([Tp,..Stk]),Rp);
    valis (Ctxx,Cdex,Stkx,nullCont)
  }
  compFrTerm(crTerm(Lc,Nm,Args,Tp),Roots,Base,Pth,Opts,Cont,Ctx,Cde,Stk,Rp) => 
    compFrArgs(Args,Roots,Base,0,Pth,Opts,
      bothCont(allocCont(tLbl(Nm,size(Args)),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).

  compFrTerm(crRecord(Lc,Nm,Fields,Tp),Roots,Base,Pth,Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    Sorted .= sort(Fields,((F1,_),(F2,_))=>F1<F2);
    Args .= (Sorted//((_,V))=>V);
    compFrArgs(Args,Roots,Base,0,Pth,Opts,bothCont(allocCont(tRec(Nm,Sorted//((F,V))=>(F,typeOf(V))),Tp,Stk),Cont),Ctx,Cde,Stk,Rp).    
  }
  compFrTerm(crTplOff(Lc,Tpl,Ix,Tp),Roots,Base,Pth,Opts,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Rc,OffPth) .= offPath(Tpl,[other(Ix)]);
    if crVar(RLc,V).=Rc && V .<. Roots then{
      FCont .= fixupCont(Base,Pth,V,OffPth);
      (Ctx1,Cde1,Stk1) <- Cont.C(Ctx,Cde++[.iLdV],some([Tp,..Stk]),Rp);
      valis (Ctx1,Cde1,Stk1,FCont)
    }
    else{
      compFrTerm(Rc,Roots,Base,Pth,Opts,
	bothCont(followPathCont(OffPth,Tp),Cont),Ctx,Cde,some(Stk),Rp)
    }
  }
  compFrTerm(crDot(Lc,Rc,Fld,Tp),Roots,Base,Pth,Opts,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Rc,OffPth) .= offPath(Rc,[either(Fld)]);
    if crVar(RLc,V).=Rc && V .<. Roots then{
      FCont .= fixupCont(Base,Pth,V,OffPth);
      (Ctx1,Cde1,Stk1) <- Cont.C(Ctx,Cde++[.iLdV],some([Tp,..Stk]),Rp);
      valis (Ctx1,Cde1,Stk1,FCont)
    }
    else{
      compFrTerm(Rc,Roots,Base,Pth,Opts,bothCont(followPathCont([either(Fld),..OffPth],Tp),Cont),Ctx,Cde,some(Stk),Rp)
    }
  }
  
  compFrTerm(crLtt(Lc,V,Val,Exp),Roots,Base,Path,Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    (Nxt,Ctx0) .= defineLbl("F",Ctx);
    (Off,Ctxa) .= defineLclVar(V,Ctx0);
    (Ctx1,Cde1,Stk1,FC1) <- compFrTerm(Val,Roots\+V,V,[],Opts,bothCont(stoLcl(V,Off),jmpCont(Nxt)),Ctxa,[iStV(Off)],Stk,Rp);
    (Ctx2,Cde2,Stk2,FC2) <- compFrTerm(Exp,Roots,Base,Path,Opts,Cont,Ctx1,Cde1++[iLbl(Nxt)],Stk1,Rp);
    valis (Ctx2,Cde++Cde2,Stk2,bothCont(FC1,FC2))
  }
  compFrTerm(crLtRec(Lc,V,Val,Exp),Roots,Base,Path,Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    (Nxt,Ctx0) .= defineLbl("G",Ctx);
    (Off,Ctxa) .= defineLclVar(V,Ctx0);
    (Ctx1,Cde1,Stk1,FC1) <- compFrTerm(Val,Roots\+V,V,[],Opts,bothCont(stoLcl(V,Off),jmpCont(Nxt)),Ctxa,[iStV(Off)],Stk,Rp);

    (Ctx2,Cde2,Stk2) <- FC1.C(Ctx1,Cde1++[iLbl(Nxt)],Stk1,Rp);
    (Ctx3,Cde3,Stk3,FC2) <- compFrTerm(Exp,Roots,Base,Path,Opts,Cont,Ctx2,Cde2,Stk2,Rp);
    valis (Ctx3,Cde++Cde3,Stk3,FC2)
  }
  compFrTerm(Exp,_,_,_,Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    (Ctx1,Cde1,Stk1) <- compExp(Exp,Opts,Cont,Ctx,Cde,Stk,Rp);
    valis (Ctx1,Cde1,Stk1,nullCont)
  }

  offPath:(crExp,cons[either[integer,string]])=>(crExp,cons[either[integer,string]]).
  offPath(crTplOff(_,Rc,Ix,_),Pth) => offPath(Rc,[other(Ix),..Pth]).
  offPath(crDot(_,Rc,Fld,_),Pth) => offPath(Rc,[either(Fld),..Pth]).
  offPath(Exp,Pth) default => (Exp,Pth).

  compFrArgs:(cons[crExp],set[crVar],crVar,integer,cons[either[integer,string]],compilerOptions,Cont,
    codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]],Cont)].

  compFrArgs([],_,_,_,_,Opts,Cont,Ctx,Cde,Stk,Rp) => do{
    (Ctxx,Cdex,Stkx) <- Cont.C(Ctx,Cde,Stk,Rp);
    valis (Ctxx,Cdex,Stkx,nullCont)
  }
  compFrArgs([El,..Es],Roots,Base,Ix,Pth,Opts,Cont,Ctx,Cde,Stk,Rp)=> do{
    (Nxt,Ctx0) .= defineLbl("f",Ctx);
    (Ctx1,Cde1,Stk1,CF1) <- compFrArgs(Es,Roots,Base,Ix+1,Pth,Opts,jmpCont(Nxt),Ctx0,Cde,Stk,Rp);
    (Ctx2,Cde2,Stk2,CF2) <- compFrTerm(El,Roots,Base,[other(Ix),..Pth],Opts,Cont,Ctx1,Cde1++[iLbl(Nxt)],Stk1,Rp);
    valis (Ctx2,Cde2,Stk2,bothCont(CF1,CF2))
  }.

  -- Expressions are evaluated in reverse order
  compExps:(cons[crExp],compilerOptions,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compExps([],Opts,Cont,Ctx,Cde,Stk,Rp)=>Cont.C(Ctx,Cde,Stk,Rp).
  compExps([El,..Es],Opts,Cont,Ctx,Cde,Stk,Rp)=> do{
    (Nxt,Ctx1) .= defineLbl("S",Ctx);
    (Ctx2,Cde1,CCstk) <- compExps(Es,Opts,jmpCont(Nxt),Ctx1,Cde,Stk,Rp);
    compExp(El,Opts,Cont,Ctx2,Cde1++[iLbl(Nxt)],CCstk,Rp)
  }.

  compCase:(locn,crExp,cons[crCase],crExp,tipe,compilerOptions,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) => either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compCase(Lc,E,Cases,Deflt,Tp,Opts,Cont,Ctx,Cde,some(Stk),Rp) => do{
    (Nxt,Ctx1) .= defineLbl("CN",Ctx);
    (DLbl,Ctx2) .= defineLbl("CD",Ctx1);
    (Ctx3,ECode,EStk) <- compExp(E,Opts,jmpCont(Nxt),Ctx2,Cde,some(Stk),Rp);
    (Table,Max) .= genCaseTable(Cases);
    OC .= onceCont(Lc,Cont);
    (Ctx4,CCode,CStk) <- compCases(Table,0,Max,OC,jmpCont(DLbl),DLbl,Opts,Ctx3,ECode++[iLbl(Nxt),iCase(Max)],EStk,Rp);
    (Ctx5,DCode,DStk) <- compExp(Deflt,Opts,OC,Ctx4,CCode++[iLbl(DLbl),iRst(size(Stk))],some(Stk),Rp);
    Stkx <- mergeStack(Lc,CStk,DStk,Rp);
    logMsg("stack after case @ $(Lc) is $(Stkx)");
    valis (Ctx5,DCode,Stkx)
  }

  genCaseTable(Cases) where Mx.=nextPrime(size(Cases)) =>
    (sortCases(caseHashes(Cases,Mx)),Mx).

  caseHashes:(cons[crCase],integer)=>cons[(locn,crExp,integer,crExp)].
  caseHashes(Cases,Mx) => (Cases//((Lc,Pt,Ex))=>(Lc,Pt,caseHash(Pt)%Mx,Ex)).

  caseHash:(crExp)=>integer.
  caseHash(crVar(_,_)) => 0.
  caseHash(crInt(_,Ix)) => Ix.
  caseHash(crFlot(_,Dx)) => hash(Dx).
  caseHash(crStrg(_,Sx)) => hash(Sx).
  caseHash(crLbl(_,Nm,Tp)) => arity(Tp)*37+hash(Nm).
  caseHash(crTerm(_,Nm,Args,_)) => size(Args)*37+hash(Nm).

  sortCases(Cases) => mergeDuplicates(sort(Cases,((_,_,H1,_),(_,_,H2,_))=>H1<H2)).

  mergeDuplicates:(cons[(locn,crExp,integer,crExp)])=>cons[(integer,cons[(locn,crExp,crExp)])].
  mergeDuplicates([])=>[].
  mergeDuplicates([(Lc,Pt,Hx,Ex),..M]) where (D,Rs).=mergeDuplicate(M,Hx,[]) =>
    [(Hx,[(Lc,Pt,Ex),..D]),..mergeDuplicates(Rs)].

  mergeDuplicate([(Lc,Pt,Hx,Ex),..M],Hx,SoFar) =>
    mergeDuplicate(M,Hx,SoFar++[(Lc,Pt,Ex)]).
  mergeDuplicate(M,_,SoFar) default => (SoFar,M).

  compCases:(cons[(integer,cons[(locn,crExp,crExp)])],integer,integer,Cont,Cont,assemLbl,compilerOptions,
    codeCtx,multi[assemOp],option[cons[tipe]],reports) => either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compCases([],Mx,Mx,_,_,_,_,Ctx,Cde,Stk,_) => either((Ctx,Cde,Stk)).
  compCases([],Ix,Mx,Succ,Fail,Deflt,Opts,Ctx,Cde,Stk,Rp) where Ix<Mx =>
    compCases([],Ix+1,Mx,Succ,Fail,Deflt,Opts,Ctx,Cde++[iJmp(Deflt)],Stk,Rp).
  compCases([(Ix,Case),..Cases],Ix,Mx,Succ,Fail,Deflt,Opts,Ctx,Cde,Stk,Rp) => do{
    (Lb,Ctx1) .= defineLbl("CC",Ctx);
    (Ctx2,Cde2,_) <- compCases(Cases,Ix+1,Mx,Succ,Fail,Deflt,Opts,Ctx1,Cde++[iJmp(Lb)],Stk,Rp);
    compCaseBranch(Case,Succ,Fail,Deflt,Opts,Ctx2,Cde2++[iLbl(Lb)],Stk,Rp)
  }
  compCases([(Iy,Case),..Cases],Ix,Mx,Succ,Fail,Deflt,Opts,Ctx,Cde,Stk,Rp) =>
    compCases([(Iy,Case),..Cases],Ix+1,Mx,Succ,Fail,Deflt,Opts,Ctx,Cde++[iJmp(Deflt)],Stk,Rp).

  compCaseBranch([(Lc,Ptn,Exp)],Succ,Fail,Deflt,Opts,Ctx,Cde,Stk,Rp) => do{
    (Nxt,Ctx1) .= defineLbl("CB",Ctx);
--    logMsg("case branch $(Ptn)->$(Exp), Stk=$(Stk)");
    (Ctx2,Cde2,Stk1)<-compPtn(Ptn,Opts,jmpCont(Nxt),Fail,Ctx1,Cde,Stk,Rp);
    compExp(Exp,Opts,Succ,Ctx2,Cde2++[iLbl(Nxt)],Stk1,Rp)
  }
  compCaseBranch([(Lc,Ptn,Exp),..More],Succ,Fail,Deflt,Opts,Ctx,Cde,Stk,Rp) => do{
    (Fl,Ctx2) .= defineLbl("CF",Ctx);
    (VLb,Ctx3) .= defineLbl("CN",Ctx2);
    Vr .= crId(genSym("__"),typeOf(Ptn));
    (Off,Ctx4) .= defineLclVar(Vr,Ctx3);
    (Ctx5,Cde2,Stk1)<-compPtn(Ptn,Opts,expCont(Exp,Opts,Succ),jmpCont(Fl),Ctx4,Cde++[iTL(Off)],Stk,Rp);
    compMoreCase(More,Off,Succ,Fail,Opts,Ctx5,Cde2++[iLbl(Fl)],Stk,Rp)
  }

  compMoreCase:(cons[(locn,crExp,crExp)],integer,Cont,Cont,compilerOptions,codeCtx,multi[assemOp],option[cons[tipe]],reports) => either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compMoreCase([],_,_,Fail,Opts,Ctx,Cde,Stk,Rp) => Fail.C(Ctx,Cde,Stk,Rp).
  compMoreCase([(Lc,Ptn,Exp),..More],Off,Succ,Fail,Opts,Ctx,Cde,Stk,Rp) => do{
    (Fl,Ctx1) .= defineLbl("CM",Ctx);
    (Ctx5,Cde2,Stk1)<-compPtn(Ptn,Opts,expCont(Exp,Opts,Succ),jmpCont(Fl),Ctx1,Cde++[iLdL(Off)],Stk,Rp);
    compMoreCase(More,Off,Succ,Fail,Opts,Ctx5,Cde2++[iLbl(Fl)],Stk,Rp)
  }
  
  compVar:(locn,string,srcLoc,compilerOptions,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compVar(Lc,Nm,argVar(Off,Tp),Opts,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdA(Off)],some([Tp,..Stk]),Rp).
  compVar(Lc,Nm,lclVar(Off,Tp),Opts,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdL(Off)],some([Tp,..Stk]),Rp).
  compVar(Lc,_,glbVar(Nm,Tp),Opts,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdG(Nm)],some([Tp,..Stk]),Rp).
  compVar(Lc,_,glbFun(Nm,Tp),Opts,Cont,Ctx,Cde,some(Stk),Rp) =>
    Cont.C(Ctx,Cde++[iLdC(symb(tLbl(Nm,arity(Tp))))],some([Tp,..Stk]),Rp).
  compVar(Lc,Nm,_,_,_,_,_,.none,Rp) =>
    other(reportError(Rp,"unreachable variable $(Nm)",Lc)).
  compVar(Lc,Nm,Loc,Opts,_,_,_,_,Rp) =>
    other(reportError(Rp,"cannot compile variable $(Nm)",Lc)).

  compCond:(crExp,compilerOptions,Cont,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compCond(crCnj(Lc,L,R),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) => do{
    OC .= onceCont(Lc,Fail);
    compCond(L,Opts,condCont(R,Opts,Succ,OC),OC,Ctx,Cde,Stk,Rp)
  }
  compCond(crDsj(Lc,L,R),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) => do{
    OC .= onceCont(Lc,Succ);
    compCond(L,Opts,OC,condCont(R,Opts,OC,Fail),Ctx,Cde,Stk,Rp)
  }
  compCond(crNeg(Lc,R),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) =>
    compCond(R,Opts,Fail,Succ,Ctx,Cde,Stk,Rp).
  compCond(crCnd(Lc,T,L,R),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) => do{
    OS .= onceCont(Lc,resetCont(Stk,Succ));
    OF .= onceCont(Lc,resetCont(Stk,Fail));
    CtxC .= ptnVars(T,Ctx);
    compCond(T,Opts,condCont(L,Opts,OS,OF),condCont(R,Opts,OS,OF),CtxC,Cde,Stk,Rp)
  }
  compCond(crMatch(Lc,Ptn,Exp),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) =>
    compExp(Exp,Opts,ptnCont(Ptn,Opts,Succ,Fail),Ctx,Cde,Stk,Rp).
  compCond(Exp,Opts,Succ,Fail,Ctx,Cde,Stk,Rp) =>
    compExp(Exp,Opts,testCont(locOf(Exp),Succ,Fail),Ctx,Cde,Stk,Rp).

  compPtn:(crExp,compilerOptions,Cont,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compPtn(crVar(Lc,crId(Vr,Tp)),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) => do{
    if Loc ^= locateVar(Vr,Ctx) then 
      compPtnVar(Lc,Vr,Loc,Opts,Succ,Ctx,Cde,Stk,Rp)
    else{
      (Off,Ctx1) .= defineLclVar(crId(Vr,Tp),Ctx);
      compPtnVar(Lc,Vr,lclVar(Off,Tp),Opts,Succ,Ctx1,Cde,Stk,Rp)
    }
  }
  compPtn(crVoid(Lc,Tp),Opts,Succ,Fail,Ctx,Cde,some([_,..Stk]),Rp) => do{
    if Fl^=Succ.L then{
      Fail.C(Ctx,Cde++[iCV(Fl)],some(Stk),Rp)
    } else{
      (Fl,Ctx1) .= defineLbl("PV",Ctx);
      (Ctx2,Cde2,Stk2) <- Fail.C(Ctx1,Cde++[iCV(Fl)],some(Stk),Rp);
      (Ctx3,Cde3,Stk3) <- Succ.C(Ctx2,Cde2++[iLbl(Fl)],some(Stk),Rp);
      Stkx <- mergeStack(Lc,Stk2,Stk2,Rp);
      valis (Ctx3,Cde3,Stkx)
    }
  }
  compPtn(L,Opts,Succ,Fail,Ctx,Cde,some(Stk),Rp) where (T,Tp)^=isLiteral(L) =>
    ptnTest(locOf(L),Tp,Succ,Fail,Ctx,Cde++[iLdC(T)],some([Tp,..Stk]),Rp).
  compPtn(crTerm(Lc,Nm,Args,Tp),Opts,Succ,Fail,Ctx,Cde,some([_,..Stk]),Rp) => do{
    (FLb,Ctx1) .= defineLbl("U",Ctx);
    (NLb,Ctx2) .= defineLbl("UN",Ctx1);
--    logMsg("compile term $(crTerm(Lc,Nm,Args,Tp))");
    (Ctx3,MtchCode,_) <- compTermArgs(Args,Opts,
      resetCont(some(Stk),Succ),jmpCont(FLb),Ctx2,
      Cde++[iUnpack(tLbl(Nm,size(Args)),FLb)],
      some((Args//typeOf)++Stk),Rp);
--    logMsg("match code $(MtchCode)");
    Fail.C(Ctx3,MtchCode++[iLbl(FLb),iRst(size(Stk))],some(Stk),Rp)
  }
  compPtn(crWhere(Lc,Ptn,Cond),Opts,Succ,Fail,Ctx,Cde,Stk,Rp) =>
    compPtn(Ptn,Opts,condCont(Cond,Opts,Succ,Fail),Fail,Ctx,Cde,Stk,Rp).
  compPtn(Ptn,Opts,Succ,Fail,Ctx,Cde,.none,Rp) =>
    other(reportError(Rp,"unreachable pattern $(Ptn)",locOf(Ptn))).  

  compTermArgs:(cons[crExp],compilerOptions,Cont,Cont,
    codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compTermArgs([],_,Succ,_,Ctx,Cde,Stk,Rp) => do{
    Succ.C(Ctx,Cde,Stk,Rp)
  }
  compTermArgs([A,..As],Opts,Succ,Fail,Ctx,Cde,some([_,..Stk]),Rp) => do{
    (NLb,Ctx1) .= defineLbl("T",Ctx);
    NCont .= resetCont(some(Stk),jmpCont(NLb));
    (Ctx2,Cde2,_) <- compPtn(A,Opts,NCont,Fail,Ctx1,[],some([typeOf(A),..Stk]),Rp);
--    logMsg("Code from compiling $(NLb) : $(A) is $(Cde2)");
    compTermArgs(As,Opts,Succ,Fail,Ctx2,Cde++Cde2++[iLbl(NLb)],some(Stk),Rp)
  }

  compPtns:(cons[crExp],integer,compilerOptions,Cont,Cont,
    codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compPtns([],_,_,Succ,_,Ctx,Cde,Stk,Rp) => do{
    Succ.C(Ctx,Cde,Stk,Rp)
  }
  compPtns([A,..As],Ix,Opts,Succ,Fail,Ctx,Cde,some(Stk),Rp) => do{
    (NLb,Ctx1) .= defineLbl("PR",Ctx);
    NCont .= resetCont(some(Stk),jmpCont(NLb));
    (Ctx2,Cde2,_) <- compPtn(A,Opts,NCont,Fail,Ctx1,Cde++[.iDup,iNth(Ix)],some([typeOf(A),..Stk]),Rp);
    compPtns(As,Ix+1,Opts,Succ,Fail,Ctx2,Cde2++[iLbl(NLb)],some(Stk),Rp)
  }
  
  compPtnVar:(locn,string,srcLoc,compilerOptions,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  compPtnVar(Lc,Nm,lclVar(Off,Tp),Opts,Cont,Ctx,Cde,some([_,..Stk]),Rp) =>
    Cont.C(Ctx,Cde++[iStL(Off)],some(Stk),Rp).
  compPtnVar(Lc,Nm,Loc,_,_,_,_,_,Rp) => other(reportError(Rp,"cannot target var at $(Loc) in pattern",Lc)).

  ptnTest:(locn,tipe,Cont,Cont,codeCtx,multi[assemOp],option[cons[tipe]],reports) =>
    either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])].
  ptnTest(_,intType,Succ,Fail,Ctx,Cde,some([_,_,..Stk]),Rp) where Fl^=Fail.L =>
    Succ.C(Ctx,Cde++[iICmp(Fl)],some(Stk),Rp).
  ptnTest(_,Tp,Succ,Fail,Ctx,Cde,some([_,_,..Stk]),Rp) where Fl^=Fail.L =>
    Succ.C(Ctx,Cde++[iCmp(Fl)],some(Stk),Rp).
  ptnTest(Lc,Tp,Succ,Fail,Ctx,Cde,some([_,_,..Stk]),Rp) => do{
    (Fl,Ctx1) .= defineLbl("TF",Ctx);
    (Ctx2,Cde1,Stk1) <- Succ.C(Ctx1,Cde++[iCmp(Fl)],some(Stk),Rp);
    (Ctx3,Cde2,Stk2) <- Fail.C(Ctx2,Cde1++[iLbl(Fl)],some(Stk),Rp);
    Stkx <- mergeStack(Lc,Stk1,Stk2,Rp);
    valis (Ctx3,Cde2,Stkx)
  }

  isLiteral:(crExp)=>option[(term,tipe)].
  isLiteral(crInt(_,Ix))=>some((intgr(Ix),intType)).
  isLiteral(crFlot(_,Dx))=>some((flot(Dx),fltType)).
  isLiteral(crStrg(_,Sx))=>some((strg(Sx),strType)).
  isLiteral(crLbl(_,Nm,Tp))=>some((symb(tLbl(Nm,0)),Tp)).
  isLiteral(crTerm(_,Nm,[],Tp)) => some((term(tLbl(Nm,0),[]),Tp)).
  isLiteral(crVoid(Lc,Tp)) => some((symb(tLbl("star.core#void",0)),Tp)).
  isLiteral(_) default => .none.

  -- continuations

  ccont:(boolean,(codeCtx,multi[assemOp],option[cons[tipe]],reports)=>either[reports,(codeCtx,multi[assemOp],option[cons[tipe]])])=>Cont.
  ccont(S,C)=>cont{.
    C=C.
    L=.none.
    Simple = S.
  .}

  nullCont = cont{.
    C(Ctx,Cde,Stk,Rp) => either((Ctx,Cde,Stk)).
    L=.none.
    Simple=.true
  .}

  retCont:(locn)=>Cont.
  retCont(Lc) => ccont(.true,(Ctx,Cde,Stk,Rp) => do{
      if [Top]^=Stk then
	valis (Ctx,Cde++[.iRet],.none)
      else if Stk==.none then
	valis (Ctx,Cde,.none)
      else
      throw reportError(Rp,"top of stack should have exactly one value, not $(Stk)",Lc)
    }).

  jmpCont:(assemLbl)=>Cont.
  jmpCont(Lb) => cont{
    C(Ctx,Cde,Stk,Rp)=>do{
      valis (Ctx,Cde++[iJmp(Lb)],Stk)
    }.
    L=some(Lb).
    Simple=.true.
  }.

  traceCont:(()=>string,Cont)=>Cont.
  traceCont(Msg,C) => ccont(C.Simple,
    (Ctx,Cde,Stk,Rp)=> do{
      logMsg("trace #(Msg()), stack=$(Stk)");
      C.C(Ctx,Cde,Stk,Rp)
    }).

  resetCont:(option[cons[tipe]],Cont)=>Cont.
  resetCont(.none,Cont) => Cont.
  resetCont(some(SStk),C) =>
    ccont(C.Simple,(Ctx,Cde,_,Rp)=>
	C.C(Ctx,Cde++genRst(size(SStk),some(SStk)),some(SStk),Rp)).

  genRst:(integer,option[cons[tipe]]) => multi[assemOp].
  genRst(_,.none) => [].
  genRst(Dpth,some(S)) where size(S)==Dpth => [].
  genRst(Dpth,_) => [iRst(Dpth)].

  dupCont:Cont.
  dupCont = ccont(.false,
    (Ctx,Cde,some([Tp,..Stk]),Rp) =>
      either((Ctx,Cde++[.iDup],some([Tp,Tp,..Stk])))).

  allocCont:(termLbl,tipe,option[cons[tipe]])=>Cont.
  allocCont(Lbl,Tp,some(OStk)) =>
    ccont(.true,(Ctx,Cde,Stk,Rp)=>either((Ctx,Cde++[iAlloc(Lbl)],some([Tp,..OStk])))).

  asmCont:(assemOp,integer,tipe,option[cons[tipe]])=>Cont.
  asmCont(Op,Ar,Tp,some(Stk)) =>
    ccont(.true,(Ctx,Cde,OStk,Rp) => either((Ctx,Cde++[Op],some([Tp,..Stk])))).
  asmCont(Op,Ar,Tp,.none) =>
    ccont(.true,(Ctx,Cde,some(Stk),Rp) => either((Ctx,Cde++[Op],some([Tp,..drop(trace("drop $(Ar) ",Stk),Ar)])))).

  escCont:(string,integer,tipe,option[cons[tipe]])=>Cont.
  escCont(Nm,Ar,Tp,some(Stk)) =>
    ccont(.false,(Ctx,Cde,OStk,Rp) => do{
	valis (Ctx,Cde++[iEscape(Nm),iFrame(intgr(size(Stk)+1))],some([Tp,..Stk]))
      }).
  escCont(Nm,Ar,Tp,.none) => ccont(.true,(Ctx,Cde,OStk,Rp) => do{
      valis (Ctx,Cde++[iEscape(Nm),iFrame(intgr(0))],.none)
    }).

  callCont:(string,integer,tipe,option[cons[tipe]])=>Cont.
  callCont(Nm,Ar,Tp,some(Stk)) =>
    ccont(.false,(Ctx,Cde,OStk,Rp) =>
	either((Ctx,Cde++[iCall(tLbl(Nm,Ar)),iFrame(intgr(size(Stk)+1))],some([Tp,..Stk])))).

  oclCont:(integer,tipe,option[cons[tipe]])=>Cont.
  oclCont(Ar,Tp,some(Stk)) =>
    ccont(.false,(Ctx,Cde,SStk,Rp) => do{
	valis (Ctx,Cde++[iOCall(Ar),iFrame(intgr(size(Stk)+1))],some([Tp,..Stk]))
      }).

  expCont:(crExp,compilerOptions,Cont)=>Cont.
  expCont(Exp,Opts,Cont) =>
    ccont(.false,(Ctx,Cde,Stk,Rp) => do{
	compExp(Exp,Opts,Cont,Ctx,Cde,Stk,Rp)
      }).

  condCont:(crExp,compilerOptions,Cont,Cont)=>Cont.
  condCont(C,Opts,Succ,Fail)=>
    ccont(Succ.Simple && Fail.Simple,(Ctx,Cde,Stk,Rp) => do{
	compCond(C,Opts,Succ,Fail,Ctx,Cde,Stk,Rp)
      }).
  
  ptnCont:(crExp,compilerOptions,Cont,Cont)=>Cont.
  ptnCont(Ptn,Opts,Succ,Fail)=>
    ccont(.false,(Ctx,Cde,Stk,Rp)=> compPtn(Ptn,Opts,Succ,Fail,Ctx,Cde,Stk,Rp)).

  fldCont:(string,tipe)=>Cont.
  fldCont(Fld,Tp)=>
    ccont(.true,(Ctx,Cde,some([T,..Stk]),Rp) => do{
	valis (Ctx,Cde++[iGet(tLbl(Fld,0))],some([Tp,..Stk]))
      }).

  tplOffCont:(integer,tipe)=>Cont.
  tplOffCont(Ix,Tp)=>
    ccont(.true,(Ctx,Cde,some([T,..Stk]),Rp) =>  do{
	valis (Ctx,Cde++[iNth(Ix)],some([Tp,..Stk]))
      }).

  tplUpdateCont:(integer)=>Cont.
  tplUpdateCont(Ix)=>
    ccont(.true,(Ctx,Cde,some([T,_,..Stk]),Rp) =>  do{
	valis (Ctx,Cde++[iStNth(Ix)],some(Stk))
      }).

  fixupCont:(crVar,cons[either[integer,string]],crVar,cons[either[integer,string]]) => Cont.
  fixupCont(Base,[Off,..Pth],Src,SrcPth) => ccont(.false,(Ctx,Cde,Stk,Rp)=>do{
      BNm.=crName(Base);
      lclVar(BLoc,_)^=locateVar(BNm,Ctx);
      lclVar(SLoc,_)^=locateVar(crName(Src),Ctx);
      Update.=[iLdL(BLoc),..followPath(Pth)]++[iLdL(SLoc),..followPath(SrcPth)]++storeField(Off);
      valis (Ctx,Cde++Update,Stk)
    }).

  followPathCont:(cons[either[integer,string]],tipe) => Cont.
  followPathCont(Path,Tp) => ccont(.false,
    (Ctx,Cde,some([_,..Stk]),Rp) => do{
      valis (Ctx,Cde++followPath(Path),some([Tp,..Stk]))
    }).

  storeField:(either[integer,string])=>multi[assemOp].
  storeField(other(Ix)) => [iStNth(Ix)].
  storeField(either(Fld)) => [iSet(tLbl(Fld,0))].

  -- path is first in first out
  followPath:(cons[either[integer,string]])=>multi[assemOp].
  followPath([])=>[].
  followPath([other(Off),..Pth]) => [iNth(Off)]++followPath(Pth).
  followPath([either(Fld),..Pth]) => [iGet(tLbl(Fld,0))]++followPath(Pth).

  litCont:(term,tipe)=>Cont.
  litCont(T,Tp) =>
    ccont(.true,(Ctx,Cde,some(Stk),Rp) => do{
      valis (Ctx,Cde++[iLdC(T)],some([Tp,..Stk]))
    }).

  stoLcl:(crVar,integer)=>Cont.
  stoLcl(Vr,Off)=>
    ccont(.true,(Ctx,Cde,some([_,..Stk]),Rp) => do{
	valis (Ctx,Cde++[iStL(Off)],some(Stk))
    }).
  
  stoCont:(crVar)=>Cont.
  stoCont(V)=>
    ccont(.true,(Ctx,Cde,some([_,..Stk]),Rp) => do{
	(Off,Ctx1) .= defineLclVar(V,Ctx);
	valis (Ctx1,Cde++[iStL(Off)],some(Stk))
    }).

  stoGlb:(string)=>Cont.
  stoGlb(V) =>
    ccont(.true,(Ctx,Cde,Stk,Rp) => either((Ctx,Cde++[iTG(V)],Stk))).

  updateCont:(srcLoc)=>Cont.
  updateCont(lclVar(Off,_))=>
    ccont(.true,(Ctx,Cde,some([_,..Stk]),Rp) =>
      either((Ctx,Cde++[iStL(Off)],some(Stk)))).
  updateCont(argVar(Off,_))=>
    ccont(.true,(Ctx,Cde,some([_,..Stk]),Rp) =>
      either((Ctx,Cde++[iStA(Off)],some(Stk)))).
  updateCont(glbVar(Nm,_))=>
    ccont(.true,(Ctx,Cde,some([_,..Stk]),Rp) =>
      either((Ctx,Cde++[iStG(Nm)],some(Stk)))).

  bothCont:(Cont,Cont)=>Cont.
  bothCont(F,G) => ccont(F.Simple&&G.Simple,(Ctx,Cde,Stk,Rp)=> do{
      (Ct1,Cd1,Stk1) <- F.C(Ctx,Cde,Stk,Rp);
      G.C(Ct1,Cd1,Stk1,Rp)
    }).

  onceCont:(locn,Cont)=>Cont.
  onceCont(_,C) where C.Simple => C.
  onceCont(Lc,C)=> let{.
    d := .none.
  .} in ccont(.false,(Ctx,Cde,Stk,Rp) => do{
      if (Lbl,EStk,LStk)^=d! then{
	XStk <- mergeStack(Lc,EStk,Stk,Rp);
	valis (Ctx,Cde++[iJmp(Lbl)],LStk)
      }
      else{
	(Lbl,Cx) .= defineLbl("O",Ctx);
	(Ctx1,Cde1,Stk1) <- C.C(Cx,Cde++[iLbl(Lbl)],Stk,Rp);
	d := some((Lbl,Stk,Stk1));
	valis (Ctx1,Cde1,Stk1)
      }
  }).

  testCont:(locn,Cont,Cont)=>Cont.
  testCont(Lc,Succ,Fail)=>
    ccont(.false,(Ctx,Cde,some([_,..Stk]),Rp)=> do{
	(Lb,Ctx0) .= defineLbl("T",Ctx);
	logMsg("test true outcome, stack=$(Stk)");
	(Ctx1,C1,Stk1) <- Succ.C(Ctx0,Cde++[iUnpack(tLbl("star.core#true",0),Lb)],some(Stk),Rp);
	logMsg("test false outcome, stack=$(Stk)");
	(Ctx2,C2,Stk2) <- Fail.C(ctxLbls(Ctx,Ctx1),C1++[iLbl(Lb)],some(Stk),Rp);
	Stkx <- mergeStack(Lc,Stk1,Stk2,Rp);
	logMsg("stack after test $(Stkx)");
	valis (Ctx2,C2,Stkx)
      }
    ).

  mergeStack:(locn,option[cons[tipe]],option[cons[tipe]],reports)=>either[reports,option[cons[tipe]]].
  mergeStack(Lc,.none,S,_) => either(S).
  mergeStack(Lc,S,.none,_) => either(S).
  mergeStack(Lc,S1,S2,_) where S1==S2 => either(S1).
  mergeStack(Lc,S1,S2,Rp) => other(reportError(Rp,"inconsistent stacks: $(S1) vs $(S2)",Lc)).
  
  locateVar:(string,codeCtx)=>option[srcLoc].
  locateVar(Nm,codeCtx(Vars,_,_,_)) => Vars[Nm].

  defineLclVar:(crVar,codeCtx) => (integer,codeCtx).
  defineLclVar(crId(Nm,Tp),codeCtx(Vrs,Lc,Count,Lbl)) where NxtCnt .= Count+1 =>
    (NxtCnt,codeCtx(Vrs[Nm->lclVar(NxtCnt,Tp)],Lc,NxtCnt,Lbl)).

  defineLbl:(string,codeCtx)=>(assemLbl,codeCtx).
  defineLbl(Pr,codeCtx(Vrs,Lc,Count,Lb))=>(al(Pr++"$(Lb)"),codeCtx(Vrs,Lc,Count,Lb+1)).

  changeLoc:(locn,compilerOptions,codeCtx)=>(multi[assemOp],codeCtx).
  changeLoc(Lc,_,codeCtx(Vars,Lc0,Dp,Lb)) where Lc=~=Lc0 =>
    ([iLine(Lc::term)],codeCtx(Vars,Lc,Dp,Lb)).
    changeLoc(_,_,Ctx)=>([],Ctx).

  implementation hasLoc[codeCtx] => {
    locOf(codeCtx(_,Lc,_,_))=>Lc.
  }

  ptnVars:(crExp,codeCtx) => codeCtx.
  ptnVars(crVar(_,crId(Nm,Tp)),codeCtx(Vars,CLc,Count,Lb)) where _ ^= Vars[Nm] => codeCtx(Vars,CLc,Count,Lb).
  ptnVars(crVar(_,crId(Nm,Tp)),codeCtx(Vars,CLc,Count,Lb)) => codeCtx(Vars[Nm->lclVar(Count+1,Tp)],CLc,Count+1,Lb).
  ptnVars(crInt(_,_),Ctx) => Ctx.
  ptnVars(crFlot(_,_),Ctx) => Ctx.
  ptnVars(crStrg(_,_),Ctx) => Ctx.
  ptnVars(crVoid(_,_),Ctx) => Ctx.
  ptnVars(crLbl(_,_,_),Ctx) => Ctx.
  ptnVars(crTerm(_,Op,Els,_),Ctx) => foldRight(ptnVars,Ctx,Els).
  ptnVars(crCall(_,_,_,_),Ctx) => Ctx.
  ptnVars(crECall(_,_,_,_),Ctx) => Ctx.
  ptnVars(crOCall(_,_,_,_),Ctx) => Ctx.
  ptnVars(crRecord(_,_,Els,_),Ctx) => foldRight(((_,El),X)=>ptnVars(El,X),Ctx,Els).
  ptnVars(crDot(_,_,_,_),Ctx) => Ctx.
  ptnVars(crTplOff(_,_,_,_),Ctx) => Ctx.
  ptnVars(crTplUpdate(_,_,_,_),Ctx) => Ctx.
  ptnVars(crCnj(_,L,R),Ctx) => ptnVars(L,ptnVars(R,Ctx)).
  ptnVars(crDsj(_,L,R),Ctx) => mergeCtx(ptnVars(L,Ctx),ptnVars(R,Ctx),Ctx).
  ptnVars(crNeg(_,R),Ctx) => Ctx.
  ptnVars(crCnd(Lc,T,L,R),Ctx) => mergeCtx(ptnVars(crCnj(Lc,T,L),Ctx),ptnVars(R,Ctx),Ctx).
  ptnVars(crLtt(_,_,_,_),Ctx) => Ctx.
  ptnVars(crCase(_,_,_,_,_),Ctx) => Ctx.
  ptnVars(crAbort(_,_,_),Ctx) => Ctx.
  ptnVars(crWhere(_,P,C),Ctx) => ptnVars(C,ptnVars(P,Ctx)).
  ptnVars(crMatch(_,P,_),Ctx) => ptnVars(P,Ctx).

  argVars:(cons[crVar],codeCtx,integer) => codeCtx.
  argVars([],Ctx,_)=>Ctx.
  argVars([crId(Nm,Tp),..As],codeCtx(Vars,CLc,Count,Lb),Ix) =>
    argVars(As,codeCtx(Vars[Nm->argVar(Ix,Tp)],CLc,Count+1,Lb),Ix+1).
  argVars([_,..As],Ctx,Arg) => argVars(As,Ctx,Arg+1).

  mergeCtx:(codeCtx,codeCtx,codeCtx)=>codeCtx.
  mergeCtx(codeCtx(LV,_,_,Lb1),codeCtx(RV,_,_,Lb2),Base) => let{
    mergeVar:(string,srcLoc,codeCtx) => codeCtx.
    mergeVar(Nm,_,Vrs) where _ ^= locateVar(Nm,Base) => Vrs.
    mergeVar(Nm,_,codeCtx(Vs,Lc,Count,_)) where lclVar(_,Tp) ^= RV[Nm] =>
      codeCtx(Vs[Nm->lclVar(Count+1,Tp)],Lc,Count+1,max(Lb1,Lb2)).
    mergeVar(Nm,lclVar(_,Tp),codeCtx(Vs,Lc,Count,_)) =>
      codeCtx(Vs[Nm->lclVar(Count+1,Tp)],Lc,Count+1,max(Lb1,Lb2)).
  } in ixRight(mergeVar,Base,LV).

  drop:all x,e ~~ stream[x->>e] |: (x,integer)=>x.
  drop(S,0)=>S.
  drop([_,..S],N)=>drop(S,N-1).

  trimStack:all x, e ~~ stream[x->>e],sizeable[x] |: (option[x],integer)=>option[x].
  trimStack(some(L),N) =>some(drop(L,size(L)-N)).
  trimStack(.none,_) => .none.

  genBoot:(pkg,cons[crDefn])=>cons[codeSegment].
  genBoot(P,Defs) where Mn .= qualifiedName(pkgName(P),.valMark,"_main") && fnDef(_,Mn,_,_,_) in Defs => 
    [method(tLbl(qualifiedName(pkgName(P),.pkgMark,"_boot"),0),funType([],unitTp),[
          iEscape("_command_line"),
	  iLdG(packageVar(P)),
	  iGet(tLbl("_main",0)),
	  iOCall(2),
	  iFrame(intgr(0)),
	  .iHalt])].

  genBoot(_,_) default => [].

  frameSig:(cons[tipe])=>term.
  frameSig(Tps) => strg((tupleType(Tps)::ltipe)::string).

  enum:(string)=>term.
  enum(Nm)=>term(tLbl(Nm,0),[]).
}
