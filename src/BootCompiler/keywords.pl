:-module(keywords, [keyword/1,isKeyword/1]).

  isKeyword(X):- keyword(X), !.

  keyword("|").
  keyword("||").
  keyword("&&").
  keyword(";").
  keyword(":").
  keyword("::").
  keyword(",").
  keyword("?").
  keyword("!").
  keyword("^").
  keyword("~").
  keyword("~~").
  keyword("=").
  keyword(".=").
  keyword("=.").
  keyword(".~").
  keyword("=>").
  keyword("<=>").
  keyword("->").
  keyword("-->").
  keyword("->>").
  keyword("::=").
  keyword("<=").
  keyword("<~").
  keyword("~>").
  keyword("\\+").
  keyword(",..").
  keyword(".").
  keyword("|:").
  keyword("@").
  keyword("let").
  keyword("this").
  keyword("ref").
  keyword("import").
  keyword("public").
  keyword("private").
  keyword("open").
  keyword("contract").
  keyword("implementation").
  keyword("type").
  keyword("where").
  keyword("void").
  keyword("all").
  keyword("exists").
  keyword("assert").
  keyword("ignore").
  keyword("let").
  keyword("#").
  keyword("$").
