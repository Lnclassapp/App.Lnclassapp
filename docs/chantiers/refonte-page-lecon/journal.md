# Journal — Refonte de la page de la leçon : fiche de révision, « Prépare interros » et exercices sur feuille

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-28 | Contenu Thalès v2 : 4 exercices de notion en Fixation (un par notion), 4 exercices de toute la leçon en Évaluation (problèmes en contexte). Touré a relu et validé les 8 sujets et leurs questions. | Q11 : le type suit ce que l'exercice travaille ; une notion se fixe, la leçon entière s'évalue. | Non |
| 2026-10-28 | Lot D : plafonds de l'import v2 (50 notions, 30 questions, 10 propositions, sujet 5 000 caractères) ; réimport d'une leçon v2 existante = archivage de ses exercices et création des nouveaux en brouillon, leçon et notions intactes, chaque notion du fichier devant exister dans la leçon (sinon refus nommé). | Menace Q1, Q2 (orchestrateur) ; remplacement des exercices (porteur) ; ne jamais modifier en place les questions d'une séance en cours. | Non |
| 2026-10-28 | Lot D, corrections des revues de la PR #336 : version entière exigée, lien mort retiré, refus d'un réimport qui omet une notion ou dont deux notions se confondent, tests de portée et de couverture reportés (menace M19 à M21) | Port `EssentialRepositoryPort#names` ajouté (lecture seule) | Non |
| 2026-10-28 | Lot E : les anciennes adresses d'une notion, de la fiche et d'une notion en classe répondent 301 vers la leçon (ancres `#notion-<slug>`, `#fiche-de-revision`), avec les refus d'avant (404, 403) : aucune redirection ne confirme un brouillon ni un autre niveau. Ouvrir la leçon enregistre la lecture de ses notions publiées (élève, hors préchargement). Les lignes de notion des cartes de leçon et de l'enseignant sont gardées, avec un lien ancré sur la leçon (`_essential_row` n'est pas supprimé). | ADR-0113 §4.3 et §4.6, UDR-0139 §3.7 ; la carte de leçon de l'élève et celle de l'enseignant listent les notions : les retirer changeait l'écran sans décision. | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Code devenu mort après le Lot E : cas d'usage `CreateEssential`, `UpdateEssential`, `CreateExercise`, `UpdateExercise` et DTO d'entrée ; contrôleurs d'envoi d'image (`Teams::EssentialImagesController`, `Teams::QuestionImagesController`) et leurs routes ; `ClassroomGapsQuery#detail` et `ClassroomOverviewQuery#shown_course?` ; variante autonome de la fiche (`embedded: false`) ; paramètre `with_essentials` | Hors du champ du Lot E ; chacun a ses tests et ses garde-fous de couverture | Nettoyage à planifier |
| Le suivi « élèves à revoir / fiche levée » de l'enseignant (page de la notion en classe) n'a plus d'écran | La page disparaît avec ADR-0113 §4 ; le bloc n'a pas été redessiné sur la page de la leçon | À décider (UDR) |
| « Modifier les jours » par classe et l'assignation par l'équipe n'existent plus sur la page de la leçon | Retirés avec la page de la notion ; la fenêtre des jours reste ouverte depuis la page de la classe | À décider (UDR) |
| Revues de la PR #337 : la réussite de la classe par exercice (`success_percent`) disparaît avec la page de notion en classe | Aucun écran ne l'affiche plus | Arbitrage du porteur |
| Revues de la PR #337 : l'exercice de remédiation proposé n'est plus proposé ; `Entities::Assessment::RemediationPick` n'a plus d'appelant | Il vivait sur la page de la notion | Arbitrage du porteur (rétablir ailleurs ou retirer l'entité) |
| Revues de la PR #337 : les routes et contrôleurs d'envoi d'images de l'équipe (`config/routes/teams.rb:74-75`) n'ont plus de formulaire | Les formulaires de notion et d'exercice ont disparu avec l'ancienne édition | Arbitrage du porteur (retirer, ou garder pour l'import) |
| Revues de la PR #337 : le code mort à planifier, déjà listé dans la première ligne de ce tableau | Voir ci-dessus | Nettoyage à planifier |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
