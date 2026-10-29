# PRD — Refonte des contenus de mathématiques

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les leçons en ligne sont à l'ancien format : leurs exercices sont jetés à l'import, et la révision est éclatée entre fiches des notions essentielles et fiches de cours illustrées ([memo](memo.md)). On remplace tout par **une fiche de révision par leçon** (chaque notion au gabarit À retenir · La méthode · Un exemple corrigé · Le piège à éviter, avec des figures interactives paramétrées réutilisables) et des exercices à correction rédigée (1 par notion + 4 problèmes, ≥ 5 questions chacun). Pilote : les 10 leçons de mathématiques de 3e ; la base est remise à zéro par le porteur.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (gestion du contenu) | Importer un fichier de leçon au nouveau format ; réimporter une leçon **en brouillon** ; voir la leçon en brouillon (fiche, figures) et son **corrigé complet** ; publier | Réimporter une leçon publiée ou archivée ; importer l'ancien format ; éditer une notion ou un exercice à l'écran (ADR-0113, inchangé) |
| Student | Lire la fiche de révision d'une leçon publiée de son niveau, manipuler ses figures, faire les exercices, lire la correction de sa copie (ADR-0115) | Voir une leçon en brouillon (404) ; voir le corrigé de l'équipe |
| Teacher | Comme aujourd'hui : lire la leçon publiée, assigner exercices et devoirs à sa classe | Voir le corrigé de l'équipe ; importer |
| Parent, SchoolStaff | Rien de nouveau (hors périmètre) | — |

Règles d'autorisation : `ManageContentPolicy` (import, corrigé de l'équipe), `ReadPublishedPolicy` (page de la leçon), inchangées.

## 3. Parcours utilisateur

### Chemin nominal

1. L'IA rédige une leçon de 3e au nouveau format avec le prompt unique ; le script de contrôle la valide ; une relecture IA indépendante refait les calculs.
2. L'équipe importe le fichier. La leçon, ses notions et ses exercices naissent **en brouillon**.
3. L'équipe ouvre la leçon : la fiche de révision (notions au gabarit fixe, figures) s'affiche ; depuis l'en-tête, « Corrigé » ouvre toutes les questions avec bonnes réponses et corrections rédigées.
4. Erreur trouvée → le fichier est corrigé et réimporté ; la leçon en brouillon est remplacée entière. Sinon → « Tout publier ».
5. L'élève de 3e ouvre la leçon : il lit la fiche, manipule une figure, puis fait l'exercice de la notion et les 4 problèmes ; à la correction de sa copie, chaque explication reprend les étapes de « La méthode ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Fichier à l'ancien format (version 1 ou 2) | Refus du fichier entier, raison « format retiré, utiliser la version 3 » |
| Leçon déjà publiée ou archivée | Refus de cette leçon, raison nommant la leçon ; rien n'est modifié |
| Leçon déjà présente en brouillon | Remplacée entière (notions, exercices, questions, séances de l'équipe sur ces exercices) dans une seule transaction |
| Notion sans exercice, ou avec plus d'un | Refus de la leçon, notion en cause nommée |
| Leçon sans exactement 4 problèmes | Refus de la leçon |
| Exercice de moins de 5 questions | Refus de la leçon, exercice en cause nommé |
| Question sans correction rédigée | Refus de la leçon, question en cause nommée |
| Exemple corrigé dont le nombre d'étapes diffère de La méthode | Refus de la leçon, notion en cause nommée |
| Figure de sorte inconnue, paramètre manquant ou hors bornes | Refus de la leçon, figure en cause nommée ; jamais de figure cassée à l'écran |
| Notion ou exercice citant une figure absente de la leçon | Refus de la leçon |
| Matière sans aucune leçon publiée | État vide existant de la liste des leçons, inchangé |
| Navigateur sans JavaScript | La figure est remplacée par sa description textuelle (obligatoire dans le fichier) |
| Notion sans figure | Pas d'emplacement vide |

## 4. Critères d'acceptation

```gherkin
# Import — format
CA-1
Étant donné un fichier de leçon au format lnclass.course-tree version 1 ou 2
Quand l'équipe l'importe
Alors le fichier est refusé entier avec la raison « format retiré »
Et aucune leçon n'est créée

CA-2
Étant donné un fichier version 3 valide d'une leçon de 3e avec 3 notions et 2 figures
Quand l'équipe l'importe
Alors la leçon, ses 3 notions, ses 7 exercices et leurs questions existent en brouillon
Et chaque notion porte ses 4 blocs (À retenir, La méthode, Un exemple corrigé, Le piège à éviter)
Et la leçon porte ses 2 figures avec leur sorte et leurs paramètres

CA-3
Étant donné une notion sans exercice ou avec 2 exercices
Quand l'équipe importe la leçon
Alors la leçon est refusée et le rapport nomme la notion

CA-4
Étant donné une leçon avec 3 problèmes (ou 5)
Quand l'équipe l'importe
Alors la leçon est refusée

CA-5
Étant donné un exercice de 4 questions
Quand l'équipe importe la leçon
Alors la leçon est refusée et le rapport nomme l'exercice

CA-6
Étant donné une question dont la correction rédigée est vide
Quand l'équipe importe la leçon
Alors la leçon est refusée et le rapport nomme la question

CA-7
Étant donné une notion dont La méthode a 4 étapes et l'exemple corrigé 3
Quand l'équipe importe la leçon
Alors la leçon est refusée et le rapport nomme la notion

CA-8
Étant donné une figure de sorte inconnue, ou d'une sorte connue avec un paramètre hors bornes ou sans description
Quand l'équipe importe la leçon
Alors la leçon est refusée et le rapport nomme la figure et le paramètre

CA-9
Étant donné un exercice qui cite une figure absente de la leçon
Quand l'équipe importe la leçon
Alors la leçon est refusée

# Import — réimport
CA-10
Étant donné une leçon publiée « Racines carrées » de 3e
Quand l'équipe importe un fichier qui la contient
Alors cette leçon est refusée avec une raison qui la nomme
Et ses notions, exercices et copies sont inchangés

CA-11
Étant donné une leçon en brouillon « Racines carrées » avec une séance de l'équipe sur un de ses exercices
Quand l'équipe réimporte un fichier corrigé qui la contient
Alors la leçon garde son identité (même adresse)
Et ses notions et exercices sont ceux du nouveau fichier, en brouillon
Et les anciens exercices et la séance n'existent plus

# Lecture — élève
CA-12
Étant donné une leçon publiée de 3e
Quand un élève de 3e l'ouvre
Alors la section « Fiche de révision » montre chaque notion dans l'ordre, avec ses 4 blocs dans l'ordre À retenir, La méthode, Un exemple corrigé, Le piège à éviter
Et la fiche garde l'habillage cahier (papier Seyès, titres manuscrits, thème de la leçon)
Et les étapes de La méthode sont numérotées
Et chaque étape de l'exemple corrigé porte le numéro de l'étape qu'elle applique

CA-13
Étant donné une notion qui cite une figure de sorte « repère »
Quand l'élève ouvre la leçon
Alors la figure est rendue sous la méthode, avec sa description textuelle accessible
Et sans JavaScript la description textuelle est visible à sa place

CA-14
Étant donné une leçon en brouillon
Quand un élève ou un enseignant l'ouvre
Alors il reçoit une 404

# Corrigé — équipe
CA-15
Étant donné une leçon en brouillon
Quand un membre de l'équipe ouvre son corrigé
Alors il voit, pour chaque exercice dans l'ordre de « Prépare interros » : le sujet, chaque question, sa ou ses bonnes réponses et sa correction rédigée

CA-16
Étant donné un élève ou un enseignant
Quand il demande le corrigé d'une leçon
Alors il reçoit une 404

# Retraits
CA-17
Étant donné l'application après le chantier
Alors les types d'import « fiche de cours » et « notions » n'existent plus
Et la table des fiches de cours et celle des images de notions n'existent plus
Et les figures propres à une leçon (Thalès, lentilles, surligneur d'arguments) n'existent plus

# Contrôle hors ligne
CA-18
Étant donné un fichier version 3 qui viole une règle de CA-3 à CA-9
Quand on lance le script de contrôle sur ce fichier
Alors il sort en erreur et nomme la même règle que l'import

# Contenu pilote
CA-19
Étant donné les 10 leçons de mathématiques de 3e de la progression 2026-2027
Quand on lance le script de contrôle sur leurs fichiers
Alors les 10 passent sans erreur
Et chacune s'importe en brouillon sur une base vide
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Catalog::NotionSheet` (4 blocs, règle étapes de l'exemple = étapes de la méthode) ; `Entities::Catalog::Figure` + `FigureKinds` (liste fermée, paramètres bornés par sorte) ; `ImportKind::COURSE_TREE_VERSION = 3`, v1/v2 retirées ; `ImportCourseTree` réécrit (≥ 5 questions, correction obligatoire, figures, réimport du brouillon) ; `ContentTreeWriterPort` : remplacement d'une leçon en brouillon ; query de lecture du corrigé. Retrait : `ImportCourseSheet`, `ImportEssentials`, `UploadEssentialImage`, `ReadEssentialImage`, `CourseSheet`, port d'images de notions |
| Infrastructure | Migration : `essentials.sheet` (jsonb), `courses.figures` (jsonb), `exercises.figure_key` ; suppression de `course_sheets`, `essential_images`, du texte riche des notions ; kinds `course_sheet` et `essentials` retirés des rapports d'import. Schéma `lnclass.course-tree.v3.json` ; v1, v2 et `course-sheet.v1` supprimés. `ContentTreeWriter` (remplacement en transaction). `RevisionSheetQuery` réécrite ; `LessonAnswerKeyQuery` (corrigé) |
| Delivery | Route équipe `GET /teams/courses/:slug/answer-key` (`Teams::AnswerKeysController#show`, `ManageContentPolicy`) ; retrait des routes d'images de notions et de l'ancienne adresse de fiche |
| UI | Habillage cahier gardé (`course_sheet.css`, Kalam, Source Serif 4, Seyès, 3 thèmes) ; `catalog/courses/_revision_sheet` réécrit, `catalog/revision_sheets/_sheet` (une page de cahier, une section par notion au gabarit) ; partial `catalog/figures/_figure` ; contrôleur Stimulus `figure` (chargé à la demande) et un module de rendu par sorte ; vue `teams/answer_keys/show` ; lien « Corrigé » dans l'en-tête de la leçon pour l'équipe. Retrait : `course_sheets/*`, contrôleurs `course_sheet/*`, classes du lexique, de l'explication simple et des exercices dans la page |
| Contenus | `docs/contenus/prompt-redaction.md` réécrit (v3), `script/contenus/valider.rb` (v3), 10 fichiers de leçons de 3e sous `docs/contenus/lecons-traitees/3eme/mathematiques/` |

## 6. Décisions rattachées

- ADR-XXXX-fiche-de-revision-par-notion-et-figures-parametrees — format v3, gabarit des notions, figures paramétrées, retraits, réimport du brouillon. Remplace ADR-0110, amende ADR-0113 §4.4 (v1 et réimport) et ADR-0105 (images des notions).
- UDR-XXXX-fiche-de-revision-en-quatre-blocs-et-corrige-de-l-equipe — rendu de la fiche, des figures et du corrigé. Amende UDR-0139 §3.2, remplace UDR-0137.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Leçons de maths de 3e avec exercices visibles | 0 | 10 | |
| Questions par exercice (minimum) | 0 importée | ≥ 5 | |
| Questions sans correction rédigée | — | 0 | |
| Code propre à une seule leçon (figures) | 4 sortes | 0 | |
