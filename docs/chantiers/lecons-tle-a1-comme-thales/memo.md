# Memo — Les leçons de Terminale A1 préparées comme Thalès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours (2026-11-07) |
| **Ouvert le** | 2026-11-07 |
| **Branche** | `feature/lecons-tle-a1-comme-thales` |
| **Ticket** | [#484](https://github.com/Lnclassapp/App.Lnclassapp/issues/484), étape 2, dossier `tle-a1` |

---

## Le problème

Les 32 leçons v3 de Tle A1 (Français 7, Mathématiques 8, Philosophie 10, SVT 7) attendent dans `docs/contenus/a-reprendre/` (chantier `base-de-lecons`) : un seul exercice par notion pour les 10 de Philosophie, aucun sujet de devoir pour toutes. Rien ne les charge.

## Pour qui

L'élève de Terminale A1 qui prépare une interro, un devoir ou le baccalauréat ; l'enseignant qui envoie un sujet à sa classe.

## Pourquoi maintenant

La Tle C et la Tle D sont fusionnées (#505, #506). Ordre fixé dans #484 : `tle-c`, `tle-d`, `tle-a1`, `tle-a2`, `tle`.

## Hors périmètre

- Les autres dossiers de Terminale (`tle-a2`, `tle`) : chantiers suivants.
- Le cours, les fiches, le 1er exercice de chaque notion et les 4 problèmes : inchangés.
- L'écran et le code (`app/`) : rien ne change, donc ni ADR ni UDR.

## Décisions

| Question | Réponse | Conséquence |
|---|---|---|
| Modèle ? | Le même que la Tle C et la Tle D | 2 exercices par notion, 4 sujets de 4 exercices de 5 ou 6 questions ; mêmes règles par matière. |
| Leçons dont la fiche est celle de la Tle C et de la Tle D (15 : Français 6, Philosophie 9) ? | Pas refaites : leurs ajouts sont repris tels quels | Le script les fusionne dans le fichier de Tle A1 et les recontrôle (contenu d'origine inchangé, preuves, réponses faussées, `valider.rb`). |
| Leçons propres à la Tle A1 (17) ? | Rédigées, contrôlées puis relues comme en Tle C et D | Un rédacteur et un relecteur distincts par leçon. |
| Retour dans `lecons-traitees/` ? | Règle de retour de `a-reprendre/README.md` | Le fichier quitte `a-reprendre/` dans le même commit et le couple entre dans `db/seeds/standard/jeu.yml`. |

## Questions encore ouvertes

- Aucune.
