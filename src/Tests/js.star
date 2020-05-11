test.js{
--  import star.core.
--  import star.cons.
  import star.
  import star.script.

  public json ::=
    jSeq(cons[json]).

  public implementation equality[json] => {
    T1 == T2 => equalJson(T1,T2).
  }

  equalJson:(json,json)=>boolean.
--  equalJson(jSeq(L1),jSeq(L2)) => L1==L2.
  equalJson(jSeq(L1),jSeq(L2)) => (E1,E2) in zip(L1,L2) *> equalJson(E1,E2).
  equalJson(_,_) => .false.

  main:()=>action[(),()].
  main() => do{
    show jSeq([]) == jSeq([])
  }
}  
