# Memo — En-têtes HITL citant des numéros d'ADR périmés

| | |
|---|---|
| **Type de cycle** | refactoring |
| **Statut** | cadrage |
| **Ouvert le** | 2026-09-18 |
| **Branche** | `refactor/hitl-refs-adr-obsoletes` |
| **Gravité** | 🟢 **Faible — mécanique, mais 3 cas ambigus** |

---

## Le problème

La normalisation du corpus de décisions a résolu deux collisions de numérotation. Les ADR issus des tickets ont été renumérotés :

| Avant | Après |
|---|---|
| `0014_CATALOGUE_PEDAGOGIQUE.md` | **ADR-0022** — Modélisation hexagonale du Catalogue Pédagogique |
| `0015_ORGANISATION_SCOLAIRE.md` | **ADR-0023** — Modélisation de l'Organisation Scolaire |

Les numéros `0014` et `0015` restent aux ADR déjà au bon format (standardisation des namespaces / stratégie de tests).

Or **36 fichiers de `app/` portent des en-têtes HITL qui citent les anciens numéros** :

| Référence dans le code | Fichiers | Doit devenir |
|---|---|---|
| `ADR-0014 (Architecture Hexagonale Catalogue)` | 20 | ADR-0022 |
| `ADR-0015 (Organisation Scolaire)` | 16 | ADR-0023 |

## Les 3 cas qui ne sont pas mécaniques

`app/domain/dtos/drena_dto.rb`, `app/domain/dtos/school_dto.rb` et `test/domain/use_cases/catalog/manage_drena_test.rb` portent un `ADR-0014` **nu**, sans libellé. Impossible de savoir à l'œil s'il visait le catalogue (→ 0022) ou la standardisation des namespaces (→ reste 0014).

C'est le symptôme exact de la collision qu'on vient de résoudre : quand deux décisions partagent un numéro, les références deviennent indécidables. Ces trois-là exigent de relire le code pour trancher.

## Pour qui

Les **agents IA**, en premier lieu. Un en-tête HITL sert à situer un fichier et à retrouver la décision qui le régit. Une référence fausse envoie l'agent lire le mauvais ADR — et il écrira du code conforme à une décision qui ne concerne pas ce fichier.

## Pourquoi maintenant

Le corpus vient d'être remis d'aplomb. Laisser 36 références fausses annule une partie du bénéfice : la doc est juste, mais le code pointe à côté.

## Hors périmètre

Toute modification du contenu des fichiers au-delà de leur en-tête.

## Ce que le grill a révélé

> À remplir en phase 1. Peu de matière ici : le chantier est mécanique sauf sur 3 fichiers.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| | | |

## Cas limites identifiés

- Le remplacement en masse est faisable par script **uniquement** sur les références portant un libellé explicite (`ADR-0014 (Architecture Hexagonale Catalogue)`).
- Les 3 `ADR-0014` nus doivent être traités à la main, après lecture du code.
- Les ADR-0022 et ADR-0023 portent déjà un encadré « Renuméroté de… » pour qu'un agent comprenne pourquoi le code ne colle pas — à retirer une fois ce chantier terminé.
- `.Archive/06_Quality_and_Reviews/improve_codebase.md` contient aussi une référence : hors périmètre, c'est une archive.
- Opportunité : ce chantier touche tous les fichiers concernés, c'est le bon moment pour aligner leur en-tête sur le **format allégé** de `docs/guide/conventions.md` §5 (3 lignes).

## Questions encore ouvertes

- Profite-t-on du passage pour migrer les 36 en-têtes vers le format allégé, ou se limite-t-on à la correction des numéros ?
