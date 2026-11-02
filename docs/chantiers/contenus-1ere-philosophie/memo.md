# Memo — Les 8 premières leçons de Philosophie de 1ère (A1, A2, C, D)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/contenus-1ere-philosophie` |
| **Programme** | `contenus-v3-tous-niveaux` (vague P7) |

---

## Le problème

Un élève de 1ère n'a aucune leçon de Philosophie au format en vigueur : les 3 leçons rédigées (méthode de lecture, introduction, conclusion) sont au format 1, retiré, et les 5 suivantes de la progression n'existent pas.

## Pour qui

- **Student** de 1ère A1, A2, C ou D, qui révise avant une interrogation ou un devoir.
- **Teacher**, qui donne les exercices et corrige les questions rédigées.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Vague P7 du programme, indépendante des autres vagues de 1ère. Aucune figure nouvelle : pas de code.

## Hors périmètre

- La série E (décision D3) et toute série « A » : le référentiel de 1ère compte A1 et A2.
- Toute sorte de figure nouvelle, tout code, tout test.
- Les leçons au-delà des 8 de la progression, l'import et la publication : les leçons restent en brouillon jusqu'à la relecture d'un enseignant.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Le programme diffère-t-il selon la série ? | Non : la progression est identique en A, C et D. | 8 leçons rédigées une fois, 32 fichiers (A1, A2, C, D) ; seuls `series_name` change. |
| `material_name` ? | « Philosophie », comme en Tle. | Repris tel quel. |
| Règles de Philosophie ? | Déjà dans `prompt-redaction.md` (vague T6). | Reprises ; relecture indépendante par un sous-agent Opus (attributions, dates, citations). |

## Cas limites identifiés

- Une citation incertaine mot pour mot : paraphrase, jamais de guillemets.
- Une question rédigée note l'argumentation, jamais l'opinion.

## Questions encore ouvertes

- Aucune.
