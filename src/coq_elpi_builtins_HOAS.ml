(* Automatically generated from elpi/coq-HOAS.elpi, don't edit *)
let code = {|
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% coq-HOAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This section contains the low level data types linking Coq and elpi.
% In particular:
%   - the data type for terms and the evar_map entries (a sequent)
%   - the entry points for commands and tactics (main and solve)

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Entry points
%
% Command and tactic invocation (coq_elpi_vernacular.ml)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Entry point for commands. Eg. "#[att=true] Elpi mycommand foo 3 (f x)." becomes
%   main [str "foo", int 3, trm (app[f,x])]
% in a context where
%   attributes [attribute "att" (leaf "true")]
% holds. The encoding of terms is described below.
pred main i:list argument.
pred usage.
pred attributes o:list attribute.

% Entry point for tactics. Eg. "elpi mytactic foo 3 (f x)." becomes
%   solve [str "foo", int 3, trm (app[f,x])] <goals> <new goals>
% The encoding of goals is described below.
pred solve i:list argument, i:list goal, o:list goal.
% Note: currently the goal list is always of length 1.

% The data type of arguments (for commands or tactics)
kind argument type.
type int       int    -> argument. % Eg. 1 -2.
type str       string -> argument. % Eg. x "y" z.w. or any Coq keyword/symbol
type trm       term   -> argument. % Eg. (t).

% Extra arguments for commands. [Definition], [Axiom], [Record] and [Context]
% take precedence over the [str] argument above (when not "quoted").
%
% Eg. Record m A : T := K { f : t; .. }.
type indt-decl indt-decl -> argument.
% Eg. Definition m A : T := B. (or Axiom when the body is none)
type const-decl id -> option term -> arity -> argument.
% Eg. Context A (b : A).
type ctx-decl context-decl -> argument.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Coq's terms
%
% Types of term formers (coq_elpi_HOAS.ml)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -- terms --------------------------------------------------------------------
kind term type.

type sort  universe -> term. % Prop, Type@{i}

% constants: inductive types, inductive constructors, definitions
type global gref -> term.

% binders: to form functions, arities and local definitions
type fun  name -> term -> (term -> term) -> term.         % fun x : t =>
type prod name -> term -> (term -> term) -> term.         % forall x : t,
type let  name -> term -> term -> (term -> term) -> term. % let x : T := v in

% other term formers: function application, pattern matching and recursion
type app   list term -> term.                   % app [hd|args]
type match term -> term -> list term -> term.   % match t p [branch])
type fix   name -> int -> term -> (term -> term) -> term. % fix name rno ty bo

kind primitive-value type.
type uint63 uint63 -> primitive-value.
type float64 float64 -> primitive-value.
type primitive primitive-value -> term.


% NYI
%type cofix name -> term -> (term -> term) -> term. % cofix name ty bo
%type proj  @gref -> term -> term. % applied primitive projection

% Notes about (match Scrutinee TypingFunction Branches) when
%   Inductive i A : A -> nat -> Type := K : forall a : A, i A a 0
% and
%   Scrutinee be a term of type (i bool true 7)
%
% - TypingFunction has a very rigid shape that depends on i. Namely
%   as many lambdas as indexes plus one lambda for the inductive itself
%   where the value of the parameters are taken from the type of the scrutinee:
%     fun `a` (indt "bool") a\
%      fun `n` (indt "nat) n\
%       fun `i` (app[indt "i", indt "bool", a n) i\ ..
%   Such spine of fun cannot be omitted; else elpi cannot read the term back.
%   See also coq.bind-ind-arity in coq-lib.elpi, that builds such spine for you,
%   or the higher level api coq.build-match (same file) that also takes
%   care of breanches.
% - Branches is a list of terms, the order is the canonical one (the order
%   of the constructors as they were declared). If the constructor has arguments
%   (excluding the parameters) then the corresponding term shall be a Coq
%   function. In this case
%      fun `x` (indt "bool") x\ ..

% -- helpers ------------------------------------------------------------------
macro @cast T TY :- (let `cast` TY T x\x).

% -- misc ---------------------------------------------------------------------

% When one writes Constraint Handling Rules unification variables are "frozen",
% i.e. represented by a fresh constant (the evar key) and a list of terms
% (typically the variables in scope).
kind evarkey type.
type uvar  evarkey -> list term -> term.


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Coq's evar_map
%
% Context and evar declaration (coq_elpi_goal_HOAS.ml)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% An evar_info
%
% x : t
% y := v : x
% ----------
% p x y
%
% is coded as an elpi goal
%
% pi x1\ decl x1 `x` <t> =>
%  pi x2\ def x2 `y` x1 <v> =>
%   declare-evar
%      [decl x1 `x` <t>, def x2 `y` x1 <v>] (Ev x1 x2) (<p> x1 x2)
%
% where, by default, declare-evar creates a syntactic constraint as
%
% {x1 x2} : decl x1 `x` <t>, def x2 `y` x1 <v> ?- evar (Ev x1 x2) (<p> x1 x2)
%
% When the program is over, a remaining syntactic constraint like the one above
% is read back and transformed into the corresponding evar_info.
%
% The client may want to provide an alternative implementation of
% declare-evar that, for example, typechecks the term assigned to Ev
% (engine/elaborator.elpi does it).

pred decl i:term, o:name, o:term. % Var Name Ty
pred def  i:term, o:name, o:term, o:term. % Var Name Ty Bo
pred declare-evar i:list prop, i:term, i:term, i:term. % Ctx RawEvar Ty Evar

:name "default-declare-evar"
declare-evar Ctx RawEv Ty Ev :-
  declare_constraint (declare-evar Ctx RawEv Ty Ev) [RawEv].

% When a goal (evar _ _ _) is turned into a constraint the context is filtered
% to only contain decl, def, pp.  For now no handling rules for this set of
% constraints other than one to remove a constraint

pred rm-evar i:term.
rm-evar (uvar as X) :- !, declare_constraint (rm-evar X) [X].
rm-evar _.

constraint declare-evar evar def decl cache evar->goal rawevar->evar rm-evar {

   % Override the actual context
   rule \ (declare-evar Ctx RawEv Ty Ev) <=> (Ctx => evar RawEv Ty Ev).

   rule \ (rm-evar (uvar X _)) (evar _ _ (uvar X _)).

}

pred evar i:term, i:term, o:term. % Evar Ty RefinedSolution
evar (uvar as X) T S :- !,
  if (var S) (declare_constraint (evar X T S) [X, S])
             (X = S, evar X T S).

:name "default-assign-evar"
evar _ _ _. % volatile, only unresolved evars are considered as evars

% To ease the creation of a context with decl and def
% Eg.  @pi-decl `x` <t> x1\ @pi-def `y` <t> <v> y\ ...
macro @pi-decl N T F :- pi x\ decl x N T => F x.
macro @pi-def N T B F :- pi x\ def x N T B => cache x B_ => F x.
macro @pi-parameter ID T F :-
  sigma N\ (coq.id->name ID N, pi x\ decl x N T => F x).
macro @pi-inductive ID A F :-
  sigma N\ (coq.id->name ID N, coq.arity->term A T, pi x\ decl x N T => F x).

% Sometimes it can be useful to pass to Coq a term with unification variables
% representing "untyped holes" like an implicit argument _. In particular
% a unification variable may exit the so called pattern fragment (applied
% to distinct variables) and hence cannot be reliably mapped to Coq as an evar,
% but can still be considered as an implicit argument.
% By loading in the context get-option "HOAS:holes" tt one forces that
% behavior. Here a convenience macro to be put on the LHS of =>
macro @holes! :- get-option "HOAS:holes" tt.

% Similarly, some APIs take a term skeleton in input. In that case unification
% variables are totally disregarded (not even mapped to Coq evars). They are
% interpreted as the {{ lib:elpi.hole }} constant, which represents an implicit
% argument. As a consenque these APIs don't modify the input term at all, but
% rather return a copy. Note that if {{ lib:elpi.hole }} is used directly, then
% it has to be applied to all variables in scope, since Coq erases variables
% that are not used. For example using {{ forall x : nat, lib:elpi.hole }} as
% a term skeleton is equivalent to {{ nat -> lib:elpi.hole }}, while
% {{ forall x : nat, lib:elpi.hole x }} puts x in the scope of the hole.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Coq's goals and tactic invocation (coq_elpi_goal_HOAS.ml)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

kind extra-info type.
type goal-name name -> extra-info.

typeabbrev goal-ctx (list prop). % in reality only decl and def entries

kind goal type.

% goal Ctx Solution Ty ExtraInfo
type goal goal-ctx -> term -> term -> list extra-info -> goal.
% where Ctx is a list of decl or def and Solution is a unification variable
% to be assigned to a term of type Ty in order to make progress.
% ExtraInfo contains a list of "extra logical" data attached to the goal.

% nabla is used to close a goal under its bound name. This is useful to pass
% a goal to another piece of code and let it open the goal
type nabla (term -> goal) -> goal.

% The invocation of a tactic with arguments: 3 x "y" (h x)
% on a goal named "?Goal2" with a sequent like
%
% x : t
% y := v : x
% ----------
% g x y
%
% is coded as an elpi goal
%
% (pi x1\ decl x1 `x` <t> =>
%   pi x2\ def x2 `y` x1 <v> =>
%    declare-evar
%       [decl x1 `x` <t>, def x2 `y` x1 <v>]
%       (Evar x1 x2) (<g> x1 x2)),
% (pi x1\ pi x2\
%   solve
%     [int 3, str `x`, str`y`, trm (app[const `h`,x1])]
%     [goal
%        [decl x1 `x` <t>, def x2 `y` x1 <v>]
%        (Evar x1 x2) (<g> x1 x2)
%        [goal-name `?Goal2`]]
%     NewGoals
%
% If the goal sequent contains other evars, then a tactic invocation is
% an elpi query made of the conjunction of all the declare-evar queries
% corresponding to these evars and the query corresponding to the goal
% sequent. NewGoals can be assigned to a list of goals that should be
% declared as open. Omitted goals are shelved. If NewGoals is not
% assigned, then all unresolved evars become new goals, but the order
% of such goals is not specified.
%
% Note that the solve goal is not under a context containg the decl/def
% entries.  It is up to the user to eventually load the context as follows
%  solve _ [goal Ctx _ Ty] _ :- Ctx => unwind {whd Ty []} WhdTy.
%
% Finally the goal above can be represented as a closed term as
% (nabla x1\ nabla x2\
%      goal
%        [decl x1 `x` <t>, def x2 `y` x1 <v>]
%        (Evar x1 x2) (<g> x1 x2)
%        [goal-name `?Goal2`])


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Declarations for Coq's API (environment read/write access, etc).
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% tt = Yes, ff = No, unspecified = No (unspecified means "_" or a variable).
typeabbrev opaque?   bool.  macro @opaque! :- tt. macro @transparent! :- ff.

%%%%%%% Attributes to be passed to APIs as in @local! => coq.something %%%%%%%%

macro @global!   :- get-option "coq:locality" "global".
macro @local!    :- get-option "coq:locality" "local".

macro @primitive! :- get-option "coq:primitive" tt. % primitive records

macro @ppwidth! N :- get-option "coq:ppwidth" N. % printing width
macro @ppall! :- get-option "coq:pp" "all". % printing all
macro @ppmost! :- get-option "coq:pp" "most". % printing most of contents

macro @using! S :- get-option "coq:using" S. % like the #[using=S] attribute

% both arguments are strings eg "8.12.0" "use foo instead"
macro @deprecated! Since Msg :-
  get-option "coq:deprecated" (pr Since Msg).

macro @ltacfail! N :- get-option "ltac:fail" N.

% Declaration of inductive types %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

kind indt-decl type.
kind indc-decl type.
kind record-decl type.

% An arity is written, in Coq syntax, as:
%    (x : T1) .. (xn : Tn) : S1 -> ... -> Sn -> U
% This syntax is used, for example, in the type of an inductive type or
% in the type of constructors. We call the abstractions on the left of ":"
% "parameters" while we call the type following the ":" (proper) arity.

% Note: in some contexts, like the type of an inductive type constructor,
% Coq makes no distinction between these two writings
%    (xn : Tn) : forall y1 : S1, ...    and      (xn : Tn) (y1 : S1) : ...
% while Elpi is a bit more restrictive, since it understands user directives
% such as the implicit status of an arguments (eg, using {} instead of () around
% the binder), only on parameters.
% Moreover parameters carry the name given by the user as an "id", while binders
% in terms only carry it as a "name", an irrelevant pretty pringintg hint (see
% also the HOAS of terms). A user command can hence only use the names of
% parameters, and not the names of "forall" quantified variables in the arity.
%
% See also the arity->term predicate in coq-lib.elpi

type parameter id -> implicit_kind -> term -> (term -> arity) -> arity.
type arity term -> arity.

type parameter   id -> implicit_kind -> term -> (term -> indt-decl) -> indt-decl.
type inductive   id -> bool -> arity -> (term -> list indc-decl) -> indt-decl. % tt means inductive, ff coinductive
type record      id -> term -> id -> record-decl -> indt-decl.

type constructor id -> arity -> indc-decl.

type field       field-attributes -> id -> term -> (term -> record-decl) -> record-decl.
type end-record  record-decl.

% Example.
% Remark that A is a regular parameter; y is a non-uniform parameter and t
% also features an index of type bool.
%
%  Inductive t (A : Type) | (y : nat) : bool -> Type :=
%  | K1 (x : A) {n : nat} : S n = y -> t A n true -> t A y true
%  | K2 : t A y false
%
% is written
%
%  (parameter "A" explicit {{ Type }} a\
%     inductive "t" tt (parameter "y" explicit {{ nat }} _\
%                     arity {{ bool -> Type }})
%      t\
%       [ constructor "K1"
%          (parameter "y" explicit {{ nat }} y\
%           (parameter "x" explicit a x\
%            (parameter "n" maximal {{ nat }} n\
%              arity {{ S lp:n = lp:y -> lp:t lp:n true -> lp:t lp:y true }})))
%       , constructor "K2"
%          (parameter "y" explicit {{ nat }} y\
%            arity {{ lp:t lp:y false }}) ])
%
% Remark that the uniform parameters are not passed to occurrences of t, since
% they never change, while non-uniform parameters are both abstracted
% in each constructor type and passed as arguments to t.
%
% The coq.typecheck-indt-decl API can be used to fill in implicit arguments
% an infer universe constraints in the declaration above (e.g. the hidden
% argument of "=" in the arity of K1).
%
% Note: when and inductive type declaration is passed as an argument to an
% Elpi command non uniform parameters must be separated from the uniform ones
% with a | (a syntax introduced in Coq 8.12 and accepted by coq-elpi since
% version 1.4, in Coq this separator is optional, but not in Elpi).

% Context declaration (used as an argument to Elpi commands)
kind context-decl type.
% Eg. (x : T) or (x := B), body is optional, type may be a variable
type context-item  id -> implicit_kind -> term -> option term -> (term -> context-decl) -> context-decl.
type context-end   context-decl.

typeabbrev field-attributes (list field-attribute).

% retrocompatibility macro for Coq v8.10
macro @coercion! :- [coercion tt].
|}
