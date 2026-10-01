# Le catalogue de l'élève limité à son niveau

| | |
|---|---|
| **Type** | bugfix (règle métier corrigée à la demande du porteur) |
| **Statut** | livré sur `fix/catalogue-eleve-son-niveau` |
| **Décisions** | [UDR-0013, amendement du 2026-10-01](../../decisions/udr/0013-catalogue-et-page-cours.md) · [ADR-0035, second amendement du 2026-10-01](../../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md) |

## Le problème

> « Normalement un élève de la TleD ne peut voir que les cours de la TleD uniquement. » (porteur, 2026-10-01)

L'élève voyait tout le catalogue publié, tous niveaux confondus. Il pouvait aussi ouvrir, par URL, n'importe quel cours, fiche ou exercice publié d'un autre niveau, et y commencer une session. L'UDR-0013 l'avait prévu ainsi (« publié seulement ») ; la règle change.

## Décisions prises

- **Niveau de l'élève** : ses classes actives de l'année en cours, adhésions non quittées. Plusieurs classes donnent l'union de leurs niveaux.
- **Cours sans série** : il est commun à toutes les séries de son niveau. Un élève de Tle D voit la Tle sans série, comme la philosophie.
- **Hors niveau** : réponse 404 sur les cinq portes (catalogue, cours, fiche, exercice, session), comme un brouillon.
- **Élève sans classe de l'année** : catalogue vide, avec un message qui l'invite à rejoindre sa classe.
- **Filtre « Niveau »** : retiré du catalogue de l'élève.
- **Autres rôles** : enseignant, direction et équipe sont inchangés.

## Suite (même jour) : l'assignation hors niveau est refusée

Décision du porteur : « Refuse l'assignation hors niveau ».

- `AssignResource` refuse un contenu dont le cours n'est pas du niveau de la classe (`:conflict`, `other_level`), avec la règle de lecture de l'élève.
- Le contenu résolu porte désormais `course_level`.

## Tests qui ont changé

Les tests existants connectaient des élèves sans classe, qui voyaient tout. Ils utilisent maintenant `create_student_for(course)`, un élève d'une classe du niveau du cours. Trois tests du filtre par niveau sont joués par un enseignant, puisque l'élève n'a plus ce filtre.
