# Journal — Remédiation ciblée

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Slug `remediation-ciblee` au lieu de `remediation` (feuille de route §5, V5) | Demande de l'orchestrateur au lancement des vagues V2 à V6 | Non |
| 2026-10-16 | Cadrage écrit selon les recommandations Q1 à Q12, statut « Proposé » partout | Le code attend la validation du porteur | ADR-0101 (Proposé) |
| 2026-10-16 | **Lots A à D lancés en autonomie, à la demande du porteur : décisions prises sur recommandation, à confirmer par le porteur (questions REM-1 à REM-12 = Q1 à Q12 du memo).** ADR-0101 et UDR-0119 à 0121 restent « Proposé » | Le porteur a demandé l'exécution sans attendre ses réponses | Non |
| 2026-10-16 | Lot A : `RemediationPick` reçoit des candidats dont l'`id` est l'identifiant public de l'exercice (`PickCandidate`) | `ExerciseRow` n'expose pas l'id ; la règle ne compare que des identifiants, et la source se lit dans la même requête que la lacune (jointure sur la session source) | Non |
| 2026-10-16 | Lot A : l'aide reçoit `pass_grade` et `remediation_grade` au lieu de réécrire `pass` et `remediation` (UDR-0119 §3) | Les autres réponses (badges, maîtrise) gardent leurs pourcentages : les mêmes variables ne peuvent pas porter deux unités | Non |
| 2026-10-16 | Lot B : `SessionResultQuery` calcule `gap_outcome` pour tout lecteur (une requête sur `knowledge_gaps`) ; seule la vue le réserve au propriétaire | La query ne connaît pas le lecteur ; la règle « élève seul » vit avec `@owner`, comme la phrase de progrès (UDR-0073) | Non |
| 2026-10-16 | Lot C : `ClassroomGapsQuery#summary` et `#detail` prennent l'identifiant public de la classe et les slugs (au lieu de `classroom_id` et `essential_id`, ADR-0101 §4.4) et un `show_roster:` | Ni `ClassroomHeaderQuery` ni `ClassroomEssentialQuery` n'exposent d'id : les modifier aurait touché des fichiers que `rapports-de-classe` change en parallèle. La présence et la fiche se résolvent en sous-requêtes, une requête par méthode. `show_roster` passe dans la query, comme `ClassroomOverviewQuery`, pour que la branche « rien n'est lu » soit testée (couverture 100 % des branches) alors que `allow_roles` ne laisse jamais passer un lecteur sans liste | Non |
| 2026-10-16 | Lot C : les deux cartes de la fiche dans la classe montrent 3 lignes puis « Voir plus » (UDR-0121 §3.2 disait 5) | `ui_reveal_item` et `ui_reveal_more` portent la limite commune de 3 (`REVEAL_LIMIT`) ; une limite par liste demanderait de changer le composant partagé | Non — à confirmer par le porteur |
| 2026-10-16 | Lot C : le sous-titre du bloc de la classe calcule « 10/20 » depuis `PASS_THRESHOLD` | Même règle que l'UDR-0119 : aucun seuil écrit en dur | Non |
| 2026-10-16 | Lot D : un seul test système (6,8 s enregistrées), sessions de 2 questions | Budget de 15 s par chantier (ADR-0069 §9) ; tous les autres cas sont prouvés au niveau du contrôleur et de la query | Non |
| 2026-10-16 | « 3 essais sous la moyenne » devient « 3 sessions sous la moyenne » (UDR-0121 §3.2, PRD §4 corrigés) | « Essai » est interdit par l'UDR-0007 (vocabulaire : une `ExerciseSession` est une « session ») ; la garde `test/i18n/locale_files_test.rb` l'a refusé au premier `bin/ci` | Non |
| 2026-10-16 | Réponses du porteur : recommandations Q1 à Q12 acceptées. ADR-0101 et UDR-0119 à 0121 passent « Accepté » ; ADR-0043, UDR-0015, UDR-0027, UDR-0029 et UDR-0087 marqués amendés | Fusion d'`origin/Develop` (commit `docs(cadrage V2–V6): réponses du porteur du 2026-10-16`) | Oui (statuts) |
| 2026-10-16 | UDR-0121 §3.2 réécrite à 3 lignes (limite commune du composant) au lieu de 5 | Le texte doit décrire ce qui est livré ; l'écart est signalé au porteur dans la PR | Non |

## Ce qui a dérapé

- **`script/ci/record_timings` ne lit pas la durée du premier test système d'un processus** : Capybara écrit « Capybara starting Puma... » sur la ligne du test, et la durée passe à la ligne suivante sans être reconnue. La durée du Lot D (6,8 s) a été relevée après avoir retiré ce texte du journal du test. À corriger dans un chantier CI.
- **Le jeu de mesure de l'ADR-0067 ne se sème plus** : `script/perf/dataset.rb` n'écrit pas `joined_via` (`teacher_profiles`, `classroom_students`), colonne `NOT NULL` sans défaut depuis l'ADR-0083. La mesure du Lot C a posé un défaut le temps du semis, sur la base de test seulement. La page entière (`script/perf/measure_screens.rb`, mode production) n'a donc pas été remesurée : seul le SQL ajouté l'a été, très loin du budget de 100 ms. Correctif du jeu à faire dans un chantier à part.

## Ce qu'on a appris sur la codebase

- **Exécution (2026-10-16)** : aucune migration, aucune route, aucun use case. Deux règles pures (`RemediationPick`, `GapOutcome`), une query nouvelle (`ClassroomGapsQuery`), deux queries étendues. Page de classe : 20 → 21 requêtes ; fiche dans la classe : 17 → 18, à 1 comme à 30 élèves (PRD §7).

- **La remédiation est déjà implicite.** `StartExerciseSession#new_session` ouvre une session `remediation` sur tout exercice d'une fiche à revoir, « Recommencer » compris. L'ADR-0043 décrivait un use case `StartRemediationSession` que personne n'a écrit, et que plus rien ne requiert. Le `grep` de vérification de l'ADR-0043 §7 nomme un fichier qui n'existe pas.
- **`self_corrected` est presque mort** : il ne naît plus que d'une session `standard` commencée avant l'échec et finie après.
- **14/20 donne « Félicitations ! » et des confettis** (seuil 70 %, UDR-0087 §3.6), mais la fiche ne se lève qu'à 15/20 (75 %). Aucun écran ne l'explique.
- **La règle de lever est écrite en pourcentage** (fiche, aide), alors que l'élève lit toutes ses notes sur 20 depuis l'UDR-0023.
- **Aucune lecture enseignant de `knowledge_gaps`** : seuls l'accueil élève, la fiche et l'effaceur de données la lisent.
- La feuille de route fait dépendre AS-17 de `rapports-de-classe`, qui n'est pas ouvert. Pourtant sa tranche « exercices » est livrée (#164), et les deux pages de classe qui accueillent AS-17 existent.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Statut `self_corrected` gardé en base sans écran | Une migration de données pour un statut rare ne vaut pas son coût | — |
| Lacunes sur la fiche d'un élève (CL-13) | La fiche élève n'existe pas encore | `rapports-de-classe` |
| Jeu de mesure de l'ADR-0067 sans session de remédiation | Déjà noté par `remediation-comptee-faite` | voir ce chantier |
| `script/perf/dataset.rb` n'écrit pas `joined_via` : le jeu ne se sème plus | Hors périmètre ; la page de classe entière n'a pas été remesurée en mode production | à ouvrir (`perf`) |
| `record_timings` rate le premier test système d'un processus | Hors périmètre | à ouvrir (CI) |
| Revue par les sous-agents (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) | Non lancée : ni la session des lots ni celle de clôture n'avaient d'outil de sous-agent. Le parcours a été rejoué par la session de clôture (captures, `bin/ci-quiet`) | avant la fusion de la PR |
| Limite de 5 lignes des cartes de la fiche dans la classe (UDR-0121) ramenée à 3 | Limite commune du composant | si le porteur tient à 5 |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-16 (PR prête, non fusionnée) |
| **PR** | `feature/remediation-ciblee` → `Develop` |
| **ADR produits** | ADR-0101 (Accepté, amende l'ADR-0043 §4 et §7) |
| **UDR produits** | UDR-0119, UDR-0120, UDR-0121 (Accepté) |
