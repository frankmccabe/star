test.j{
  import star.
  import star.json.
  import star.parse.

<<<<<<< HEAD
  assert parse(pJson,"1"::list[integer]) == [(jNum(1.0),[])].
=======
/*  assert parse(pJson,"11"::list[integer]) == [(jNum(11.0),[])].
>>>>>>> 92a0b81122be93f4854ba006ffc464a89ec52f9f

  /*assert parse(pJson,"[1]"::list[integer]) == [(jSeq([jNum(1.0)]),[])].

  assert parse(pJson,"[1,2]"::list[integer]) == [(jSeq([jNum(1.0),jNum(2.0)]),[])].
*/

  assert parse(pJson,"\"alpha\""::list[integer]) == [(jTxt("alpha"),[])].

--  assert parse(pJson,"[\"alpha\"]"::list[integer]) == [(jSeq([jTxt("alpha")]),[])].
/*
  assert parse(pJson,"{\"f\":\"alpha\",\"g\":1}"::list[integer]) ==
     [(jColl(["f"->jTxt("alpha"),"g"->jNum(1.0)]),[])].

  assert parse(pJson,"[1,{\"f\":\"alpha\",\"g\":{}}]"::list[integer]) ==
   [(jSeq([jNum(1.0),jColl(["f"->jTxt("alpha"),"g"->jColl([])])]),[])].
<<<<<<< HEAD
   */
=======
*/
>>>>>>> 92a0b81122be93f4854ba006ffc464a89ec52f9f
}
