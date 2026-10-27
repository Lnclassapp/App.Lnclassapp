# Memo — Les tests « aucun id révélé » des questions à relier et à ordonner échouent sans fuite

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-27 |
| **Branche** | `fix/question-matching-instable` |
| **Programme** | — |

---

## Symptôme

Pendant la mesure avant du chantier `ci-rejeu-cible` (train n° 1, `9ecaa07`), `test/integration/assessment/question_matching_test.rb` est rouge deux fois, sur `Develop`, sans que le code ait changé :

- ligne 96 : `Expected /\b15\b/ to not match "<!DOCTYPE html>…"` ;
- ligne 37 : `Expected ["2"] to be empty.`

Les trains suivants, sur le même code, sont verts. `test/integration/assessment/question_ordering_test.rb` porte les deux mêmes assertions (lignes 38 et 89).

## Ce qui est attendu, et où c'est écrit

CA-9 (ADR-0091 §4.4, UDR-0087) : la page d'une question à relier, ou à ordonner, ne révèle aucun id de réponse ; l'élève poste des indices d'affichage, jamais un id. Les tests le vérifient, et doivent échouer **seulement** si un id fuit.

## Reproduction

Les ids des réponses viennent de la séquence `answers_id_seq` de la base de test : ils dépendent des tests passés avant, dans le même processus. Ils sont parfois petits.

1. `source ~/.lnclass-ci-env`
2. Ajouter en tête du `setup` des deux fichiers : `Orm::Answer.connection.execute("ALTER SEQUENCE #{Orm::Answer.sequence_name} RESTART WITH 1")`.
3. `COVERAGE=0 bin/rails test test/integration/assessment/question_matching_test.rb test/integration/assessment/question_ordering_test.rb`

Résultat le 2026-10-27, sur `550c09f` : 14 runs, **4 échecs** à chaque passage. Deux sont dus à `Expected ["2", "3"] to be empty` ou `["1", "2"]` : les ids 1 à 3 valent les indices d'affichage `0`, `1`, `2`. Deux sont dus à `Expected /\b1\b/ to not match` : la page contient « Question 1 sur 2 » et le chemin SVG `M9 12.75 11.25 15 15 9.75`. Sans l'étape 2, les deux fichiers sont verts.

## Portée

- Depuis l'ajout des deux tests (lot G, ADR-0091). Ils n'échouent que si un id de réponse vaut un nombre de la page.
- **Aucun acteur touché** : l'application ne révèle aucun id (pages vérifiées : seul l'id de la question est posté, en champ caché, comme prévu). C'est un faux rouge qui coûte un train relancé.
- **Données corrompues : non.** Rien n'est écrit en base.

## Hors périmètre

- Les autres tests instables vus pendant `ci-rejeu-cible` (`blog_management_test`, `essential_images_test`, `boucle_pedagogique_test`) : causes différentes, à cadrer chacun.
- L'application : aucune ligne de `app/` ne change.

## Questions encore ouvertes

- —

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (ici : la suite, avec des ids forcés bas ; le bug est dans le test)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal (aucune)
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Contrat d'exécution (lot unique)

1. **Test de reproduction** : les deux fichiers forcent dans leur `setup` des ids de réponse bas (séquence relancée à 1), pour toujours jouer le pire cas. Lancés, ils sont **rouges** avec les messages ci-dessus.
2. **Correctif dans le test**, qui est la couche de la cause : comparer les ids aux **valeurs d'attribut** de la page (égalité exacte, ou segment d'URL), en écartant les seuls indices d'affichage, dont la liste exacte (`""`, `"0"`, `"1"`, `"2"`…) est déjà vérifiée à part. Jamais le texte entier de la page.
3. Vert, puis la suite `test/integration/assessment` et `test/controllers/assessment` au vert.
4. **Cas symétrique** : une fuite réelle (un `data-answer-id` ajouté à la vue, le temps d'un essai) fait toujours échouer les deux tests.
