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

## Ce qui a dérapé

- Rien pour l'instant : phase de cadrage.

## Ce qu'on a appris sur la codebase

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

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0101 (Proposé) |
| **UDR produits** | UDR-0119, UDR-0120, UDR-0121 (Proposé) |
