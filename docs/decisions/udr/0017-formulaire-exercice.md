# UDR-0017 : Formulaire exercice (questions et propositions imbriquées)

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/) (Lot B5 ; AS-03, AS-04, AS-05, TR-cadre-6) |
| **ADR lié** | [ADR-0026](../adr/0026-contrat-result-entites-et-dto.md) (DTO de saisie) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (brouillon, publication, archivage) · [ADR-0036](../adr/0036-suppression-archivage-et-anonymisation.md) (archiver sans détruire) · [ADR-0054](../adr/0054-moteur-d-evaluation-soumission-et-cloture.md) (questions verrouillées après une session) · UDR-0006 (CRUD Hotwire) · UDR-0007 (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

Un exercice appartient à une fiche essentielle. Il porte un titre, une consigne, un type (fixation ou évaluation) et des questions. Chaque question a un énoncé, une explication montrée après la réponse, un type (Vrai / Faux, Choix unique, 2 ou 3 propositions correctes) et ses propositions, dont certaines sont correctes.

Dans l'ancienne application, le formulaire avait trois défauts :

- le bouton « + Ajouter une question » était inerte : le contrôleur Stimulus `nested-form` qu'il appelait n'existait pas ;
- une question mal construite n'était pas refusée à sa place, ou ne l'était pas du tout ;
- rien n'empêchait de réécrire les questions d'un exercice déjà fait par des élèves, ce qui faussait leurs résultats.

Turbo ne sait pas ajouter un champ au formulaire sans aller-retour avec le serveur. C'est le seul endroit de ce lot où un contrôleur Stimulus est justifié.

## 2. Décision

**Un seul formulaire, dans la grande modale, qui écrit l'exercice, ses questions et leurs propositions en une transaction.**

- La création s'ouvre depuis la fiche essentielle, et la modification depuis l'exercice. Les deux s'ouvrent dans la modale `lg` du layout (UDR-0006) et s'enregistrent sans recharger la page.
- « Ajouter une question », « Ajouter une proposition » et « Retirer » agissent **sans requête**. Ils clonent un `<template>` rendu par le serveur, qui contient déjà les bons noms de champs, libellés et classes.
- La structure de chaque question est une règle de l'entité `Question`. Le formulaire l'annonce dans une aide sous « Questions ». Une question mal construite est refusée **dans son propre bloc**, et tout ce qui a été saisi est conservé.
- Après la première session d'un élève, les questions sont **verrouillées**. Le formulaire garde le titre et la description modifiables. Il affiche les questions, leurs propositions et le type en lecture seule, sous un bandeau « Questions verrouillées ».
- La publication et l'archivage changent le statut sans rien détruire. **Aucune route ne supprime un exercice.**

## 3. Règles d'implémentation

**Structure**

- Routes : `GET /teams/essentials/:essential_slug/exercises/new` et `POST /teams/essentials/:essential_slug/exercises`, puis `GET /teams/exercises/:public_id/edit` et `PATCH /teams/exercises/:public_id`, et enfin `PATCH …/publish` et `PATCH …/archive`. Toutes sont réservées à l'équipe (`Teams::BaseController`, `ManageContentPolicy`).
- `new.html.erb` et `edit.html.erb` : `turbo_frame_tag "modal"` → `ui_modal(id: "exercise-modal", size: :lg, open: true)` → `_form`. Le bouton d'envoi est dans `modal.footer` et vise `form: "exercise-form"`. `new` affiche `#exercise-essential` (« Fiche essentielle : … »).
- `_form.html.erb` contient `form_with scope: :exercise, id: "exercise-form"`. Une erreur `base` s'affiche en tête dans un `role="alert"`. Suivent Titre (`maxlength` 150), Description, Type, puis `section#exercise-questions`.
  - Questions modifiables : `data-controller="teams--nested-form"`, avec pour placeholder `NEW_QUESTION` et pour élément `[data-nested-question]`. La cible `list` reçoit `fields_for :questions`, et la cible `template` contient une question vierge de type Choix unique avec 2 propositions.
  - Questions verrouillées : champ caché `exercise[exercise_type]`, puis `#questions-locked` (`role="status"`), puis une liste `ol` en lecture seule. Aucun champ `questions_attributes` n'est envoyé.
- `_question_fields.html.erb` : `fieldset[data-nested-question]`. Sa légende « Question N » est numérotée par un compteur CSS : retirer une question renumérote les autres, sans JavaScript. Il contient « Retirer la question » (icône, `aria-label`), l'énoncé, le type, l'explication, puis un second contrôleur `teams--nested-form` (`NEW_ANSWER`, `[data-nested-answer]`) pour les propositions.
- `_answer_fields.html.erb` : `div[data-nested-answer]`. Il contient le texte (`maxlength` 500, libellé `sr-only`), la case « Proposition correcte » et « Retirer la proposition ».
- `app/javascript/controllers/teams/nested_form_controller.js` : `add` remplace le placeholder par un index unique, insère le clone et place le focus dans son premier champ. `remove` ôte l'élément le plus proche. Les deux contrôleurs imbriqués ne se gênent pas, car chacun agit dans sa propre portée.

**Tokens**

- Uniquement les tokens `@theme` et les composants `ui_*` (UDR-0005).
- Question : `rounded-card border border-line bg-white p-4`. Bandeau verrouillé : `bg-warning-soft`, icône `lock-closed` en `text-warning`. Proposition correcte en lecture seule : `check-circle` en `text-success`.

**Comportement**

- Création réussie : `create.turbo_stream.erb` → toast « Exercice « … » créé (brouillon). », puis `turbo_stream.refresh(request_id: nil)`, car la page hôte appartient à un autre lot. La modale se ferme sur `turbo:submit-end` réussi.
- Modification réussie : `update.turbo_stream.erb`, sur le même modèle.
- Le toast survit au morphing de la page hôte : chaque toast porte un id unique et `data-turbo-permanent` (socle). Aucun flash n'est posé en plus, il ferait un doublon.
- Saisie invalide : la modale est re-rendue en **422**. Chaque erreur s'affiche sous son champ (titre, énoncé, texte d'une proposition). Une erreur de structure s'affiche en tête de sa question. Les valeurs saisies sont conservées, y compris les questions ajoutées par clonage.
- Questions verrouillées : si une question est envoyée ou si le type change, la réponse est un 422 avec l'erreur `base` « questions verrouillées », et rien n'est écrit.
- Publier : il faut au moins une question bien construite, et la fiche comme son cours doivent être publiés. Sinon, la réponse est un 422 avec un toast d'erreur qui nomme la raison. Publier comme archiver remplace le panneau de statut `content_status_exercise_<public_id>`.
- Repli sans Turbo : chaque écriture redirige vers la page de l'exercice avec un flash (`notice`, ou `alert` pour un refus).

**États obligatoires**

- Vide : à la création, aucune question ; le bouton « Ajouter une question » est la seule action. Un brouillon peut être enregistré sans question, mais un exercice publié en garde au moins une.
- Chargement : sans objet (modale chargée dans son frame, clonage local).
- Erreur : 422 dans la modale ; toast d'erreur pour une transition refusée ; 404 pour une fiche ou un exercice inconnus ; 403 hors équipe.
- Succès : toast, modale refermée, page hôte mise à jour sans rechargement.

**Accessibilité**

- Chaque question est un `fieldset` avec sa `legend`. Les boutons faits d'une seule icône portent un `aria-label` (« Retirer la question », « Retirer la proposition »).
- Chaque champ d'une proposition a un libellé, masqué visuellement mais lu par les lecteurs d'écran. Un champ en erreur porte `aria-invalid` et `aria-describedby` vers son message.
- Le focus va dans le premier champ d'une question ou d'une proposition ajoutée. Les cibles tactiles font au moins 48 px (`min-h-tap`).
- À 390 px, la modale et ses questions ne font jamais défiler la page latéralement : les propositions passent à la ligne (`flex-wrap`, `basis-56`).

## 4. Conséquences

- Les bonnes réponses ne s'affichent que dans ce formulaire, réservé à l'équipe (`RevealAnswersPolicy`). Aucun autre rôle ne les reçoit.
- Le contrôleur `teams--nested-form` est générique (placeholder et sélecteur d'élément passés en valeurs). Un autre formulaire à champs imbriqués peut le réutiliser.
- Interdit désormais sur ce formulaire : un bouton d'ajout qui fait une requête, la suppression d'un exercice, et la réécriture des questions d'un exercice déjà fait par des élèves.
- Preuve : `test/system/teams/exercise_form_test.rb` ajoute puis retire des questions, et enregistre 2 questions et 5 propositions. Il fait corriger dans la modale une question sans proposition correcte, puis rouvre l'exercice en modification, le tout sous `assert_no_page_reload`. Il vérifie aussi l'absence de défilement latéral à 390 px. `test/controllers/teams/exercises_controller_test.rb` couvre le 403, le 422, le verrouillage et TR-cadre-6.
