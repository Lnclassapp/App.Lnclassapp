# UDR-0038 : Import de cours — aide de l'arbre étage par étage dans la modale d'import, noms du référentiel à portée de main, rapport qui compte les lignes créées
<!-- index
titre: Import de cours
statut: Accepté
adr-lie: [0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md), [0039](../adr/0039-format-d-import-du-contenu.md)
problematique: Aide de l'arbre étage par étage dans la modale d'import, noms du référentiel à portée de main, rapport qui compte les lignes créées
-->

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-25 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot I1 ; critères CA-08, TR-28 |
| **ADR lié** | [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (tout naît en brouillon) · [ADR-0039](../adr/0039-format-d-import-du-contenu.md) (format, import partiel) · [UDR-0006](0006-shell-applicatif-par-role.md) §7 (CRUD Hotwire) · [UDR-0037](0037-import-des-etablissements.md) (aide d'un type d'import) · UDR-0007 (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

L'équipe charge des programmes entiers : un cours, ses fiches essentielles, leurs exercices, leurs questions et leurs propositions, souvent depuis les fichiers de l'ancienne application (`.Business/content_pedagogics/tle_d/`).

Dans l'ancienne application, l'import de cours tenait en un champ de fichier en haut de `/courses` :

- aucun mot sur le format : l'arbre, les clés acceptées et les règles des questions ne se lisaient que dans le code ;
- aucun rapport : « L'import de vos cours est en cours. », puis rien ; un cours refusé disparaissait sans bruit ;
- un niveau, une série ou une matière inconnus étaient **créés à la volée**, et l'exemple affiché montrait `"status": "publié"` alors que tout arrivait en brouillon, sauf les exercices, publiés d'office.

## 2. Décision

1. **L'aide du format vit dans la modale d'import**, sous le champ de fichier, comme pour les établissements (UDR-0037). L'arbre ayant cinq étages, les clés sont rangées **étage par étage**, chacun dans un `<details>` : seul le cours est ouvert, les autres se déplient à la demande. La modale reste courte, et tout est là.
2. **Les noms acceptés du référentiel sont dans la modale**, repliés : les niveaux avec leurs séries, les matières avec leur abrégé. Un nom inconnu est une erreur du cours, jamais une création : l'équipe vérifie l'orthographe sans quitter l'import. Un référentiel vide renvoie à son écran.
3. **Le brouillon est dit en clair** : tout arrive en brouillon, quelle que soit la clé `status`. Un cours déjà présent est ignoré et compté, jamais modifié.
4. **Le rapport compte les lignes créées** sous le cours : fiches essentielles, exercices, questions, propositions. Le nombre de cours est déjà le compteur « Importés ».
5. **Aucun contrôleur ni écran propre** : la modale, le suivi sans rechargement et le rapport sont ceux de l'écran des imports (socle, UDR-0006 §7). Ce lot ne fournit que le partial du type.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Partial `app/views/teams/imports/kinds/_course_tree.html.erb`, rendu par `teams/imports/new` dans le formulaire d'import, sous le champ de fichier.
- `section#import-help-course_tree` (`rounded-ln bg-mist p-4 text-sm space-y-4`, `aria-labelledby` sur son titre `h3`) contient, dans l'ordre :
  - le titre « Format du fichier » et une phrase : format `lnclass.course-tree`, version 1, un cours et toute sa descendance par élément de `courses`, entier ou pas du tout ;
  - `div#import-help-keys` : cinq `details` blancs (`border-line`), un par étage (Cours `courses[]`, Fiche essentielle `essentials[]`, Exercice `exercises[]`, Question `questions[]`, Proposition `answers[]`), le premier ouvert. Chacun contient une `dl` : pour chaque clé canonique, ses alias en `<code>` séparés par « · », puis sa règle. Les alias du cours et de l'exercice sont lus dans `UseCases::Catalog::ImportCourseTree::COURSE_ALIASES` et `EXERCISE_ALIASES`, jamais recopiés ;
  - « Exemple minimal » : un cours, une fiche, un exercice, une question Vrai/Faux, dans un `<pre><code>` blanc (`border-line`, `font-mono text-xs`, `overflow-x-auto`) ;
  - le rappel du brouillon, précédé de l'icône `information-circle` ;
  - `details` « Noms acceptés du référentiel » : la règle de comparaison (sans accents ni casse, « Physique Chimie »), puis `ul#import-help-levels` (chaque niveau en `<code>`, puis ses séries séparées par « · », ou « sans série ») et `ul#import-help-materials` (chaque matière en `<code>`, puis son abrégé), en deux colonnes dès `sm`. Sans niveau ou sans matière : un `p#import-help-referential` et le lien « Ouvrir le référentiel » (`data-turbo-frame="_top"`).
- Rapport : les libellés `teams.imports.status.details.essentials_created`, `exercises_created`, `questions_created`, `answers_created` s'affichent dans le bloc « Détails » du suivi du socle.

**Tokens**
- `bg-mist` pour le fond de l'aide, `bg-white` et `border-line` pour les étages, l'exemple et le référentiel, `text-mute` pour les explications, `text-brand` pour l'icône, `text-brand-strong` pour le lien. Aucune valeur arbitraire, aucune classe de l'ancienne application.

**Comportement**
- Ouverture : `new_teams_import_path(kind: "course_tree")` dans le frame `modal` (menu « Nouvel import » de l'écran des imports ; l'écran des cours pourra y mener).
- Téléversement, suivi et rapport : ceux du socle (`create.turbo_stream.erb`, frame `import_status` rechargé toutes les 3 s), sans rechargement de page.
- Erreurs d'un cours notées à la **clé canonique** et au chemin exact dans l'arbre, quel que soit l'alias du fichier : `courses[3].name`, `courses[4].material_name`, `courses[1].essentials[0].exercises[2].questions[3].answers`.

**États obligatoires**
- Référentiel vide : phrase et lien vers l'écran du référentiel.
- Import terminé : les quatre lignes créées dans « Détails » ; aucune ligne si aucun cours n'a été écrit.
- Rejet en bloc, erreur par élément : ceux du socle.

**Accessibilité**
- Chaque `summary` a une cible d'au moins 48 px (`min-h-tap`) ; `details` s'ouvre au clavier.
- L'icône d'information est décorative : le texte porte seul le message.
- Seuls l'exemple et la liste des matières défilent, jamais la modale en largeur.

## 4. Conséquences

- Les imports de fiches essentielles (I2) et d'exercices (I3) peuvent reprendre les étages « Fiche essentielle » à « Proposition » de cette aide.
- Un alias ajouté à `COURSE_ALIASES` ou `EXERCISE_ALIASES` apparaît de lui-même dans l'aide.
- Le libellé commun du type (`import_kinds.course_tree`) est « Cours complets » (décision du porteur, 2026-09-27) : le vocabulaire de l'UDR-0007 ne connaît pas « chapitre ».
