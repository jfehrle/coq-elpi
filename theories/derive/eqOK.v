(* Generates correctness proofs for comparison functions generated by derive.eq.

   license: GNU Lesser General Public License Version 2.1 or later           
   ------------------------------------------------------------------------- *)

From elpi Require Import elpi
  derive.eq derive.projK derive.isK 
  derive.param1 derive.param1P derive.map
  derive.induction derive.isK derive.projK
  derive.cast derive.bcongr derive.eqK.

Elpi Db derive.eqOK.db "
  type eqOK-db term -> term -> prop.

:name ""eqOK-db:fail""
eqOK-db T _ :-
  coq.say ""derive.eqOK: can't find the correctness proof for the comparison function on""
          {coq.term->string T},
  stop.

".

Elpi Command derive.eqOK.
Elpi Accumulate Db derive.param1.db.
Elpi Accumulate Db derive.induction.db.
Elpi Accumulate Db derive.map.db.
Elpi Accumulate Db derive.eq.db.
Elpi Accumulate Db derive.eqK.db.
Elpi Accumulate Db derive.eqOK.db.
Elpi Accumulate File "derive/eqOK.elpi".
Elpi Accumulate "
  main [str I, str Suffix] :- !, coq.locate I T, derive.eqOK.main T Suffix _.
  main [str I] :- !, coq.locate I T, derive.eqOK.main T ""_eqOK"" _.
  main _ :- usage.

  usage :- coq.error ""Usage: derive.eqOK <inductive type name> [<suffix>]"".
".
Elpi Typecheck.

