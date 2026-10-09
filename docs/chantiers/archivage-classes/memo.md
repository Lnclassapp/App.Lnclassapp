# Memo — Archiver une classe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-09 |
| **Branche** | `Develop` (branche désignée de la session ; pas de `feature/<slug>`) |
| **Programme** | — *(ou `<programme>` si le chantier est une vague d'un programme — voir `docs/workflows/programme.md`)* |

---

## Le problème

Tous les établissements importés reçoivent désormais les classes de la 6ème à la Terminale (chantier import-second-cycle-force). Un collège, ou un établissement sans second cycle, se retrouve donc avec des classes qui n'existent pas sur le terrain. Aujourd'hui personne ne peut les mettre de côté : la seule action possible est de supprimer la dernière classe d'un niveau, et seulement si elle n'a jamais servi.

## Pour qui

La direction d'un établissement (SchoolStaff) et l'équipe (Team), quelques mois après l'import, quand le terrain a montré quels niveaux n'existent pas.

## Pourquoi maintenant

L'import des établissements force le second cycle partout : sans archivage, les classes en trop restent visibles de tous (élèves, enseignants, direction) et faussent les effectifs.

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- Les rôles « Drena manager » et « DE » : ils n'existent pas dans l'application et ne sont pas créés ici.
- Supprimer définitivement une classe.
- Archiver en masse (par niveau ou par établissement).

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qui archive : « Drena managers » / « DE », ou direction et équipe ? | Direction et équipe (porteur) | Aucun nouveau rôle. Droit de la direction limité à son établissement, comme pour les autres actions de structure |
| Une classe avec des élèves peut-elle être archivée ? | Oui, avec un message de confirmation (porteur, revient sur sa première réponse) | Aucun refus pour cause d'élèves ; la confirmation dit combien d'élèves sont concernés |
| Une classe avec des enseignants rattachés ou des exercices assignés ? | Oui aussi, même confirmation (porteur) | Plus aucun blocage : seule la confirmation protège ; l'historique (adhésions, assignations) est conservé |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
