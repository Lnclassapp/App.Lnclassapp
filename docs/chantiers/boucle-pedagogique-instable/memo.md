# Memo — La boucle pédagogique perd parfois un clic du Référentiel

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-27 |
| **Branche** | `fix/boucle-pedagogique-instable` |
| **Programme** | — |

---

## Symptôme

Pendant le bench S2 de `ci-rejeu-cible` (train, 2026-10-27), sans changement de code :

```
BouclePedagogiqueTest#test_a_blank_base,_then_the_whole_loop… [test/system/boucle_pedagogique_test.rb:432]:
expected "/teams/referential" to equal "/teams/drenas"
```

Le passage suivant, même code, est vert.

## Ce qui est attendu, et où c'est écrit

UDR-0068 §3.4 : depuis le Référentiel, la tuile « DRENA » mène à `/teams/drenas`. Le test le parcourt (`click_referential`, ligne 429) avant de créer une DRENA.

## Reproduction

Le Référentiel est déjà visité trois fois quand le test y revient pour les DRENA : Turbo en garde une copie en cache.

Test jetable `turbo_preview_click_test.rb` (rangé hors du dépôt, dans le scratchpad de la session) :
1. un membre de l'équipe ouvre le Référentiel, puis les Matières ;
2. la réponse du Référentiel est retenue ; on clique « Référentiel » : `assert_current_path` passe aussitôt et la page porte `html[data-turbo-preview]` ;
3. on presse la souris sur la tuile DRENA de la copie, on libère la réponse, la vraie page remplace la copie, on relâche.

Résultat : `expected "/teams/referential" to equal "/teams/drenas"`, à chaque fois. Avec le Référentiel seulement ralenti (1,5 s), le test entier reste vert : le clic ne se perd que s'il chevauche le remplacement.

## Portée

- Depuis l'ajout du Référentiel en page (UDR-0068 §3.4). Rare : la fenêtre est celle du remplacement de la copie par la page.
- **Aucun acteur touché** : un humain qui perd un clic reclique. Faux rouge qui coûte un train.
- **Données corrompues : non.**

## Hors périmètre

- Les autres `assert_current_path` après un clic de lien Turbo dans `test/system` (236 occurrences) : à auditer dans un chantier de suivi s'ils échouent, noté au journal.
- L'application : aucune ligne de `app/` ne change.

## Questions encore ouvertes

- —

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (navigateur piloté, réponse retenue)
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

1. **Reproduction** : la scène ci-dessus, rejouée contre le `navigate_to` du test ; rouge avec le message du symptôme.
2. **Correctif dans le test** (`navigate_to`, ligne 423) : après l'URL, attendre que la page ne soit plus une copie (`assert_no_selector "html[data-turbo-preview]"`). Aucun clic ne part plus d'une copie.
3. Vert, puis `boucle_pedagogique_test.rb` entier, plusieurs fois, et avec le Référentiel ralenti.
4. **Cas symétrique** : une page sans copie en cache (première visite) se parcourt toujours ; le test ne ralentit pas sensiblement.
