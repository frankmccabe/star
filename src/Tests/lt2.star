test.lt2{
  import star.
  import star.script.

  js ::=
    .jT | .jF  | jS(js).

  eqr = {.
    eq = equalJ
  .}.

  equalJ(.jT,.jT) => .true.
  equalJ(.jF,.jF) => .true.
  equalJ(jS(L1),jS(L2)) => execQ(L1,L2).
  equalJ(_,_) default => .false.

  execQ(L1,L2) => eqr.eq(L1,L2).

  test() => equalJ(jS(.jT),jS(.jT)).

  main:()=>action[(),()].
  main() => do{
    assert test();
    assert ~execQ(.jF,.jT)
  }
}

  
