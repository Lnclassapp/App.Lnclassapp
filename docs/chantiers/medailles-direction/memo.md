# Memo — Médailles : écrans de la direction

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-09 |
| **Branche** | `feature/medailles-direction` |
| **Programme** | — (suite de `medailles-vocabulaire`, voir son `plan.md`) |

---

## Le problème

La direction lit des moyennes en %, un « Score moyen » par élève, un « Taux de rendu » en % et une alerte « moins de 40 % des devoirs ». Mesures concurrentes de la médaille, que l'élève lit seule depuis `medailles-eleve`.

## Pour qui

La direction (`/school-admin`) : page d'une classe, carte de classe d'un niveau, bulles « Niveaux » de l'accueil et alertes de l'établissement, anciens élèves.

## Pourquoi maintenant

UDR « Médailles » (2026-11-08) : la médaille remplace notes, % et moyennes partout où la direction les lit ; la classe se lit par exercice, en répartition de médailles, jamais en moyenne ni classement.

## Hors périmètre

- Écrans enseignant (`medailles-enseignant`, en parallèle), y compris la fiche élève et la liste de classe que la direction ouvre en lecture seule : mêmes vues, convertis là-bas.
- Équipe (`medailles-equipe`). Chiffres en base, seuils, noms de code.
