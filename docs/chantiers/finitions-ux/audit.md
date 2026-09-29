# Audit — finitions UX (état des lieux du 2026-09-29)

> Inventaire en **lecture seule** du code de `Develop` (commit `44125507`), préparé pour la phase 1 (Cadrer) du chantier [`finitions-ux`](memo.md). Rien n'est décidé ici : chaque « manque » est un constat, chaque « piste » une option à trancher par le porteur (questions dans le [memo](memo.md)).
>
> Sources lues : `CLAUDE.md`, `docs/guide/conventions.md`, l'index des UDR, UDR-0005 (design system et ses amendements), UDR-0006 (shell, CRUD Hotwire, toasts), UDR-0011, 0014, 0019, 0020, 0027, 0036, 0049, 0050, 0051, 0052, ADR-0049 (CSP stricte), ADR-0051 (navigateurs : plancher Chrome 111, Safari 16.4, Firefox 128), ADR-0062, ADR-0054 ; les 16 contrôleurs Stimulus de `app/javascript/controllers`, `app/views/components`, `app/views/shared`, `app/helpers` ; les 229 vues de `app/views` (78 pages hors partials, layouts et composants) ; `config/routes/*.rb`.

Rôles : **É** élève (`student`) · **Ens** enseignant (`teacher`) · **Éq** équipe (`team`) · **Dir** direction (`school_admin`) · **Pub** public, non connecté.

---

## 0. Ce qui existe déjà et sert de socle

| Brique | Où | Utile pour |
|---|---|---|
| `ui_field(..., hint:)` : aide sous le champ, reliée par `aria-describedby` | `ComponentsHelper`, `components/_field` | point 3 (l'aide *visible* existe, pas l'aide *à la demande*) |
| `ui_page_header(title:, subtitle:)` : un seul `h1` | `components/_page_header` | points 1 et 7 (aucun emplacement pour un lien retour, aucun lien avec `<title>`) |
| `<title><%= content_for(:title) \|\| "Lnclass" %></title>` | `layouts/application` | point 7 |
| `layouts/turbo_rails/frame` (requêtes de frame, modales) : sans `<title>` | `layouts/turbo_rails/frame` | point 7 (normal : Turbo ne lit pas le titre d'un frame) |
| `classroom--join-code-copy` : `navigator.clipboard.writeText`, toast serveur cloné depuis un `<template>` (succès / échec) | `controllers/classroom/join_code_copy_controller.js` | point 4 |
| `identity--share` : WhatsApp, SMS, **copier**, partage natif, comptage `sendBeacon` | `controllers/identity/share_controller.js` | point 4 (réimplémente la même copie et le même toast) |
| `ShareHelper#whatsapp_share_url`, `#sms_share_url` | `app/helpers/share_helper.rb` | point 4 |
| `modal` : `showModal()` natif (piège du focus, Échap) | `controllers/modal_controller.js` | point 2 (sans `autofocus`, le navigateur place le focus sur le **premier focusable** de la `<dialog>`, c'est-à-dire le bouton ✕ de l'en-tête) |
| `teams--nested-form` : focus dans le premier champ ajouté | UDR-0017 | point 2 (seul focus programmé de l'application) |
| `password-reveal` : bouton œil des PIN | UDR-0051 | point 5 (déjà branché sur `turbo:before-cache`) |
| Filtres GET → Turbo Frame `advance` (établissements, catalogue, pilotage) | UDR-0036, 0013, 0049 | point 6 |
| `ui_pagination` | établissements (50/page), recherche du pilotage (20/page) | point 6 |
| `photo_picker` : seul `requestSubmit()` de l'application | `controllers/identity/photo_picker_controller.js` | point 5 (motif d'envoi programmé déjà accepté) |

**Contraintes transverses** : ADR-0049 interdit tout script en ligne (`onclick`, `<script>` sans nonce) → tout comportement passe par un contrôleur Stimulus enregistré par motif (`controllers/<ctx>/<nom>_controller.js`, ADR-0051, aucun manifeste à éditer). Budget JS : 60 Ko gzip (39,7 Ko mesurés le 2026-09-25). Toute nouvelle brique d'interface n'existe qu'une fois appelable par `ComponentsHelper`, visible sur `/design` et couverte par `test/system/design_system_test.rb` (UDR-0005 §4). Les textes restent côté serveur (toasts rendus en HTML, jamais construits par le JS, UDR-0006).

**Décisions existantes qui contredisent certaines demandes** (à amender, pas à contourner) :

- UDR-0011 §3 : « Le code est affiché, **pas copiable** » (Ma classe, élève).
- UDR-0019 : « Le lien n'a pas de bouton « Copier » : cette action demanderait un contrôleur Stimulus hors du lot. […] Un lot ultérieur peut ajouter le bouton sans changer ce contrat. »
- UDR-0020 : le code de récupération du PIN « n'a pas de bouton « Copier » […] ; il est fait pour être dicté ».
- UDR-0027 : « tout écran qui affiche un code d'adhésion […] s'il propose de le copier, réutilise `classroom--join-code-copy` plutôt qu'un nouveau contrôleur ».
- ADR-0062 : le cache des indicateurs de pilotage a été **écarté** (option B) au profit d'une lecture en direct (point 8).

---

## 1. Liens de retour

**Existant.** Aucune UDR ne prescrit de lien retour en général ; chaque UDR d'écran l'a décidé pour elle-même. Trois motifs coexistent :

- **A — fil d'Ariane court** : `nav[aria-label="Fil d'Ariane"]` → lien `chevron-left` `text-mute` `min-h-tap` (8 écrans) ;
- **A′ — fil d'Ariane complet** : `Cours › Matière › Nom` (`chevron-right`), seulement sur la page cours ;
- **B — bouton** `ui_button variant: :ghost, size: :sm, icon: "arrow-left"` (2 écrans) ;
- **C — lien texte** « Retour à la connexion » (PIN oublié) ou bouton en bas de page (« Retour à l'accueil », déclaration des classes).

Les libellés varient aussi : « Retour à %{x} », « Cours : %{x} », « Fiche essentielle : %{x} », « Accueil », « Établissements ».

### Écrans qui ont un retour

| Écran (vue) | Route | Rôle | Motif | Remarque |
|---|---|---|---|---|
| `catalog/courses/show` | `GET /courses/:slug` | tous | A′ | fil complet, le seul |
| `catalog/essentials/show` | `GET /courses/:course_slug/essentials/:slug` | tous | A | « Cours : %{name} » |
| `assessment/exercises/show` | `GET /exercises/:public_id` | tous | A | « Fiche essentielle : %{name} » |
| `assessment/exercise_sessions/show` | `GET /sessions/:public_id` | É | A | « Quitter » |
| `assessment/session_results/show` | `GET /sessions/:public_id/result` | É, Ens | A | |
| `classroom/classrooms/show` (`_header`) | `GET /classrooms/:public_id` | Ens, Éq | A | **incohérent pour l'équipe** : « Accueil » → `home_path_for(role)`, donc l'accueil équipe, alors que l'équipe arrive de la fiche établissement |
| `classroom/classroom_courses/show` | `GET /classrooms/:id/courses/:slug` | Ens | A | « Retour à %{classroom} » |
| `classroom/classroom_essentials/show` | `…/essentials/:essential_slug` | Ens | A | |
| `classroom/course_assignments/index` | `GET /courses/:course_slug/assignments` | Ens | A | « Retour au cours » |
| `teams/schools/show` (`_header`) | `GET /teams/schools/:public_id` | Éq | A | « Établissements » ; ne garde pas les filtres de la liste (lien nu vers `schools_path`) |
| `teams/imports/show` | `GET /teams/imports/:public_id` | Éq | **B** | motif différent |
| `school_admin/classrooms/show` | `GET /school-admin/classrooms/:public_id` | Dir | **B** | motif différent |
| `identity/pin_resets/new` | `GET /identity/pin-reset` | Pub | C | |
| `classroom/teaching_selections/index` | `GET /teachers/classrooms` | Ens | C | bouton en bas, seulement une fois l'accueil fait ; c'est une destination de la navigation, le retour n'est pas indispensable |

### Écrans où le retour manque

| Écran (vue) | Route | Rôle | Arrive depuis | Manque |
|---|---|---|---|---|
| `teams/levels/index` | `GET /teams/levels` | Éq | Accueil équipe › Référentiel | aucun retour vers l'accueil |
| `teams/series/index` | `GET /teams/series` | Éq | idem | idem |
| `teams/materials/index` | `GET /teams/materials` | Éq | idem | idem |
| `teams/drenas/index` | `GET /teams/drenas` | Éq | idem | idem |
| `teams/classroom_plans/show` | `GET /teams/classroom-plan` | Éq | Accueil, Niveaux, Établissements | idem (trois points d'entrée : le « retour » n'est pas univoque) |
| `teams/growth/show` | `GET /teams/growth` | Éq | Accueil › Raccourcis | idem |
| `teams/account_lookups/show` | `GET /teams/accounts` | Éq | Accueil › Raccourcis | idem |
| `identity/referrals/show` | `GET /teachers/invite` | Ens | Mes classes (« Inviter »), accueil | aucun retour vers « Mes classes » (la page déclare pourtant `nav_key "classrooms"`) |
| `identity/profiles/show` | `GET /profile` | tous | menu du compte | pas de retour ; aucune entrée de navigation active (facultatif) |
| `identity/sessions/new` | `GET /login` | Pub | landing | pas de retour à l'accueil public : le logo est une image, pas un lien |
| `classroom/join_codes/new` | `GET /join` | Pub | landing (modale élève) | idem |
| `classroom/joins/new` | `GET /c/:code` | Pub | lien partagé | idem |
| `identity/teacher_registrations/new` | `GET /teacher-signup`, `GET /e/:code` | Pub | landing (modale enseignant), lien de parrainage | idem |
| `identity/pending_teacher_registrations/new` | `GET /teacher-signup/without-code` | Pub | inscription enseignant | a un lien vers l'inscription avec code ; pas vers la landing |
| `identity/invitations/show` | `GET /invitations/:token` | Pub | lien d'invitation | idem (lien « Se connecter » seulement si le lien est périmé) |
| `identity/second_factor_enrollments/new` | `GET /identity/second-factor/enrollment` | Éq | connexion | **aucune sortie** : ni retour, ni « Se déconnecter » (la vérification `second_factors/new`, elle, en a un) |

**Hors besoin** : les destinations de la navigation (accueils, Cours, Ma classe, Mes classes, Établissements, Imports, Pilotage, Travail des élèves, Enseignants), les modales (fermeture ✕ / Échap / Annuler), les pages d'erreur (bouton « Accueil »).

**Estimation** : 16 écrans à doter d'un retour, 3 à aligner sur le motif commun (imports, direction, classe vue par l'équipe) → **≈ 19 écrans**.

---

## 2. Auto-focus sur le premier champ

**Existant.** Aucun contrôleur ni UDR générale ; l'attribut HTML `autofocus` est posé à la main sur 14 formulaires. UDR-0014 le prescrit pour le nom d'un cours (« Le nom reçoit le focus à l'ouverture »), UDR-0017 pour un champ imbriqué ajouté. Dans une `<dialog>` ouverte par `showModal()`, le navigateur honore `autofocus` ; **sans lui, il place le focus sur le bouton ✕** (premier focusable de l'en-tête de `components/_modal`). Sur une page complète, Turbo focalise le premier `[autofocus]` après chaque rendu, y compris le re-rendu 422 : le focus revient au **premier** champ, pas au **premier champ en erreur**.

### Formulaires qui ont l'auto-focus

| Écran | Route | Rôle | Champ | Remarque |
|---|---|---|---|---|
| `identity/sessions/new` | `GET /login` | Pub | numéro | |
| `identity/second_factors/new` | `GET /identity/second-factor` | Éq | code | |
| `classroom/join_codes/new` | `GET /join` | Pub | code de classe | |
| `identity/profile_names/edit` (modale) | `GET /profile/name/edit` | tous | nom | |
| `identity/profile_contacts/edit` (modale) | `GET /profile/contact/edit` | tous | PIN actuel | |
| `identity/profile_pins/edit` (modale) | `GET /profile/pin/edit` | tous | PIN actuel | |
| `teams/courses/_form` (modale) | `/teams/courses/new`, `…/:slug/edit` | Éq | nom | prescrit par UDR-0014 |
| `teams/drenas/_form`, `teams/materials/_form`, `teams/series/_form`, `teams/schools/_form` (modales) | `/teams/{drenas,materials,series}/new\|edit`, `/teams/schools/:id/edit` | Éq | nom | |
| `teams/invitations/new`, `teams/staff_invitations/new` (modales) | `/teams/invitations/new`, `/teams/schools/:id/staff-invitations/new` | Éq | numéro | |
| `teams/school_classrooms/_form` (modale) | `/teams/schools/:id/classrooms/new` | Éq | **nom (3ᵉ champ)** | incohérent : le premier champ est le niveau (`select`) |

### Formulaires où il manque

| Écran | Route | Rôle | Premier champ | Remarque |
|---|---|---|---|---|
| `teams/levels/_form` (modale) | `/teams/levels/new`, `…/:slug/edit` | Éq | nom | focus sur ✕ |
| `teams/essentials/_form` (modale) | `/teams/courses/:slug/essentials/new`, `/teams/essentials/:slug/edit` | Éq | nom | idem ; les formulaires frères (cours) l'ont |
| `teams/exercises/_form` (modale) | `/teams/essentials/:slug/exercises/new`, `/teams/exercises/:id/edit` | Éq | titre | idem |
| `teams/classroom_plans/edit` (modale) | `/teams/classroom-plan/:level(/:series)/edit` | Éq | effectif public | idem |
| `teams/imports/new` (modale) | `/teams/imports/new` | Éq | fichier | focus sur un `input type=file` : à trancher (ouvrir le sélecteur n'est pas souhaitable) |
| `identity/profile_photos/edit` (modale) | `/profile/photo/edit` | tous | fichier | idem |
| `classroom/joins/_signup_form` | `GET /c/:code` | Pub | nom | inscription élève : écran d'entrée clé |
| `identity/teacher_registrations/_form` | `/teacher-signup`, `/e/:code`, `/teacher-signup/without-code` | Pub | nom | idem |
| `identity/invitations/show` | `GET /invitations/:token` | Pub | nom | idem |
| `identity/pin_resets/new` | `GET /identity/pin-reset` | Pub | numéro | |
| `identity/second_factor_enrollments/new` | `GET /identity/second-factor/enrollment` | Éq | code (après le QR) | l'auto-focus ferait défiler la page sous le QR code au téléphone : à trancher |
| `teams/account_lookups/show` | `GET /teams/accounts` | Éq | numéro | champ unique, recherche |
| Confirmations en `<dialog>` (désactiver, supprimer, générer…) | UDR-0042 | Éq | — | pas de champ : le focus tombe sur ✕ ; l'usage veut le bouton le moins destructeur (« Annuler ») |

**Pièges.** Au téléphone, l'auto-focus ouvre le clavier et masque le texte d'accueil (pages publiques en deux colonnes) ; un lecteur d'écran saute ce qui précède le champ. Après un 422, il faut viser le premier `[aria-invalid="true"]` (que `ui_field` pose déjà), sinon l'erreur n'est pas annoncée là où elle est. Un `autofocus` dans une page qui porte aussi une modale ouverte se dispute le focus.

**Estimation** : 12 formulaires sans auto-focus + 1 incohérent + les confirmations → **≈ 13 écrans**, plus la règle « premier champ en erreur après 422 » sur **tous** les formulaires (≈ 30).

---

## 3. Icônes d'infobulle (aide contextuelle)

**Existant.** Pas de composant, pas d'UDR. On trouve à la place : l'aide sous le champ (`hint:`), des encadrés `information-circle` (`bg-info-soft`), des phrases sous les tableaux (« La moyenne s'affiche à partir de 5 élèves… »), des `<details>` dans les aides d'import, des précisions sous les chiffres clés du pilotage (`_figure hint:`), et **un seul attribut `title=`** (`teams/levels/_level_row`, « hors génération ») : invisible au toucher et au clavier, donc inaccessible au téléphone.

Contrainte technique : l'API `popover` (sans JS) exige Safari 17 ; le plancher de l'ADR-0051 est **Safari 16.4** → soit `<details>/<summary>` (partout, sans JS), soit un petit contrôleur Stimulus, soit `popover` en amélioration progressive.

### Indicateurs et champs dont le sens n'est pas évident

| Écran | Route | Rôle | Élément | État actuel | Manque |
|---|---|---|---|---|---|
| `school_admin/classrooms/index` | `GET /school-admin/classrooms` | Dir | « Taux de rendu » | libellé seul | définition (devoirs rendus / devoirs donnés ? sur quelle période ?) |
| idem | idem | Dir | « Moyenne », « — » | phrase sous le tableau ; « — » lu « non calculé » en `sr-only` | aide au point d'usage ; « — » n'est pas expliqué à l'œil |
| `school_admin/classrooms/show` | `GET /school-admin/classrooms/:id` | Dir | tuiles « Taux de rendu », « Moyenne » ; colonnes « Devoirs rendus », « Score moyen » | **aucune phrase** : la règle des 5 élèves n'est pas reprise ici | définition + sens de « — » ; « Moyenne » et « Score moyen » désignent-ils la même chose ? |
| `teams/dashboards/_key_figures` | `GET /teams/dashboard` | Éq | « Réussite moyenne : — » | aucun | pourquoi « — » |
| `teams/dashboards/_drenas` | idem | Éq | colonne « Élèves actifs », « Couverture » | l'aide « Au moins une session commencée » existe dans les chiffres clés, **pas** dans le tableau | reprise de la définition |
| `teams/growth/show` | `GET /teams/growth` | Éq | « k enseignant », « Conversion par partage », « Cycle viral médian », « Élèves arrivés par enseignant actif » | une note générale en bas | une définition par indicateur (jargon de croissance) |
| `teams/levels/_level_row` | `GET /teams/levels` | Éq | badge « hors génération » | `title=` | remplacer par une aide accessible |
| `teams/classroom_plans/show` | `GET /teams/classroom-plan` | Éq | colonnes public / privé | encadré en tête | aide par colonne ? |
| `teams/schools/_header` | `GET /teams/schools/:id` | Éq | « Code d'établissement » vs « code national » | phrase d'aide + lien | distinguer les deux codes |
| `teams/schools/_school_row`, `_header` | `/teams/schools(/:id)` | Éq | statuts brouillon / actif / désactivé | badge seul | conséquence de chaque statut |
| `classroom/classrooms/_header` | `GET /classrooms/:id` | Ens, Éq | « 12 / 40 élèves » | icône avec libellé pour lecteur d'écran seulement | que « 40 » est le plafond |
| `classroom/classrooms/_roster` | idem | Ens | « Dernier score », « Générer un code de récupération » | `issue_code_hint` en texte | sens du score (sur 20 ? en % ?) |
| `classroom/student_homes/*`, `assessment/*` | `/students`, `/exercises/:id`, `/sessions/:id/result` | É | badges Bronze / Argent / Or / Diamant, « Maîtrise » (Acquis / Fragile / En difficulté), « — » | badge seul | seuils (ADR-0033) |
| `catalog/*`, `teams/*` | `/courses…` | Éq | statut de contenu (brouillon / publié / archivé) | badge + panneau | facultatif |
| `identity/teacher_registrations/_form` | `/teacher-signup` | Pub | « Code d'établissement » | `hint` « 6 caractères, transmis par votre établissement. » | *qui* le transmet, *où* le trouver |
| `identity/pending_teacher_registrations/_school_fields` | `/teacher-signup/without-code` | Pub | « code national » | `hint` « 6 chiffres, celui des résultats du BEPC » | suffisant ? |
| Champs PIN (13, UDR-0051) | connexion, inscriptions, profil | tous | « PIN » | `hint` « 4 chiffres » | pourquoi un PIN, quoi faire si oublié (lien existe à la connexion seulement) |
| `identity/second_factor_enrollments/new` | `/identity/second-factor/enrollment` | Éq | « application d'authentification », clé manuelle | sous-titre | quelles applications, à quoi sert la clé |
| `identity/second_factors/new` | `/identity/second-factor` | Éq | « code de secours » | `hint` | facultatif |

**Estimation** : **≈ 14 écrans**, ≈ 25 éléments.

---

## 4. Copier les liens et codes à partager

**Existant.** Deux contrôleurs pour un même geste (`classroom--join-code-copy`, utilisé aussi pour le code d'**établissement**, et `identity--share`, qui recopie la logique de copie et de toast). Trois écrans copient.

| Élément partagé | Écran | Route | Rôle | État | Manque / remarque |
|---|---|---|---|---|---|
| Code de classe | `classroom/classrooms/_header` | `GET /classrooms/:id` | Ens, Éq | ✅ « Copier » + WhatsApp | le **lien** `/c/<code>` n'est pas copiable (seulement dans le message WhatsApp) |
| Code d'établissement **et** lien `/e/<code>` | `teams/schools/_header` | `GET /teams/schools/:id` | Éq | ✅ « Copier le code », « Copier le lien » | contrôleur nommé `classroom--…` pour un objet `school` |
| Lien de parrainage `/e/<code>?ref=` | `identity/referrals/_invite` | `/teachers/invite`, `/teachers` | Ens | ✅ WhatsApp, SMS, copier, partage natif (comptés) | référence du motif le plus complet |
| **Lien d'invitation équipe** `/invitations/<token>` | `teams/invitations/_created` (modale) | `POST /teams/invitations` | Éq | ❌ champ en lecture seule | **montré une seule fois** : le geste le plus critique ; UDR-0019 a reporté le bouton « à un lot ultérieur » |
| **Lien d'invitation direction** | `teams/staff_invitations/_created` (modale) | `POST /teams/schools/:id/staff-invitations` | Éq | ❌ idem | idem |
| Codes de classe d'un établissement | `teams/schools/_classroom_group` | `GET /teams/schools/:id` | Éq | ❌ affichés en liste | copie par ligne ? |
| Code de classe (élève) | `classroom/student_classrooms/show`, `student_homes/_classroom_card` | `/students/classroom`, `/students` | É | ❌ affiché | **interdit par UDR-0011 §3** (l'élève le dicte) |
| Code de récupération du PIN | `identity/pin_recovery_codes/_code` (modale) | `POST /accounts/:id/pin-recovery-codes` | Ens, Éq | ❌ `select-all` | **écarté par UDR-0020** (fait pour être dicté) |
| Clé secrète TOTP (saisie manuelle) | `identity/second_factor_enrollments/new` | `/identity/second-factor/enrollment` | Éq | ❌ texte | utile au téléphone quand on ne peut pas scanner son propre écran |
| Codes de secours (10) | `identity/second_factor_enrollments/backup_codes` | `POST /identity/second-factor/enrollment` | Éq | ❌ liste | copier tout / télécharger (voir point 5) |
| Lien public d'un cours | `catalog/courses/show` | `/courses/:slug` | tous | ❌ | pas de besoin exprimé ; hors périmètre probable |

**Estimation** : 5 écrans certains (2 invitations, lien de classe, clé TOTP, codes de secours), 3 à trancher (codes de classe de la fiche établissement, code élève, code de récupération) → **5 à 8 écrans**, plus la fusion des deux contrôleurs existants.

---

## 5. Auto-submit sur les gestes clés

Aucun envoi automatique aujourd'hui, sauf `photo_picker` (`requestSubmit` après recadrage). WCAG 3.2.2 (« Au changement de saisie ») : un changement de contexte déclenché par la saisie doit être **annoncé avant** ; le bouton d'envoi doit rester.

### 5a. Lien d'invitation (acceptation)

| | |
|---|---|
| **Écran** | `identity/invitations/show` · `GET /invitations/:token`, `POST /invitations/:token` (`accept`) · Pub → Éq ou Dir |
| **Parcours actuel** | lien reçu → formulaire Nom, Prénom(s), Genre, PIN, Confirmation → « Créer mon compte » → **redirection vers `/login`** avec un toast → la personne ressaisit son **numéro** et son PIN → équipe : enrôlement du second facteur ; direction : « Travail des élèves ». Limite : 5 envois / min / IP. |
| **Ce qu'« auto-submit » peut vouloir dire** | le formulaire ne peut pas partir seul (il attend des données). Deux lectures : **(i)** ouvrir la session dès l'acceptation, sans repasser par `/login` (le détenteur du lien vient de choisir son PIN) ; **(ii)** pré-remplir le numéro sur `/login` et y mettre le focus sur le PIN. |
| **Pièges** | (i) touche l'ADR-0050 (authentification et session) et l'ADR-0031 (le second facteur reste obligatoire pour l'équipe) : c'est une décision d'architecture ; un lien intercepté ouvrirait directement une session. (ii) le numéro ne doit transiter ni par l'URL ni par le flash en clair. |
| **Gestes voisins** | `/c/<code>` (élève) et `/e/<code>?ref=` (enseignant) pré-remplissent déjà le code ; `/join` pourrait partir seul au 5ᵉ caractère valide (3 lettres + 2 chiffres) — limite de 10 / min / IP. |

### 5b. Second facteur (6 chiffres)

| | Vérification | Enrôlement |
|---|---|---|
| **Écran** | `identity/second_factors/new` · `GET/POST /identity/second-factor` · Éq | `identity/second_factor_enrollments/new` · `GET/POST /identity/second-factor/enrollment` · Éq |
| **Parcours actuel** | champ unique, `autofocus`, `autocomplete="one-time-code"`, `inputmode="text"`, `maxlength 12` : il accepte **un code TOTP (6 chiffres) ou un code de secours (10 caractères base58)** → bouton « Vérifier » | QR code, clé manuelle, champ 6 chiffres (`inputmode="numeric"`, pas d'`autofocus`) → « Activer » → codes de secours rendus dans la même réponse (Turbo Stream `replace`) |
| **Avec auto-submit** | envoi dès que la valeur (espaces retirés) vaut exactement `^\d{6}$` | envoi au 6ᵉ chiffre |

**Pièges** :

- **Codes de secours** : base58 contient les chiffres 1-9 ; un code de secours qui commence par 6 chiffres partirait tronqué (probabilité ≈ 1 / 72 000 par code, mais réelle). Options : bascule explicite « J'utilise un code de secours », ou n'envoyer que si le champ a été rempli d'un coup (collage, remplissage automatique) ou après une courte pause.
- **Verrouillage** : 5 envois / min / IP (`rate_limit`) et paliers de `Entities::Identity::Lockout` sur les échecs consécutifs. Une faute de frappe envoyée automatiquement **consomme un essai**, là où l'envoi manuel laissait corriger. Après un 422, le champ est vidé (`value: ""`) : pas de boucle, mais ne pas ré-envoyer automatiquement tant que la valeur n'a pas changé.
- **Double soumission** : l'événement `input` du remplissage automatique puis la touche Entrée ; garder un verrou tant que `turbo:submit-end` n'est pas arrivé.
- **iOS / gestionnaires de mots de passe** : `one-time-code` propose le code (SMS, trousseau iCloud, 1Password) et l'insère d'un seul `input` ; certains insèrent caractère par caractère → ne pas se fier au nombre d'événements. Pour un TOTP, iOS ne propose un code que si le trousseau en porte le secret.
- **Lecteurs d'écran** : annoncer dans l'aide que le code part seul au 6ᵉ chiffre ; ne pas déplacer le focus ; laisser le bouton (sans JS, rien ne change).
- **CSP** : contrôleur Stimulus, aucun `oninput`.

### 5c. Téléchargement des codes de secours

| | |
|---|---|
| **Écran** | `identity/second_factor_enrollments/backup_codes` · réponse du `POST /identity/second-factor/enrollment` (Turbo Stream ou HTML) · Éq |
| **Parcours actuel** | 10 codes en grille, « montrés une seule fois », bouton « C'est noté » → `/teams`. Ni copier, ni télécharger, ni imprimer. Les codes ne sont **stockés qu'en empreinte** : ils n'existent en clair que dans cette réponse → aucun téléchargement côté serveur possible après coup. |
| **Avec auto-submit** | déclencher **automatiquement** le téléchargement d'un fichier texte (`lnclass-codes-de-secours.txt`) construit par le navigateur (Blob) dès l'affichage, en plus des boutons « Télécharger », « Copier », « Imprimer ». |
| **Pièges** | un téléchargement sans geste de l'utilisateur est bloqué, ou demande confirmation, selon le navigateur (Safari iOS, Chrome Android) : il **ne doit jamais conditionner** « C'est noté », et on ne peut pas savoir s'il a réussi → le bouton manuel reste. Pas de `data:` ni de script en ligne (ADR-0049) : Blob + `a[download]` dans un contrôleur. Annonce du téléchargement pour les lecteurs d'écran. |
| **Sécurité (constat hors demande)** | la page des codes n'a **ni `Cache-Control: no-store`** (posé pour le code de récupération et les liens d'invitation) **ni exemption du cache Turbo** : l'aperçu Turbo ou le cache arrière du navigateur peuvent ré-afficher les codes après « C'est noté » puis Retour. Idem pour la clé TOTP de la page d'enrôlement. À traiter dans ce chantier ou dans un correctif dédié. |

**Estimation** : **4 écrans** (acceptation d'invitation, vérification, enrôlement, codes de secours), +1 à trancher (`/join`).

---

## 6. Recherche dynamique

**Existant.** Aucune recherche « pendant la frappe » : toutes les recherches sont des **formulaires GET à bouton**, visant un Turbo Frame avec `data-turbo-action="advance"` (l'URL garde les filtres, UDR-0036). UDR-0036 §4 fait de ce patron la règle pour « toute autre liste d'administration longue ». Aucun contrôleur `debounce`/`search`.

| Liste | Écran | Route | Rôle | Volume | Recherche actuelle | Remarque |
|---|---|---|---|---|---|---|
| Établissements | `teams/schools/index` + `_filters` | `GET /teams/schools` | Éq | ≈ 600+ (SC-04), 50 / page | GET → frame `schools`, champ nom / sigle / code national (sans accents), 4 listes ; bouton « Filtrer » | candidat n° 1 ; `LIKE '%…%'` sur `translate(lower(name))` **sans index trigramme** : une requête par frappe = un parcours complet |
| Élèves et enseignants | `teams/dashboards/_search` | `GET /teams/dashboard?q=` | Éq | tous les comptes, 20 / page | GET → frame `team_dashboard_search` ; min. 2 lettres ou 4 chiffres ; bouton | `LIKE '%…%'` sur `users` |
| Catalogue | `catalog/courses/index` | `GET /courses` | tous | tous les cours, **sans pagination** | 2 listes (niveau, matière) + bouton ; **pas de champ texte** | recherche par nom attendue quand le catalogue grossit ; les listes pourraient partir au changement |
| Pilotage — DRENA | `teams/dashboards/_filters` | `GET /teams/dashboard` | Éq | ≈ 40 | liste + bouton « Filtrer » | envoi au changement plutôt que recherche |
| Compte par numéro | `teams/account_lookups/show` | `GET /teams/accounts` | Éq | 1 résultat | GET + bouton | recherche exacte : le live n'apporte rien |
| Élèves d'une classe | `classroom/classrooms/_roster` | `GET /classrooms/:id` | Ens | jusqu'au plafond (≈ 40-80) | aucune | filtre côté client (le roster est déjà dans la page) pour trouver l'élève à débloquer |
| Classes de l'établissement | `classroom/teaching_selections/index` | `GET /teachers/classrooms` | Ens | toutes les classes de l'école, par niveau | aucune | filtre côté client |
| Classes d'un établissement | `teams/schools/show` | `GET /teams/schools/:id` | Éq | par niveau | aucune | faible besoin |
| Établissements d'une DRENA | `school/drena_schools/index` (frame) | `GET /drenas/:id/schools` | Pub | dizaines à centaines | `<select>` | liste longue au téléphone : combobox filtrable ? (plus lourd) |
| Niveaux, séries, matières, DRENA, imports, enseignants (direction) | `teams/*/index`, `school_admin/teachers/index` | — | Éq, Dir | < 50 | aucune | pas de besoin |

**Pièges** : `advance` à chaque frappe remplit l'historique (préférer `replace` pendant la frappe) ; le champ doit rester **hors** du frame rechargé (c'est déjà le cas) sinon il perd le focus ; délai de 300 ms environ et seuil minimal ; annoncer le nombre de résultats (`aria-live`, déjà présent pour le catalogue) ; Turbo annule la requête précédente d'un même frame ; sans JS, le bouton doit rester.

**Estimation** : 3 recherches serveur à rendre dynamiques (établissements, pilotage, catalogue avec un champ à créer), 2 filtres côté client (roster, classes de l'enseignant), 2 listes à envoyer au changement (filtres du catalogue et du pilotage) → **≈ 5 écrans**.

---

## 7. Titre de page (`<title>`)

**Layout.** `layouts/application` : `<title><%= content_for(:title) || "Lnclass" %></title>` ; `layouts/shell` en hérite ; `layouts/turbo_rails/frame` n'a pas de titre (normal). Pas de helper : chaque vue écrit `content_for :title, t(".page_title")` (ou `.title`).

**Couverture.** 78 pages (hors partials, layouts, composants, Turbo Streams) : **58 posent un titre**, 20 non.

### Vues sans `content_for :title`

| Vue | Route | Rôle | Nature | Impact |
|---|---|---|---|---|
| `teams/levels/new`, `teams/levels/edit` | `/teams/levels/new`, `…/:slug/edit` | Éq | modale (frame) | titre « Lnclass » si l'URL est ouverte directement (rechargement, nouvel onglet, sans JS) |
| `teams/series/new`, `…/edit` | `/teams/series/…` | Éq | modale | idem |
| `teams/materials/new`, `…/edit` | `/teams/materials/…` | Éq | modale | idem |
| `teams/courses/new`, `…/edit` | `/teams/courses/…` | Éq | modale | idem |
| `teams/essentials/new`, `…/edit` | `/teams/courses/:slug/essentials/new`, `/teams/essentials/:slug/edit` | Éq | modale | idem |
| `teams/exercises/new`, `…/edit` | `/teams/essentials/:slug/exercises/new`, `/teams/exercises/:id/edit` | Éq | modale | idem |
| `teams/schools/edit` | `/teams/schools/:id/edit` | Éq | modale | idem |
| `teams/school_classrooms/new` | `/teams/schools/:id/classrooms/new` | Éq | modale | idem |
| `teams/classroom_plans/edit` | `/teams/classroom-plan/:level(/:series)/edit` | Éq | modale | idem |
| `teams/imports/new` | `/teams/imports/new` | Éq | modale | idem |
| `identity/pending_teacher_registrations/new` | `/teacher-signup/without-code` | Pub | `render template:` | **faux positif** : hérite du titre de `teacher_registrations/new` |
| `school/drena_schools/index` | `/drenas/:id/schools` | Pub | frame | sans objet |
| `design/modal`, `design/frame` | `/design/…` (hors production) | — | démonstration | sans objet |

Les modales **frères** `teams/drenas/new|edit`, `teams/invitations/new`, `teams/staff_invitations/new`, `identity/profile_*/edit` posent un titre : l'usage n'est pas uniforme (16 modales sans, 8 avec).

### Incohérences des titres existants

- **Suffixe** : 14 titres finissent par « · Lnclass » (pages publiques, mais aussi `identity/referrals/show` « Inviter un collègue · Lnclass » et `teams/growth/show` « Croissance · Lnclass » dans le shell) ; les ≈ 40 autres n'ont pas de marque. Variante isolée : « Rejoindre Lnclass · Direction ».
- **Séparateurs** : « · », « — » et « : » (« Fiche essentielle : %{name} », « %{name} — Cours », « Import : %{kind} »).
- **Titres identiques** : « Accueil » pour l'élève, l'enseignant et l'équipe (onglets indiscernables pour un compte qui en ouvre plusieurs, historique illisible).
- **Titre brut** : `school_admin/classrooms/show` pose `classroom.name` sans traduction ni contexte ; `teams/imports/show` retombe sur la clé brute `kind` si le type est inconnu.
- **Titre et `h1`** : aucun lien entre `content_for :title` et `ui_page_header(title:)` ; les deux sont écrits séparément (deux clés de locale par page).
- **Navigation par frame** (`advance`) : les filtres changent l'URL, pas le titre (acceptable).

**Estimation** : 16 modales à titrer (faible impact) + ≈ 58 titres à harmoniser si l'on adopte un helper à suffixe → **≈ 74 vues**, mais un changement mécanique.

---

## 8. Caching (ajout du porteur, 2026-09-29)

> **Ce volet relève d'un chantier `optimize` séparé** (`/optimize <slug>`) : on mesure avant d'optimiser. Ce chantier-ci (`feature`, finitions d'interface) n'y touche pas ; l'état des lieux ci-dessous sert à ouvrir l'autre chantier.

| Couche | État actuel | Constat |
|---|---|---|
| **Store** | production `:solid_cache_store` (`config/cache.yml` : `max_size` 256 Mo, `namespace` par environnement, `max_age` commenté) ; table `solid_cache_entries` dans la base principale (ADR-0010, ADR-0052) ; développement `:memory_store` (`perform_caching` basculé par `bin/rails dev:cache`) ; test `:memory_store`, `perform_caching = false` | seul client réel : **`rate_limit`** des contrôleurs (connexion, second facteur, invitations, `/join`, inscriptions), qui s'appuie par défaut sur `Rails.cache` |
| **Fragments de vue** | aucun `cache` / `cache_if` / `render …, cached: true` dans `app/views` | contrainte à respecter : ADR-0054 et ADR-0028 interdisent tout fragment contenant une proposition correcte (rendu enseignant resservi à un élève) |
| **`Rails.cache.fetch`** | aucun dans `app/` | ADR-0062 a **écarté** le cache des indicateurs de pilotage (option B : chiffres périmés, clé difficile à tenir complète) au profit de requêtes groupées en nombre fixe |
| **HTTP** | aucun `fresh_when` / `stale?` ; `expires_in … public: false` sur la photo de profil ; `Cache-Control: no-store` sur le code de récupération et les deux liens d'invitation ; les autres pages ont l'en-tête par défaut de Rails (`max-age=0, private, must-revalidate`) et l'ETag de `Rack::ETag` (économise la bande passante, pas le calcul) | page des codes de secours et page d'enrôlement TOTP **sans** `no-store` (voir 5c) |
| **Cache Turbo** | aucune exemption (`turbo_exempts_page_from_cache` / `turbo-cache-control`) ; modales, menus et PIN se referment ou se remasquent sur `turbo:before-cache` ; `turbo_refreshes_with method: :morph` ; **préchargement au survol** de Turbo 8 actif par défaut (pas de `turbo-prefetch=false`) | le préchargement double les requêtes des pages lourdes survolées ; aperçu de cache à exclure sur les pages à secret |
| **Assets** | Propshaft (empreintes dans les noms), `public_file_server.headers` = `public, max-age=1 an` en production ; **Thruster** devant Puma (`bin/thrust`, Dockerfile) : compression et cache HTTP des assets, X-Sendfile | conforme ; pas d'`immutable` explicite (Thruster le gère pour les fichiers à empreinte) |

**Écrans lourds qui gagneraient le plus** (à mesurer avant tout) :

| Écran | Route | Rôle | Pourquoi |
|---|---|---|---|
| Pilotage | `GET /teams/dashboard` | Éq | comptages sur `users`, `exercise_sessions`, `classroom_assignments` **sans index sur leurs dates** (coût mesuré dans l'ADR-0062) ; recherche `LIKE '%…%'` |
| Croissance | `GET /teams/growth` | Éq | agrégats de parrainage et classements |
| Établissements | `GET /teams/schools` | Éq | 600+ lignes filtrées par `LIKE` sans index ; la recherche dynamique (point 6) multiplierait les requêtes |
| Catalogue | `GET /courses` | tous | liste complète sans pagination, cartes par cours |
| Page cours / fiche | `/courses/:slug`, `/courses/:slug/essentials/:slug` | tous | texte riche assaini + KaTeX à chaque vue (candidat naturel au fragment, **hors** propositions correctes) |
| Travail des élèves | `GET /school-admin/classrooms`, `/:id` | Dir | taux et moyennes calculés à chaque vue |
| Accueils | `/students`, `/teachers`, `/teams` | É, Ens, Éq | plusieurs sections et requêtes par page |

---

## Synthèse

### Briques communes proposées

| Brique | Nature | Sert aux points | Remarque |
|---|---|---|---|
| `clipboard` | contrôleur Stimulus générique (`controllers/clipboard_controller.js`) + `ui_copy_button(value, label:, copied:)` dans `ComponentsHelper` | 4, 5c | remplace `classroom--join-code-copy` et la copie d'`identity--share` (qui garde WhatsApp, SMS, natif et le comptage) ; amende UDR-0027 §64 |
| `autofocus` | contrôleur Stimulus posé par `ui_modal` et par les formulaires de page : premier `[aria-invalid="true"]`, sinon premier champ, sinon « Annuler » dans une confirmation | 2 | ou, plus simple : `autofocus: true` systématique via `ui_field(..., autofocus:)` et une règle dans UDR-0005 |
| `autosubmit` | contrôleur Stimulus : `requestSubmit()` quand la valeur correspond à un motif (`pattern` en valeur), verrou jusqu'à `turbo:submit-end`, une seule fois par valeur | 5a (`/join`), 5b | aide « envoyé automatiquement » obligatoire |
| `download` | contrôleur Stimulus : Blob texte + `a[download]`, déclenchement manuel et, si décidé, automatique | 5c | + `no-store` et exemption du cache Turbo sur la page |
| `search` | contrôleur Stimulus : `input` → délai ≈ 300 ms → `requestSubmit()` avec `turbo-action=replace` ; `change` sur les listes ; variante côté client (masquer les lignes) | 6 | amende UDR-0036 (patron des listes longues) |
| `back_link` | partial `components/_back_link` + `ui_back_link(label, href)`, ou slot `back:` de `ui_page_header` | 1 | unifie les motifs A, B, C |
| `info_tip` | helper `ui_info_tip(text, label:)` : icône `information-circle` 48 px, `<details>/<summary>` (ou `popover` progressif) | 3 | remplace `title=` ; Safari 16.4 impose un repli sans `popover` |
| `page_title` | helper `page_title(*parties)` → « Partie · Partie · Lnclass », éventuellement alimenté par `ui_page_header` | 7 | + test : toute page non partielle pose un titre |

Chaque brique : API dans `ComponentsHelper`, démonstration sur `/design`, test système, amendement de l'UDR-0005 (composant) — probablement une **UDR « finitions »** unique plutôt qu'un amendement par écran.

### Écrans touchés par point (estimation)

| Point | Écrans | Nature |
|---|---|---|
| 1. Retour | ≈ 19 (16 manques + 3 à aligner) | partial + une ligne par vue |
| 2. Auto-focus | ≈ 13 (+ règle 422 sur ≈ 30 formulaires) | attribut ou contrôleur |
| 3. Infobulles | ≈ 14 (≈ 25 éléments) | helper + textes à écrire (**contenu à valider par le porteur**) |
| 4. Copier | 5 certains + 3 à trancher | contrôleur + 3 UDR à amender (0011, 0019, 0020) |
| 5. Auto-submit | 4 (+1 à trancher) | 2 contrôleurs ; 5a peut toucher l'ADR-0050 |
| 6. Recherche dynamique | ≈ 5 | contrôleur ; dépend des index (volet 8) |
| 7. Titre de page | 16 à ajouter, ≈ 58 à harmoniser | helper, mécanique |
| 8. Caching | — | **chantier `optimize` séparé** |

### Constats hors demande, relevés en passant

- Page des codes de secours et clé TOTP sans `no-store` ni exemption du cache Turbo (5c).
- Enrôlement du second facteur sans « Se déconnecter » (1).
- « Accueil » ramène l'équipe à son accueil depuis la page d'une classe, au lieu de la fiche établissement (1).
- UDR-0052 prescrit `nav_key "classrooms"` pour « Travail des élèves », la vue pose `"student_work"` (à vérifier contre l'amendement de navigation de l'UDR-0006).
