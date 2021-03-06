From Coq Require Import Arith.
From ITree Require Import ITree.

Inductive IO : Type := Read | Write (n : nat).

Definition IO_reaction : IO -> Type := fun e =>
    match e with
    | Read => nat
    | Write _ => unit
    end.

Canonical Structure IOE : Effect := {|
  action := IO;
  reaction := IO_reaction;
  |}.

Definition example : itree IOE unit :=
  n <- liftE Read;;
  (liftE (Write n) : itree _ unit).

Definition SOME_NUMBER := 13.

Definition test_interp : itree IOE unit -> bool := fun t =>
  match t with
  | Vis e k =>
    match e return (reaction e -> _) -> _ with
    | Read => fun id =>
      match k (id SOME_NUMBER) with
      | Vis (Write n) _ => n =? SOME_NUMBER
      | _ => false
      end
    | _ => fun _ => false
    end (fun x => x)
  | _ => false
  end.

Example test : test_interp example = true := eq_refl.

Require Extraction.

Parameter exit_success : unit.
Parameter exit_failure : unit.
Extract Inlined Constant exit_success =>
  "print_endline ""OK!""; exit 0".
Extract Inlined Constant exit_failure =>
  "print_endline ""IO test failed!""; exit 1".

Definition test_io :=
  if test_interp example then
    exit_success
  else
    exit_failure.

Extraction "io.ml" test_io.
