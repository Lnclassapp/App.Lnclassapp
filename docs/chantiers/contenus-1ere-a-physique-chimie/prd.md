# PRD — Les leçons de Physique-Chimie de 1ère A au format v3

Vague P4 de [`contenus-v3-tous-niveaux`](../contenus-v3-tous-niveaux/feuille-de-route.md). Modèle : [`contenus-1ere-physique-chimie-cd`](../contenus-1ere-physique-chimie-cd/prd.md).

## Contexte

Rédiger les 10 premières leçons de Physique-Chimie de 1ère A (progression DPFC 2026-2027, rangs 1 à 10) en fichiers `lnclass.course-tree` v3 prêts à importer en brouillon, selon [`prompt-redaction.md`](../../contenus/prompt-redaction.md) et [`prompt-redaction-lot.md`](../../contenus/prompt-redaction-lot.md). 20 fichiers : 10 pour A1, 10 pour A2.

## Acteurs

Team (importe, relit, publie), Student (révise une leçon publiée), Teacher (donne les exercices). Aucune règle d'autorisation nouvelle.

## Critères d'acceptation

1. 10 fichiers dans `lecons-traitees/1ere-a1/physique-chimie/` et 10 dans `1ere-a2/physique-chimie/`, identiques à `series_name` près, `level_name` « 1ère », intitulés de la progression à l'identique.
2. Chaque fichier passe `ruby script/contenus/valider.rb` sans erreur ni avertissement.
3. Chaque leçon relue par un sous-agent distinct de l'auteur ; chiffres et données vérifiés par Opus.
4. Les points à faire valider sont au journal du programme.
5. Aucun code touché.
