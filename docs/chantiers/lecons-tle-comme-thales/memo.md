# Memo — Les leçons de Terminale (Histoire-Géographie) préparées comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (2026-11-09) |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `feature/lecons-tle-comme-thales` |
| **Ticket** | [#484](https://github.com/Lnclassapp/App.Lnclassapp/issues/484), étape 2, dossier `tle` |

---

## Le problème

Les 10 leçons v3 d'Histoire-Géographie de Terminale, communes à toutes les séries (dossier `tle/`) attendent dans `docs/contenus/a-reprendre/` (chantier `base-de-lecons`) : un seul exercice par notion pour les 10 de Philosophie, aucun sujet de devoir pour toutes. Rien ne les charge.

## Pour qui

L'élève de Terminale (Histoire-Géographie) qui prépare une interro, un devoir ou le baccalauréat ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

La Tle C, la Tle D, la Tle A1 et la Tle A2 sont fusionnées (#505, #506, #507, #513). Ordre fixé dans #484 : `tle-c`, `tle-d`, `tle-a1`, `tle-a2`, `tle`.

## Hors périmètre

- Le cours, les fiches, le 1er exercice de chaque notion et les 4 problèmes : inchangés.
- L'écran et le code (`app/`) : rien ne change, donc ni ADR ni UDR.

## Décisions

| Question | Réponse | Conséquence |
|---|---|---|
| Modèle ? | Le même que la Tle C et la Tle D | 2 exercices par notion, 4 sujets de 4 exercices de 5 ou 6 questions ; mêmes règles par matière. |
| Leçons communes à un autre dossier ? | Aucune : l'Histoire-Géographie de Terminale n'existe que dans `tle/` | Les 10 leçons sont rédigées, contrôlées puis relues comme en Tle A1 et A2, un rédacteur et un relecteur distincts par leçon. |
| Retour dans `lecons-traitees/` ? | Règle de retour de `a-reprendre/README.md` | Le fichier quitte `a-reprendre/` dans le même commit et le couple entre dans `db/seeds/standard/jeu.yml`. |

## Questions encore ouvertes

- Aucune.
