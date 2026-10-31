# Memo — Couverture du train #417

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-31 |
| **Branche** | `bugfix/couverture-train` |
| **Programme** | — |

---

## Le problème

Le train `Develop → Staging` (PR #417) est rouge : la suite unitaire passe (7 711 tests, 0 échec), mais la couverture
tombe à 99,95 % des lignes et 99,13 % des branches, sous le seuil de 100 % (ADR-0024). Les PR vers `Develop` ne mesurent
pas la couverture (niveau `pr` de `bin/ci-quiet`, ADR-0107) : les trous de deux chantiers ne se voient qu'au train.

## Pour qui

L'équipe : le train ne passe pas en recette tant que la couverture n'est pas revenue à 100 %.

## Pourquoi maintenant

Le train porte « Prépare interros » / « Prépare devoirs » et « Je m'entraîne » ; Touré veut les tester en recette.

## Hors périmètre

Tout changement de comportement. Un trou se ferme par un test du comportement réel ; une branche prouvée inatteignable
se retire (code mort), sans changer ce que voit un utilisateur.

## Cause racine

Mesure locale (suite complète, `DEFAULT_TEST_EXCLUDE` de `config/ci.rb`) : 9 lignes et 48 branches jamais jouées, dans
`prepare-interros-cahier` (contrôleur de vérification sur la feuille, requêtes des feuilles, envoi groupé, sujet, copie)
et `je-m-entraine-dans-la-fiche` (indice, entraînement, nœud de contenu, sélection). Liste complète dans le journal.
