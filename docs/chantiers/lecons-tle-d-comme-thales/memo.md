# Memo — Les leçons de Terminale D préparées comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (2026-11-07) |
| **Ouvert le** | 2026-11-07 |
| **Branche** | `feature/lecons-tle-d-comme-thales` |
| **Ticket** | [#484](https://github.com/Lnclassapp/App.Lnclassapp/issues/484), étape 2, dossier `tle-d` |

---

## Le problème

Les 45 leçons v3 de Tle D (Français 6, Mathématiques 10, Philosophie 9, Physique-Chimie 10, SVT 10) attendent dans `docs/contenus/a-reprendre/` (chantier `base-de-lecons`) : un seul exercice par notion pour 9 d'entre elles, aucun sujet de devoir pour toutes. Rien ne les charge.

## Pour qui

L'élève de Terminale D qui prépare une interro, un devoir ou le baccalauréat ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

La Tle C est fusionnée (#505). Ordre fixé dans #484 : `tle-c`, `tle-d`, `tle-a1`, `tle-a2`, `tle`.

## Hors périmètre

- Les autres dossiers de Terminale (`tle-a1`, `tle-a2`, `tle`) : chantiers suivants.
- Le cours, les fiches, le 1er exercice de chaque notion et les 4 problèmes : inchangés.
- L'écran et le code (`app/`) : rien ne change, donc ni ADR ni UDR.

## Décisions

| Question | Réponse | Conséquence |
|---|---|---|
| Modèle ? | Le même que la Tle C (`lecons-tle-c-comme-thales`) | 2 exercices par notion, 4 sujets de 4 exercices de 5 ou 6 questions ; mêmes règles par matière. |
| Leçons dont la fiche est celle de la Tle C (31) ? | Pas refaites : les ajouts de la Tle C sont repris tels quels | Le script les fusionne dans le fichier de Tle D et les recontrôle (contenu d'origine inchangé, preuves, réponses faussées, `valider.rb`). |
| Leçons propres à la Tle D (14) ? | Rédigées, contrôlées puis relues comme en Tle C | Un rédacteur et un relecteur distincts par leçon. |
| Retour dans `lecons-traitees/` ? | Règle de retour de `a-reprendre/README.md` | Le fichier quitte `a-reprendre/` dans le même commit et le couple entre dans `db/seeds/standard/jeu.yml`. |

## Questions encore ouvertes

- Aucune.
