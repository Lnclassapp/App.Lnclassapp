# UDR-0019 : Invitation équipe — le lien s'affiche une fois dans la modale, la personne invitée crée son compte sur une page publique puis active son second facteur

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B7, critère F-16 (ID-04 remplacée) |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (acceptation exemptée de policy) · [ADR-0031](../adr/0031-second-facteur-totp-pour-l-equipe.md) (TOTP) · [ADR-0037](../adr/0037-nom-et-prenoms-en-deux-champs.md) · [ADR-0038](../adr/0038-comptes-de-l-equipe-et-sous-roles.md) · [ADR-0050](../adr/0050-authentification-et-session.md) · [UDR-0006](0006-shell-applicatif-par-role.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Dans l'ancienne application, n'importe qui créait un compte `team` depuis `/team-signup`, une page publique de quatre champs, avec un code secret saisi en clair (ID-04, faille n°1 de l'inventaire). En V1, un compte `team` naît seulement d'une invitation (ADR-0038) :

- un admin de l'équipe crée l'invitation ;
- il transmet lui-même le lien, par un canal de son choix. Aucun SMS n'est envoyé.

Deux frictions sont à éviter :

- l'admin perd le lien, qui n'est jamais stocké en clair ;
- la personne invitée ne sait pas qu'une étape de sécurité l'attend après la création de son compte.

## 2. Décision

1. **Inviter se fait en modale** (UDR-0006) : le numéro et le rôle (Administration, Contenu, Terrain, chacun décrit en une ligne).
2. **Le succès ne ferme pas la modale : il la remplace.** Le toast « Invitation créée » s'affiche, et la modale montre le lien dans un champ en lecture seule, avec la consigne « Transmettez ce lien à la personne invitée ; il expire dans 72 h. » et l'avertissement que le lien ne s'affiche qu'une fois. Le lien n'est ni dans un flash, ni dans une URL, ni dans un cache (`Cache-Control: no-store`).
3. **L'acceptation est une page publique en deux colonnes**, comme l'inscription enseignant (UDR-0024). Elle demande Nom, Prénom(s), Genre, PIN et confirmation, **jamais le numéro ni le rôle** : les deux viennent de l'invitation.
4. **Après l'acceptation, aucune session n'est ouverte.** La personne arrive sur « Se connecter » avec le toast « Votre compte est créé. Connectez-vous : la vérification en deux étapes vous sera demandée. ». La connexion la mène à l'activation du TOTP, puis à ses codes de secours, puis à `/teams`.
5. **Un lien périmé, déjà servi ou révoqué** montre un message seul, sans formulaire, avec « Se connecter ». Un lien inconnu donne 404.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `teams/invitations/new` : `turbo_frame_tag "modal"` → `ui_modal(id: "invitation-modal", open: true)` → une phrase d'introduction, puis `form#invitation-form` (scope `invitation`) :
  - `ui_field :contact, as: :tel` ;
  - un `<fieldset>` de trois radios `team_role` dans des étiquettes `min-h-tap` empilées, libellé et aide sur deux lignes.
  - Pied : « Annuler » et « Créer l'invitation ».
- `teams/invitations/_created` : `ui_modal(id: "invitation-created-modal", open: true)` → résumé « Invitation pour le 01 00 00 00 09, rôle Contenu. », puis `input#invitation-link[readonly]` relié à sa consigne par `aria-describedby`, puis l'avertissement « ne s'affiche qu'une fois ». Pied : « Fermer ».
- `identity/invitations/show` : la page de l'inscription enseignant, avec les rubriques Identité (Nom, Prénom(s), Genre) et Sécurité (PIN, confirmation). Un encadré `bg-info-soft` annonce la vérification en deux étapes. Le bouton est « Créer mon compte ». L'état périmé est `#invitation-expired[role=alert]` → `ui_empty_state(icon: "clock")`.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement : `bg-error-soft`/`text-error` pour l'alerte générale, `bg-warning-soft` pour « ne s'affiche qu'une fois », `bg-info-soft` pour l'annonce du second facteur, `has-checked:border-brand has-checked:bg-brand-soft` pour les radios. Le lien est en `font-mono` sur `bg-mist`.

**Comportement**
- Ouverture : lien `data-turbo-frame="modal"` vers `/teams/invitations/new`. Hors frame, la même modale s'ouvre sur le shell.
- Erreur : 422, la modale est re-rendue avec les valeurs saisies.
- Succès : `create.turbo_stream.erb` ajoute le toast et fait `turbo_stream.update "modal"` avec `_created`. Repli HTML : la page `created`, en 201.
- `new` et `create` sont refusés en 403 à tout membre qui n'est pas `admin`.
- Acceptation : en Turbo Drive, 422 re-rendu dans la page, succès en 303 vers `/login`. Débit limité à 5 requêtes par minute et par adresse, lecture du lien comprise (429 dans le formulaire). Lien périmé : 410 à la lecture, 422 à l'envoi.

**États obligatoires**
- Erreur :
  - numéro hors format : « Saisissez un numéro ivoirien à 10 chiffres, par exemple 01 02 03 04 05. » ;
  - numéro qui a déjà un compte : « Ce numéro a déjà un compte Lnclass. » ;
  - invitation encore valable pour ce numéro : « Une invitation attend déjà ce numéro. ». Une invitation expirée jamais acceptée ne bloque pas : elle est révoquée, puis la nouvelle est créée ;
  - rôle absent : « Choisissez le rôle de la personne invitée. ».
- Acceptation : chaque message sous son champ, sauf « numéro devenu un compte », qui s'affiche en tête dans le bloc `role="alert"`.
- Succès : le lien dans la modale ; à l'acceptation, le toast sur « Se connecter ».
- Lien périmé : « Ce lien d'invitation n'est plus valable ».

**Accessibilité**
- Rôle et genre sont des `<fieldset>` avec `<legend>` ; leur erreur est reliée par `aria-describedby`.
- PIN et confirmation en `type="password"`, `inputmode="numeric"`, `maxlength="4"`, `autocomplete="new-password"`, jamais renvoyés au re-rendu.
- Cibles tactiles ≥ 48 px ; la modale est une feuille basse sur mobile (UDR-0005).

## 4. Conséquences

- `/team-signup` n'existe plus, et aucune route publique ne crée un compte `team` (test de non-régression).
- L'invitation d'amorçage du seed (ADR-0034) s'accepte par la même page.
- Le lien n'a pas de bouton « Copier » : cette action demanderait un contrôleur Stimulus hors du lot. Le champ en lecture seule se sélectionne et se copie à la main. Un lot ultérieur peut ajouter le bouton sans changer ce contrat.
- Le point d'entrée « Inviter un membre » de l'accueil équipe appartient au lot de cet écran : il ouvre `/teams/invitations/new` dans le frame `modal`.

## Amendement du 2026-09-28 — invitation de la direction

*Chantier [`docs/chantiers/espace-direction-simple`](../../chantiers/espace-direction-simple/prd.md), [UDR-0052](0052-espace-direction-simple.md), [ADR-0065](../adr/0065-espace-direction-simple-en-lecture-seule.md). Statut : `Proposé`.*

- La même page d'acceptation sert l'invitation de la direction. Pour elle, l'encadré `bg-info-soft` dit « Vous rejoignez <établissement> comme direction. », sans annoncer de second facteur, et le toast sur « Se connecter » dit « Votre compte est créé. Connectez-vous avec votre numéro et votre PIN. ».
- La modale d'invitation de la direction s'ouvre depuis la fiche d'un établissement, sans choix de rôle : UDR-0052 §3.

## Amendement du 2026-09-29 — finitions d'interface

*Chantier [`docs/chantiers/finitions-ux`](../../chantiers/finitions-ux/prd.md), [UDR-0054](0054-finitions-d-interface.md). Statut : `Accepté` (avec l'UDR-0054, par le porteur le 2026-09-29). Le texte ci-dessus reste tel qu'il a été accepté ; cette section fait foi en cas d'écart.*

- **Copier** : la modale `_created` gagne, sous `input#invitation-link`, `ui_copy_button(<lien>, label: "Copier le lien", aria_label: "Copier le lien d'invitation", icon: "link")` ; toast « Lien copié. ». C'est le bouton prévu au §4 « par un lot ultérieur ». Pas de WhatsApp ni de SMS. Même règle pour la modale de l'invitation de la direction.
- **Acceptation, §2.4 précisé** (décision du porteur du 2026-09-29) : toujours **aucune session ouverte** ; la personne arrive sur « Se connecter » avec son **numéro pré-rempli** (jamais le PIN) et le focus sur le PIN. Le numéro voyage dans la session Rails chiffrée (`session[:login_contact]`, lu et supprimé par « Se connecter »), jamais dans l'URL ni dans le flash (UDR-0054 §3.8). Toasts inchangés.
- **Focus** : sur « Nom » à l'arrivée sur la page d'acceptation ; sur le premier champ en erreur après un 422. Le §2.3 (« jamais le numéro ») est inchangé : le numéro n'apparaît que sur « Se connecter ».
- Titres : « Inviter un membre de l'équipe · Équipe · Lnclass » (modale) ; page publique « Créer mon compte · Lnclass ».
