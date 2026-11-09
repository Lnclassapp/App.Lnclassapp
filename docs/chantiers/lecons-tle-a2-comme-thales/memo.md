# Memo — Les leçons de Terminale A2 préparées comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (2026-11-08) |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `feature/lecons-tle-a2-comme-thales` |
| **Ticket** | [#484](https://github.com/Lnclassapp/App.Lnclassapp/issues/484), étape 2, dossier `tle-a2` |

---

## Le problème

Les 31 leçons v3 de Tle A2 (Français 7, Mathématiques 7, Philosophie 10, SVT 7) attendent dans `docs/contenus/a-reprendre/` (chantier `base-de-lecons`) : un seul exercice par notion pour les 10 de Philosophie, aucun sujet de devoir pour toutes. Rien ne les charge.

## Pour qui

L'élève de Terminale A2 qui prépare une interro, un devoir ou le baccalauréat ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

La Tle C, la Tle D et la Tle A1 sont fusionnées (#505, #506, #507). Ordre fixé dans #484 : `tle-c`, `tle-d`, `tle-a1`, `tle-a2`, `tle`.

## Hors périmètre

- Le dernier dossier de Terminale (`tle`) : chantiers suivants.
- Le cours, les fiches, le 1er exercice de chaque notion et les 4 problèmes : inchangés.
- L'écran et le code (`app/`) : rien ne change, donc ni ADR ni UDR.

## Décisions

| Question | Réponse | Conséquence |
|---|---|---|
| Modèle ? | Le même que la Tle C et la Tle D | 2 exercices par notion, 4 sujets de 4 exercices de 5 ou 6 questions ; mêmes règles par matière. |
| Leçons dont la fiche est celle de la Tle A1 (28 : Français 7, Philosophie 10, Mathématiques 4, SVT 7) ? | Pas refaites : leurs ajouts (déjà relus en Tle A1, ou repris de Tle C) sont repris tels quels | Le script les fusionne dans le fichier de Tle A2 et les recontrôle (contenu d'origine inchangé, preuves, réponses faussées, `valider.rb`). |
| Fonction exponentielle et fonction logarithme (fiche presque identique, sans primitive en A2) ? | Ajouts de Tle A1 repris, puis relus pour retirer ce qui sort du programme de A2 | Un relecteur ciblé. |
| « Probabilité » (propre à la Tle A2) ? | Rédigée, contrôlée puis relue comme en Tle A1 | Un rédacteur et un relecteur distincts. |
| Retour dans `lecons-traitees/` ? | Règle de retour de `a-reprendre/README.md` | Le fichier quitte `a-reprendre/` dans le même commit et le couple entre dans `db/seeds/standard/jeu.yml`. |

## Questions encore ouvertes

- Aucune.
