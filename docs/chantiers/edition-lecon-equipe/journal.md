# Journal — Édition d'une leçon par l'équipe

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Menu ⋮ (statut + transitions) sous le titre de chaque notion de la fiche de révision et de chaque exercice de la feuille, équipe seulement | Seuls endroits où ces contenus se lisent depuis ADR-0113 et ADR-0121 | Non : amendement UDR-0042 |
| 2026-11-14 | La modale « Modifier » dit que notions et exercices se réimportent, avec un lien « Importer la leçon » | Le formulaire est juste ; c'est l'attente qui ne l'est pas | Non : amendement UDR-0014 |

## À trancher

- [x] 2026-11-14 · edition-lecon-equipe · Corriger à l'écran le texte d'une notion ou d'un exercice d'une leçon publiée déjà travaillée par des élèves ? ADR-0113 §4.6 l'interdit (« la leçon se réimporte »). — appliqué : rien (ADR inchangé) ; autres : (a) entrée « Modifier le texte » au menu ⋮ d'une notion et d'un exercice : modale qui ne touche que les textes (titre, sujet, énoncés, propositions, indices), jamais le nombre ni l'ordre des questions ni la bonne réponse, pour que les copies et notes déjà rendues gardent leur sens ; journalisée (AuditLog) ; (b) réimport partiel d'une seule notion ; recommandé : (a), par un ADR qui amende ADR-0113 §4.6, en chantier `feature` séparé. **Tranché par le porteur le 2026-11-14** : (a), bonne réponse modifiable même après des tentatives sans recalcul ; chantier `edition-texte-lecon`, ADR-0113 §4.6 amendé.
- [x] 2026-11-14 · edition-lecon-equipe · Le champ « Contenu » (Action Text) de la modale n'est plus montré sur aucune page depuis ADR-0110/0116. — appliqué : gardé, la modale renvoie vers l'import ; autres : le retirer du formulaire (UDR-0014) ; recommandé : le retirer, en retouche. **Tranché par le porteur le 2026-11-14** : il reste.

## Ce qui a dérapé

- Premier jet du test : j'attendais « Archiver » sur un brouillon ; `ContentStatus::TRANSITIONS` ne le permet pas (brouillon → publié seulement). Test corrigé.
- 2026-11-14 : #598 a cassé `Develop` (train #596). Le menu ⋮ de l'exercice avait remplacé le badge `.ps-status` « Brouillon » du titre `.ps-paper-exercise-title` ; trois tests d'intégration le décrivent (`team_assigns_from_sheet`, `sheet_paper`, `prepare_interros`). `bin/ci-quiet` niveau pr ne les a pas joués : il suit les tests des fichiers touchés, et la vue partielle `sheets/_paper` n'y mène pas. Correctif `fix/badge-statut-feuille` : badge rétabli dans le titre, menu gardé sous le titre. Leçon : pour une vue partagée, jouer `test/integration/catalog` et `test/integration/classroom` avant la PR.

## Ce qu'on a appris sur la codebase

**Rapport de root cause.**

1. Chaîne d'appels : `Catalog::CoursesController#show` → `catalog/courses/show` → `_revision_sheet` → `catalog/revision_sheets/_sheet` (une section par notion, `RevisionSheetQuery::Notion` sans statut) ; et `Catalog::PrepareSheetsController#show` → `catalog/prepare_sheets/_sheet` → `catalog/courses/sheets/_paper` (mode `:team` : seul un libellé « Brouillon »).
2. Cause : les menus ⋮ vivaient sur la page de la notion (`#essential_team_actions`, UDR-0015) et sur la page de l'exercice (`assessment/exercises/show`, UDR-0021). ADR-0113 a retiré la première ; ADR-0121 a fait lire l'exercice dans la feuille (`sheets/_paper.html.erb`, ligne du titre) sans y reporter le menu. Les transitions n'ont plus d'entrée depuis la leçon.
3. Trou de test : les tests de transitions passent par les routes (`teams/exercises_controller_test`, `teams/essentials_controller_test`), jamais par la présence de leur entrée sur la page où le contenu se lit.
- Phrase sans les mots du symptôme : les entrées des transitions sont restées attachées à des pages que la leçon ne relie plus.

**Point 1.** `Teams::CoursesController#edit` recharge nom, sous-titre, niveau, série, matière et `content` ; l'import `course-tree` ne remplit pas `content` (74/75 leçons du jeu standard), et la page ne le montre plus. Pas un défaut de chargement.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Champ « Contenu » sans affichage | Choix d'interface du porteur (À trancher) | retouche à ouvrir |
| Édition du texte des notions et exercices | Revient sur ADR-0113 §4.6 (À trancher) | feature à ouvrir |
