# UDR-0169 : Pendant la bêta, l'élève ne voit aucune invitation à s'abonner

<!-- index
titre: Bêta sans invitation à s'abonner
statut: Accepté
adr-lie: XXXX (acces-beta-reglage-unique)
problematique: un bêta-testeur ne doit voir ni compte à rebours ni appel à l'abonnement
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-12 |
| **Chantier** | `docs/chantiers/acces-beta` |
| **ADR lié** | ADR-0132 · amende UDR-0158 §3 tant que la bêta est ouverte |
| **Remplacé par** | — |

---

## 1. Contexte

Le bandeau de l'accueil élève (UDR-0158 §3) compte les jours gratuits et pousse « M'abonner ». Pendant la bêta, l'accès est gratuit et complet : ce bandeau ment et décourage le testeur.

## 2. Décision

Le bandeau ne s'affiche plus pendant la bêta ; il n'est pas retiré de l'accueil mais se masque selon le statut de l'accès, pour revenir seul à la fin de la bêta. Mon abonnement, joignable seulement à la main, dit l'accès bêta au lieu d'un compte à rebours.

## 3. Règles d'implémentation

**Structure**

- `app/views/classroom/student_homes/show.html.erb` garde `render "billing/subscriptions/home_notice", access: @access`.
- `app/views/billing/subscriptions/_home_notice.html.erb` ne rend rien sauf si `access&.subscription_pending?` (statut `:free` ou `:blocked`). En `:beta`, `:subscribed` ou `nil` : aucun nœud, aucun lien vers `billing_subscription_path`.
- `app/views/billing/subscriptions/_status.html.erb`, branche `:beta` : icône `gift`, pastille `bg-success-soft text-success`, titre `billing.subscriptions.status.beta.title` (« Accès complet gratuit pendant la bêta »), texte `…beta.text` (« Profite de tous les cours et exercices sans abonnement. »). Même carte `ui_card` que les autres états, titre en `h2`.
- Le reste de Mon abonnement (points relais, saisie du code) est inchangé.

**Tokens** — ceux d'UDR-0158 ; aucun nouveau.

**Comportement** — aucun Turbo nouveau. La redirection de blocage (UDR-0158) ne se déclenche plus : aucun refus n'est rendu en bêta.

**États obligatoires**

- Vide : sans objet (pas de liste). Chargement : sans objet (rendu serveur).
- Erreur : inchangé (erreur de code sur Mon abonnement).
- Succès : accueil sans bandeau ; Mon abonnement avec la carte « bêta ».

**Accessibilité** — l'accueil perd une `section[aria-label="Abonnement"]` ; la carte bêta garde son `h2` et son icône décorative (`aria-hidden` par `ui_icon`).

## 4. Conséquences

- Toute nouvelle vue élève qui invite à s'abonner teste `subscription_pending?`, jamais `status != :subscribed`.
- À la fin de la bêta, l'UDR-0158 s'applique de nouveau sans modification de vue.
