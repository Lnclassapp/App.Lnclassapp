# PRD — Leçons de 1ère en Histoire-Géographie au format v3

> Reprend le PRD cadre de [`contenus-3e-histoire-geographie`](../contenus-3e-histoire-geographie/prd.md). Aucun code.

## 1. Contexte

Rédiger les 10 premières leçons d'Histoire-Géographie de 1ère (progression DPFC 2026-2027), au format `lnclass.course-tree` v3, avec `docs/contenus/prompt-redaction-lot.md`.

## 2. Les 10 leçons (ordre de la progression, `level_name` "1ère", `material_name` "Histoire-Géographie", sans série)

| Rang | Intitulé exact | v1 remplacée |
|---:|---|---|
| 1 | Histoire — L'essor du capitalisme et ses conséquences | oui |
| 2 | Géographie — Dynamisme démographique et qualité de la vie en Côte d'Ivoire | oui |
| 3 | Histoire — Les révolutions industrielles | oui |
| 4 | Géographie — La croissance démographique mondiale et ses conséquences | non |
| 5 | Histoire — Le mouvement impérialiste et le congrès de Berlin | non |
| 6 | Histoire — Les résistances aux conquêtes territoriales : exemple de la Côte d'Ivoire de 1878 à 1920 | non |
| 7 | Géographie — L'urbanisation dans les pays en développement : l'exemple de la Côte d'Ivoire | non |
| 8 | Géographie — L'urbanisation dans les pays développés : l'exemple de la France | non |
| 9 | Histoire — La colonisation et les résistances en Côte d'Ivoire de 1893 à 1946 | non |
| 10 | Géographie — L'organisation administrative de la Côte d'Ivoire | non |

## 3. Critères d'acceptation

```gherkin
Fonctionnalité: Les 10 leçons de 1ère en Histoire-Géographie

  Scénario: CA-1 chaque leçon passe le contrôle
    Quand on lance ruby script/contenus/valider.rb sur chaque fichier de docs/contenus/lecons-traitees/1ere/histoire-geographie/
    Alors il sort sans erreur ni avertissement

  Scénario: CA-2 les faits sont vérifiés
    Étant donné chaque leçon
    Quand un sous-agent Opus distinct de l'auteur relit dates, chiffres, cartes et faits
    Alors les défauts sont corrigés ou inscrits au journal

  Scénario: CA-3 les v1 sont remplacées
    Alors les 3 fichiers v1 du même intitulé sont remplacés par leur version v3

  Scénario: CA-4 la CI est verte
    Quand bin/ci-quiet tourne sur le head final
    Alors la ligne de preuve est dans la PR
```

## 4. Hors périmètre

Voir le memo.
