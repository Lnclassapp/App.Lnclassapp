# UDR-0024 : Inscription enseignant — une page en quatre rubriques, établissements rechargés par la DRENA dans un frame, arrivée sur la déclaration des classes

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D1, critères ID-03, ID-08, SC-26, SC-27, TR-cadre-1 |
| **ADR lié** | [ADR-0030](../adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) (école principale) · [ADR-0037](../adr/0037-nom-et-prenoms-en-deux-champs.md) (nom et prénoms) · [ADR-0050](../adr/0050-authentification-et-session.md) (PIN, session, limite de débit) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Un enseignant s'inscrit seul, depuis `/teacher-signup`. Il doit choisir son établissement parmi des centaines : la DRENA sert de filtre. Dans l'ancienne application :

- la liste des établissements se rechargeait par un `fetch` vers une API JSON, puis par une reconstruction du `<select>` à la main ; sans JavaScript, le formulaire était inutilisable ;
- elle listait aussi les établissements désactivés ;
- le code secret se saisissait **en clair**, sans confirmation ; le nom se tapait en un seul champ, découpé au hasard ;
- une erreur rechargeait toute la page (`turbo: false`).

## 2. Décision

1. **Une seule page en deux colonnes**, comme la connexion : l'accueil à gauche sur grand écran, le formulaire dans une carte à droite. Le formulaire garde les **quatre rubriques** de l'ancienne application : Informations personnelles (Nom, Prénom(s), Genre), Contact (numéro), Établissement et matière (DRENA, établissement, matière), Sécurité (PIN et confirmation).
2. **La DRENA recharge le frame `schools`**, qui ne contient que les établissements **actifs**, triés par nom. Le frame vient de `GET /drenas/:drena_public_id/schools` : Turbo fait le rendu, un contrôleur Stimulus d'une ligne pose seulement son `src`, car Turbo ne sait pas lier un `<select>` à un frame. La même adresse répond en JSON pour l'API (SC-26).
3. **La DRENA n'est pas enregistrée.** Elle voyage avec la liste : le frame porte un champ caché `drena_public_id`. L'établissement envoyé appartient donc toujours à la DRENA dont la liste est affichée ; le serveur le vérifie quand même (établissement actif de cette DRENA, sinon 422).
4. **Sans JavaScript**, le sélecteur de DRENA et le bouton « Afficher les établissements » appartiennent à un petit formulaire `GET` distinct (attribut `form`) : seule la DRENA part dans l'adresse, **jamais le PIN**. Le bouton vit dans un `<noscript>` : un attribut posé par Stimulus serait effacé par le morphing du re-rendu 422.
5. **Erreur en 422 sans rechargement** : la page est re-rendue par Turbo, les saisies gardées (sauf les PIN), chaque message sous son champ.
6. **Succès : la page change**, c'est voulu. La session est ouverte, l'enseignant arrive sur « Quelles classes enseignez-vous ? » (`/teachers/classrooms`) avec le toast « Bienvenue ! Sélectionnez vos classes pour commencer. ». Aucun `*.turbo_stream.erb`.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `identity/teacher_registrations/new` : `main.grid.md:grid-cols-2` ; colonne gauche `bg-brand-soft`, logo, « Bienvenue sur Lnclass » ; colonne droite : `ui_card(padding: :lg)` → titre « Créer un compte enseignant », puis `_form`, puis « Déjà un compte ? Se connecter ».
- `_form` : `form#teacher-signup-drena[method=get]` vide, puis `form#teacher-registration-form` (scope `teacher_registration`, `data-controller="school--drena-schools"`). Chaque rubrique est un `<fieldset>` dont la `<legend>` est en petites capitales `text-mute`.
- Genre : deux radios dans des étiquettes `min-h-tap` côte à côte (Masculin, Féminin), aucune présélection.
- Frame : `school/drena_schools/index` (locals `schools`, `drena_public_id`, `registration`), rendu seul par `School::DrenaSchoolsController` ou dans `_form` par `render template:`. Il contient le champ caché de la DRENA (sans `id`) et `ui_field :school_public_id, as: :select`.
- Aucun attribut `role` dans le formulaire ni dans le DTO : le rôle est imposé à `teacher` par le use case.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement : `ui_field`, `ui_button` (`brand`, `lg`, pleine largeur pour « Créer mon compte »), `bg-error-soft`/`text-error` pour l'alerte générale, `has-checked:border-brand has-checked:bg-brand-soft` pour le genre choisi. Aucune classe de l'ancienne application.

**Comportement**
- Au changement de DRENA : `frame.src = /drenas/<public_id>/schools` (ou `reload()` si c'est la même). DRENA remise à vide : les champs du frame sont désactivés, le serveur redemandera DRENA et établissement.
- Pendant le chargement, le frame (`aria-busy`) passe à 50 % d'opacité.
- Sans DRENA : liste désactivée, aide « Choisissez d'abord votre DRENA. ». DRENA sans établissement actif : liste désactivée, aide « Aucun établissement actif dans cette DRENA. Vérifiez la DRENA choisie. ».
- `/drenas/:drena_public_id/schools` : public, 30 requêtes par minute et par adresse (429 au-delà) ; DRENA inconnue : 404. `POST /teacher-signup` : 5 par minute, 429 re-rendu dans le formulaire.
- Personne déjà connectée : `GET` la renvoie à son accueil ; `POST` reçoit 403.

**États obligatoires**
- Vide : les deux aides du frame ci-dessus.
- Chargement : opacité du frame.
- Erreur : message sous chaque champ (`aria-invalid`, `aria-describedby`) ; numéro pris : « Ce numéro est déjà utilisé. » ; erreur générale (débit, écriture refusée) dans le bloc `role="alert"` en tête.
- Succès : toast sur la page d'arrivée.

**Accessibilité**
- PIN et confirmation en `type="password"`, `inputmode="numeric"`, `maxlength="4"`, `autocomplete="new-password"` ; jamais renvoyés au re-rendu.
- Le genre est un `<fieldset>` avec `<legend>`, son erreur reliée par `aria-describedby`.
- Cibles tactiles ≥ 48 px ; parcours prouvé à 390 px.

## 4. Conséquences

- Aucun sélecteur « école + niveau → classe » n'existe dans l'application (ID-08) : l'élève rejoint sa classe par son code (UDR-0009).
- Le formulaire « Prepa BAC — Ressources Enseignants » (TR-17) n'est pas repris : l'inscription enseignant n'a qu'une entrée.
- Tout autre écran qui aurait besoin des établissements d'une DRENA réutilise l'adresse `/drenas/:drena_public_id/schools`, en frame ou en JSON, plutôt qu'un nouveau point d'accès.
