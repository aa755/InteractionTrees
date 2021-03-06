(* We show the equivalence between the following two ways of
   defining a type of effects:
   - [E = (action : Type, reaction : action -> Type)]
     ([Effect], from [Effect.v])
   - [E : Type -> Type] ([IxEffect], defined below)
 *)

Set Implicit Arguments.
Set Contextual Implicit.
Set Maximal Implicit Insertion.

From ITree Require Effect ITree Morphisms.

Module X.

Local Notation IxEffect := (Type -> Type).

CoInductive itree (E : IxEffect) (R : Type) : Type :=
| Ret (r : R)
| Tau (t : itree E R)
| Vis (X : Type) (e : E X) (k : X -> itree E R)
.

(* [id_itree] as a notation makes it easier to
   [rewrite <- match_itree]. *)
Notation id_ixitree t :=
  match t with
  | Ret r => Ret r
  | Tau t' => Tau t'
  | Vis e k => Vis e k
  end.

Lemma match_itree : forall E R (t : itree E R), t = id_ixitree t.
Proof. destruct t; auto. Qed.

Arguments match_itree {E R} t.

(* The [match] in the definition of bind. *)
Definition bind_match {E T U}
           (k : T -> itree E U)
           (bind : itree E T -> itree E U)
           (c : itree E T) : itree E U :=
    match c with
    | Ret r => k r
    | Tau t => Tau (bind t)
    | Vis e h => Vis e (fun x => bind (h x))
    end.

Definition bind {E T U}
           (c : itree E T) (k : T -> itree E U) : itree E U :=
  (cofix bind' := bind_match k bind') c.

Bind Scope ixitree_scope with itree.
Delimit Scope ixitree_scope with ixitree.

Notation "t1 >>= k2" := (bind t1 k2)
  (at level 50, left associativity) : ixitree_scope.
Notation "x <- t1 ;; t2" := (bind t1 (fun x => t2))
  (at level 100, t1 at next level, right associativity) : ixitree_scope.
Notation "t1 ;; t2" := (bind t1 (fun _ => t2))
  (at level 100, right associativity) : ixitree_scope.
Notation "' p <- t1 ;; t2" :=
  (bind t1 (fun x_ => match x_ with p => t2 end))
  (at level 100, t1 at next level, p pattern, right associativity) : ixitree_scope.

Lemma match_bind {E R S} (t : itree E R) (k : R -> itree E S) :
  (t >>= k)%ixitree = bind_match k (fun t' => bind t' k) t.
Proof.
  rewrite (match_itree (bind _ _)); simpl;
    destruct t; auto.
  - rewrite <- match_itree; auto.
Qed.

Notation "F ~> G" := (forall X, F X -> G X)
  (at level 80, right associativity).

Definition interp_match {E F : IxEffect} {R}
           (f : E ~> itree F) (hom : itree E R -> itree F R)
           (t : itree E R) :=
  match t with
  | Ret r => Ret r
  | Vis e k => bind (f _ e) (fun x => Tau (hom (k x)))
  | Tau t' => Tau (hom t')
  end.

Definition interp {E F : IxEffect}
           (f : E ~> itree F) : itree E ~> itree F :=
  fun _X => cofix hom_f t := interp_match f hom_f t.
Arguments interp {E F} _ [X] _.

Lemma match_interp {E F R} {f : E ~> itree F} (t : itree E R) :
  interp f t = interp_match f (fun t' => interp f t') t.
Proof.
  rewrite (match_itree (interp _ _)).
  simpl; rewrite <- match_itree.
  reflexivity.
Qed.

End X.

Module T.
Include Effect.
Include ITree.
Include Morphisms.
End T.

Module XT.
Import Effect.
Local Notation IxEffect := (Type -> Type).

(* From [Effect] to [IxEffect] *)
Variant ix (E : Effect) : IxEffect :=
| MkIx : forall e : E, ix E (reaction e).

Definition xi_action (E : IxEffect) : Type :=
  { X : Type & E X }.

Definition xi_reaction (E : IxEffect) (e : xi_action E) : Type :=
  projT1 e.

(* From [IxEffect] to [Effect] *)
Canonical Structure xi (E : Type -> Type) : Effect := {|
  action := xi_action E;
  reaction := xi_reaction;
|}.

(*         xi ix                   xi  ix *)
Definition xi_ix (E : Effect) (e : xi (ix E)) : E :=
  match e with
  | existT _ _ (MkIx e') => e'
  end.

(*         ix xi                                ix  xi *)
Definition ix_xi (E : IxEffect) (X : Type) (e : ix (xi E) X) : E X :=
  match e with
  | MkIx (existT _ _ e') => e'
  end.

CoFixpoint XtoT (E : IxEffect) (R : Type)
           (t : X.itree E R) : T.itree (xi E) R :=
  match t with
  | X.Ret r => T.Ret r
  | X.Tau t => T.Tau (XtoT t)
  | X.Vis e k => T.Vis (existT _ _ e : xi_action E)
                       (fun x => XtoT (k x))
  end.

CoFixpoint TtoX (E : Effect) (R : Type)
           (t : T.itree E R) : X.itree (ix E) R :=
  match t with
  | T.Ret r => X.Ret r
  | T.Tau t => X.Tau (TtoX t)
  | T.Vis e k => X.Vis (MkIx e)
                       (fun x => TtoX (k x))
  end.

(* Need to define:

   - mapE : (E ~> F) -> X.itree E ~> F.itree E
     and the same thing of T.itree
   - extensional equality of X.itree (see [Eq.Eq] for T.itree)

   Need to show:

   mapE ix_xi . XtoT . TtoX = id
   mapE xi_ix . TtoX . XtoT = id

   equivalences for [>>=], and (maybe) [interp]:

   XtoT (t >>= k) = (XtoT t >>= fun r => XtoT (k r))

*)

End XT.
