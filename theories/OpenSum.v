(** Common effects *)

(* TODO Swap sums (changed associativity). *)
(* TODO Split framework for extensible effects from concrete effect definitions *)

From Coq Require Import
     List String.
Import ListNotations.

From ExtLib.Structures Require Import
     Functor Monoid.

From ITree Require Import
     ITree Morphisms.

(** Sums for extensible event types. *)

Definition sum_reaction (E1 E2 : Effect) : E1 + E2 -> Type :=
  fun e =>
    match e with
    | inl e1 => reaction e1
    | inr e2 => reaction e2
    end.

Canonical Structure sumE (E1 E2 : Effect) : Effect := {|
    action := E1 + E2;
    reaction := sum_reaction E1 E2;
  |}.

Notation "E1 +' E2" := (sumE E1 E2)
(at level 50, left associativity) : type_scope.

Definition empty_reaction : Empty_set -> Type :=
  fun e => match e with end.

Canonical Structure emptyE : Effect := {|
    action := Empty_set;
    reaction := empty_reaction;
  |}.

(* Just for this section, [A B C D : Type -> Type] are more
   effect types. *)

Definition swap1 {A B : Effect}
           (ab : A +' B) : B +' A :=
  match ab with
  | inl a => inr a
  | inr b => inl b
  end.

Definition bimap_sum1 {A B C D : Effect}
           (f : A -> C) (g : B -> D)
           (ab : sumE A B) : sumE C D :=
  match ab with
  | inl a => inl (f a)
  | inr b => inr (g b)
  end.

Section into.
  Context {E F : Effect}.

  Definition into (h : eff_hom E F) : eff_hom (E +' F) F :=
    fun e =>
      match e with
      | inl e => h e
      | inr e => Vis e Ret
      end.

  Definition into_state {s} (h : eff_hom_s s E F) : eff_hom_s s (E +' F) F :=
    fun e s =>
      match e with
      | inl e => h e s
      | inr e => Vis e (fun x => Ret (s, x))
      end.

  Definition into_reader {s} (h : eff_hom_r s E F) : eff_hom_r s (E +' F) F :=
    fun e s =>
      match e with
      | inl e => h e s
      | inr e => Vis e Ret
      end.

  Definition into_writer {s} `{Monoid_s : Monoid s} (h : eff_hom_w s E F)
  : eff_hom_w s (E +' F) F :=
    fun e =>
      match e with
      | inl e => h e
      | inr e => Vis e (fun x => Ret (monoid_unit Monoid_s, x))
      end.

  (* todo(gmm): is the a corresponding definition for `eff_hom_p`? *)

End into.


(* Automatic application of commutativity and associativity for sums.
   TODO: This is still quite fragile and prone to
   infinite instance resolution loops.
 *)

Class Convertible (A B : Effect) := {
    convert_action : A -> B;
    convert_reaction : forall a : A,
        reaction (convert_action a) -> reaction a;
  }.

(* Don't try to guess. *)
Global Instance fluid_id A : Convertible A A | 0 := {
    convert_action a := a;
    convert_reaction _ x := x;
  }.

(* Destructure sums. *)
Global Instance fluid_sum A B C `{Convertible A C} `{Convertible B C}
  : Convertible (A +' B) C | 7 := {
    convert_action ab :=
      match ab with
      | inl a => convert_action a
      | inr b => convert_action b
      end;
    convert_reaction ab :=
      match ab with
      | inl a => convert_reaction a
      | inr b => convert_reaction b
      end;
  }.

(* Lean right by default for no reason. *)
Global Instance fluid_left A B `{Convertible A B} C
  : Convertible A (B +' C) | 9 := {
    convert_action a := inl (convert_action a);
    convert_reaction := convert_reaction;
  }.

(* Very incoherent instances. *)
Global Instance fluid_right A C `{Convertible A C} B
  : Convertible A (B +' C) | 8 := {
    convert_action a := inr (convert_action a);
    convert_reaction := convert_reaction;
  }.

Global Instance fluid_empty A : Convertible emptyE A := {
    convert_action v := match v with end;
    convert_reaction v := match v with end;
  }.

Arguments convert_reaction {_ _ _ a}.

Notation "EE ++' E" := (List.fold_right sumE EE E)
(at level 50, left associativity) : type_scope.

Notation "E -< F" := (Convertible E F)
(at level 90, left associativity) : type_scope.

Module Import SumNotations.

(* Is this readable? *)

Delimit Scope sum_scope with sum.
Bind Scope sum_scope with sumE.

Notation "(| x )" := (inr x) : sum_scope.
Notation "( x |)" := (inl x) : sum_scope.
Notation "(| x |)" := (inl (inr x)) : sum_scope.
Notation "(|| x )" := (inr (inr x)) : sum_scope.
Notation "(|| x |)" := (inr (inr (inl x))) : sum_scope.
Notation "(||| x )" := (inr (inr (inr x))) : sum_scope.
Notation "(||| x |)" := (inr (inr (inr (inl x)))) : sum_scope.
Notation "(|||| x )" := (inr (inr (inr (inr x)))) : sum_scope.
Notation "(|||| x |)" :=
  (inr (inr (inr (inr (inl x))))) : sum_scope.
Notation "(||||| x )" :=
  (inr (inr (inr (inr (inr x))))) : sum_scope.
Notation "(||||| x |)" :=
  (inr (inr (inr (inr (inr (inl x)))))) : sum_scope.
Notation "(|||||| x )" :=
  (inr (inr (inr (inr (inr (inr x)))))) : sum_scope.
Notation "(|||||| x |)" :=
  (inr (inr (inr (inr (inr (inr (inl x))))))) : sum_scope.
Notation "(||||||| x )" :=
  (inr (inr (inr (inr (inr (inr (inr x))))))) : sum_scope.

End SumNotations.

Open Scope sum_scope.

(*
Definition lift {E F R} `{Convertible E F} : itree E R -> itree F R :=
  hoist (@convert _ _ _).

Class Embed A B :=
  { embed : A -> B }.

Instance Embed_fun T A B `{Embed A B} : Embed (T -> A) (T -> B) :=
  { embed := fun f t => embed (f t) }.

Instance Embed_eff E F R `{Convertible E F} :
  Embed (E R) (itree F R) :=
  { embed := fun e => liftE (convert e) }.

Arguments embed {A B _} e.
*)

Notation compose f g := (fun x => f (g x)).

Definition vis {E F R} `{F -< E}
           (e : F) (k : reaction e -> itree E R) : itree E R :=
  Vis (convert_action e) (compose k convert_reaction).

Definition do {E F} `{F -< E} (e : F) : itree E (reaction e) :=
  Vis (convert_action e) (compose Ret convert_reaction).

Section Failure.

Variant failure : Type :=
| Fail : string -> failure.

Definition failure_reaction : failure -> Type :=
  fun _ => Empty_set.

Canonical Structure failureE : Effect := {|
    action := failure;
    reaction := failure_reaction;
  |}.

Definition fail {E : Effect} `{failureE -< E} {X : Type}
           (reason : string)
  : itree E X :=
  vis (Fail reason) (fun v : Empty_set => match v with end).

End Failure.

Section NonDeterminism.

Variant nondet : Type := Or.

Definition nondet_reaction : nondet -> Type :=
  fun _ => bool.

Canonical Structure nondetE : Effect := {|
    action := nondet;
    reaction := nondet_reaction;
  |}.

Definition or {E} `{nondetE -< E} {R} (k1 k2 : itree E R)
  : itree E R :=
  vis Or (fun b : bool => if b then k1 else k2).

(* This can fail if the list is empty. *)
Definition choose {E} `{nondetE -< E} `{failureE -< E} {X}
  : list X -> itree E X := fix choose' xs : itree E X :=
  match xs with
  | [] => fail "choose: No choice left"
  | x :: xs =>
    or (Ret x) (choose' xs)
  end.

(* TODO: how about a variant of [choose] that expects
   a nonempty list so it can't fail? *)

(* All ways of picking one element in a list apart
   from the others. *)
Definition select {X} : list X -> list (X * list X) :=
  let fix select' pre xs :=
      match xs with
      | [] => []
      | x :: xs' => (x, pre ++ xs') :: select' (pre ++ [x]) xs'
      end in
  select' [].

End NonDeterminism.

(* TODO Another nondet with Or indexed by Fin. *)

Section Reader.

  Variable (env : Type).

  Variant reader : Type :=
  | Ask : reader.

  Definition reader_reaction : reader -> Type :=
    fun _ => env.

  Canonical Structure readerE : Effect := {|
      action := reader;
      reaction := reader_reaction;
    |}.

  Definition ask {E} `{Convertible readerE E} : itree E env :=
    vis Ask Ret.

  Definition eval_reader {E} : eff_hom_r env readerE E :=
    fun e r =>
      match e with
      | Ask => Ret r
      end.

  Definition run_reader {E} R (v : env) (t : itree (readerE +' E) R)
  : itree E R :=
    interp_reader (into_reader eval_reader) t v.

End Reader.

Arguments ask {env E _}.
Arguments run_reader {_ _} [_] _ _.

Section State.

  Variable (S : Type).

  Variant state : Type :=
  | Get : state
  | Put : S -> state.

  Definition state_reaction : state -> Type :=
    fun e =>
      match e with
      | Get => S
      | Put _ => unit
      end.

  Canonical Structure stateE : Effect := {|
      action := state;
      reaction := state_reaction;
    |}.

  Definition get {E} `{stateE -< E} : itree E S := do Get.
  Definition put {E} `{stateE -< E} (s : S) : itree E unit :=
    do (Put s).

  Definition eval_state {E} : eff_hom_s S stateE E :=
    fun e s =>
      match e with
      | Get => Ret (s, s)
      | Put s' => Ret (s', tt)
      end.

  Definition run_state {E R} (v : S) (t : itree (stateE +' E) R)
  : itree E (S * R) :=
    interp_state (into_state eval_state) t v.

(*
Definition run_state {E F : Type -> Type}
           `{Convertible E (stateE +' F)} {R}
           (s : S) (m : itree E R) : itree F (S * R) :=
  run_state' s (hoist (@convert _ _ _) m : itree (stateE +' F) R).

Definition exec_state {E F : Type -> Type}
           `{Convertible E (stateE +' F)} {R}
           (s : S) (m : itree E R) : itree F S :=
  map fst (run_state s m).

Definition eval_state {E F : Type -> Type}
           `{Convertible E (stateE +' F)} {R}
           (s : S) (m : itree E R) : itree F R :=
  map snd (run_state s m).
*)

End State.

Arguments get {S E _}.
Arguments put {S E _}.
Arguments run_state {_ _} [_] _ _.

Section Tagged.
  Variable E : Effect.

  Record tagged (tag : Type) : Type := Tag
    { unTag : E }.

  Definition tagged_reaction (tag : Type) : tagged tag -> Type :=
    fun e => reaction (unTag _ e).

  Canonical Structure taggedE (tag : Type) : Effect := {|
      action := tagged tag;
      reaction := tagged_reaction tag;
    |}.

  Definition eval_tagged (tag : Type) : eff_hom (taggedE tag) E :=
    fun e => Vis (unTag _ e) Ret.

End Tagged.

Arguments unTag {E tag}.
Arguments Tag {E} tag.

Section Counter.

  Class Countable (N : Type) := { zero : N; succ : N -> N }.

  Global Instance Countable_nat : Countable nat | 0 :=
  { zero := O; succ := S }.

  (* Parameterizing by the type of counters makes it easier
   to have more than one counter at once. *)
  Variant counter (N : Type) : Type :=
  | Incr : counter N.

  Global Arguments Incr {N}.

  Definition counter_reaction {N} : counter N -> Type :=
    fun _ => N.

  Canonical Structure counterE N : Effect := {|
      action := counter N;
      reaction := counter_reaction;
    |}.

  Definition incr {N E} `{counterE N -< E} : itree E N :=
    do Incr.

  Definition eval_counter {N E} `{Countable N}
  : eff_hom_s N (counterE N) E :=
    fun e s =>
      match e with
      | Incr => Ret (succ s, s)
      end.

  Definition run_counter {N} `{Countable N} {E R} (t : itree (counterE N +' E) R)
  : itree E R :=
    fmap snd (interp_state (into_state eval_counter) t zero).

End Counter.

Arguments run_counter {_ _ _} [_] _.

Section Writer.

  Variable (W : Type).

  Variant writer : Type :=
  | Tell : W -> writer.

  Definition writer_reaction : writer -> Type :=
    fun _ => unit.

  Canonical Structure writerE : Effect := {|
      action := writer;
      reaction := writer_reaction;
    |}.

  Definition tell {E} `{writerE -< E} (w : W) : itree E unit :=
    do (Tell w).

End Writer.

Section Stop.
  (* "Return" as an effect. *)

  Variant stop_ (S : Type) : Type :=
  | Stop : S -> stop_ S.

  Global Arguments Stop {S}.

  Definition stop_reaction {S} : stop_ S -> Type :=
    fun _ => Empty_set.

  Canonical Structure stopE S : Effect := {|
      action := stop_ S;
      reaction := stop_reaction;
    |}.

  Definition stop {E S R} `{stopE S -< E} : S -> itree E R :=
    fun s =>
      vis (Stop s) (fun v : Empty_set => match v with end).

End Stop.

Arguments stop {E S R _}.

Section Trace.

  Variant trace_ : Type :=
  | Trace : string -> trace_.

  Definition trace_reaction : trace_ -> Type := fun _ => unit.

  Canonical Structure traceE : Effect := {|
      action := trace_;
      reaction := trace_reaction;
    |}.

  Definition trace {E} `{traceE -< E} (msg : string) : itree E unit :=
    do (Trace msg).

  (* todo(gmm): define in terms of `eff_hom` *)
  CoFixpoint ignore_trace {E R} (t : itree (traceE +' E) R) :
    itree E R :=
    match t with
    | Ret r => Ret r
    | Tau t => Tau (ignore_trace t)
    | Vis e k =>
      match e return (@reaction (_ +' _) e -> _) -> _ with
      | ( Trace _ |) => fun k => Tau (ignore_trace (k tt))
      | (| e ) => fun k => Vis e (fun x => ignore_trace (k x))
      end k
    end.

End Trace.
