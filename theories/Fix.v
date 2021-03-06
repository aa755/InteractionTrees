(* Implementation of the fixpoint combinator over interaction
 * trees.
 *
 * The implementation is based on the discussion here
 *   https://gmalecha.github.io/reflections/2018/compositional-coinductive-recursion-in-coq
 *)
Require Import ITree.ITree.
Require Import ITree.Morphisms.
Require Import ITree.OpenSum.

Module Type FixSig.
  Section Fix.
    (* the ambient effects *)
    Context {E : Effect}.

    Context {dom : Type}.
    Variable codom : dom -> Type.

    Definition fix_body : Type :=
      forall E',
        (forall t, itree E t -> itree E' t) ->
        (forall x : dom, itree E' (codom x)) ->
        forall x : dom, itree E' (codom x).

    Parameter mfix : fix_body -> forall x : dom, itree E (codom x).

    Axiom mfix_unfold : forall (body : fix_body) (x : dom),
        mfix body x = body E (fun t => id) (mfix body) x.

  End Fix.
End FixSig.

Module FixImpl <: FixSig.
  Section Fix.
    (* the ambient effects *)
    Variable E : Effect.

    Variable dom : Type.
    Variable codom : dom -> Type.

    (* the fixpoint effect, used for representing recursive calls *)
    Variant fixpoint : Type :=
    | call : forall x : dom, fixpoint.

    Definition fixpointE : Effect := {|
        action := fixpoint;
        reaction := fun '(call x) => codom x;
      |}.

    Section mfix.
      (* this is the body of the fixpoint. *)
      Variable f : forall x : dom, itree (fixpointE +' E) (codom x).

      Local CoFixpoint homFix {T : Type}
            (c : itree (fixpointE +' E) T)
        : itree E T :=
        match c with
        | Ret x => Ret x
        | Vis e k =>
          match e return (@reaction (_ +' _) e -> _) -> _ with
          | inl (call x) => fun k =>
            Tau (homFix (bind (f x) k))
          | inr e => fun k =>
            Vis e (fun x => homFix (k x))
          end k
        | Tau x => Tau (homFix x)
        end.

      Definition _mfix (x : dom) : itree E (codom x) :=
        homFix (f x).

      Definition eval_fixpoint (x : fixpointE +' E) :
        itree E (reaction x) :=
        match x with
        | inr e => Vis e Ret
        | inl f0 =>
          match f0 with
          | call x => Tau (_mfix x)
          end
        end.

      Theorem homFix_is_interp : forall {T} (c : itree _ T),
          homFix c = interp eval_fixpoint c.
      Proof.
      Admitted.

      Theorem _mfix_unroll : forall x, _mfix x = homFix (f x).
      Proof. reflexivity. Qed.

    End mfix.

    Section mfixP.
      (* The parametric representation allows us to avoid reasoning about
       * `homFix` and `eval_fixpoint`. They are (essentially) replaced by
       * beta reduction.
       *
       * The downside, is that the type of the body is a little bit more
       * complex, though one could argue that it is a more abstract encoding.
       *)
      Definition fix_body : Type :=
        forall E',
          (forall t, itree E t -> itree E' t) ->
          (forall x : dom, itree E' (codom x)) ->
          forall x : dom, itree E' (codom x).

      Variable body : fix_body.

      Definition mfix
      : forall x : dom, itree E (codom x) :=
        _mfix
          (body (fixpointE +' E)
                (fun t => @interp _ _ (fun e => do e) _)
                (fun x0 : dom => @Vis (fixpointE +' _) _ (inl (call x0)) Ret)).

      Theorem mfix_unfold : forall x,
          mfix x = body E (fun t => id) mfix x.
      Proof. Admitted.
    End mfixP.
  End Fix.
End FixImpl.

Export FixImpl.
Arguments mfix {_ _} _ _ _.
