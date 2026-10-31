# Memo — Leçons au format v3 pour tous les niveaux (Tle → 6ème)

| | |
|---|---|
| **Type de cycle** | programme |
| **Statut** | cadrage — feuille de route soumise au porteur, aucune vague lancée |
| **Ouvert le** | 2026-10-31 |
| **Branche** | aucune en propre ; une branche `feature/contenus-<niveau>-<matiere>` par vague |
| **Programme** | — *(ce dossier est le programme `contenus-v3-tous-niveaux`)* |

---

## Le problème

Seule la 3ème a des leçons au format v3 (60 leçons, 6 matières). Les autres niveaux n'ont que des fiches vides issues des progressions, et quelques leçons v1 rangées dans `docs/contenus/lecons-traitees/` (213 fichiers sources dans `leçons/`) que l'import ne prend plus. Un élève de 6ème, de 2nde ou de Terminale n'a rien à réviser au nouveau format.

## Pour qui

- **Student** de chaque niveau, qui révise une leçon et s'entraîne dans la fiche.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe en brouillon, fait relire par un enseignant, publie.

## Demande du porteur (2026-10-31)

« Réouvre les vagues pour générer les leçons pour les autres niveaux. Commence par la Tle, puis 1ère, 2nde, jusqu'à la 6e. Rassemble les leçons dans une session nommée à cet effet. » Ordre : Tle → 1ère → 2nde → 3ème (compléter) → 4ème → 5ème → 6ème.

## Ce qu'on reprend tel quel

- Format v3, fiche en 4 blocs, figures paramétrées, 1 exercice par notion (≥ 5 questions), 4 problèmes par leçon, corrections avec la méthode : ADR-0116, UDR-0141 (`refonte-contenus-maths`).
- Figures des autres matières : ADR-0117, UDR-0142 (`contenus-3e-autres-matieres`).
- « Je m'entraîne » dans la fiche (`je-m-entraine-dans-la-fiche`).
- Rédaction : `docs/contenus/prompt-redaction-lot.md` ; contrôle : `script/contenus/valider.rb` ; relecture indépendante ; rangement dans `docs/contenus/lecons-traitees/<niveau-série>/<matière>/`.
- Les leçons v1 de `leçons/` sont une **source**, réécrites entièrement, jamais fusionnées.

## Hors périmètre

- Les leçons au-delà des 10 premières de chaque progression.
- L'import en production, la relecture enseignante et la publication : faits par l'équipe. Les leçons restent en **brouillon**.
- Toute suppression de données de production. L'import ne remplace qu'un brouillon (`replace_draft`), jamais un cours publié.
- Matières hors des 7 « à fiche » (voir décision D1 de la feuille de route) tant que le porteur ne les a pas ajoutées.
