# Memo — Finitions de la génération des classes et du menu ⋮ au téléphone

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `fix/finitions-generation-menu` |
| **Programme** | — |

---

Trois défauts relevés par les recettes du 2026-09-28 (chantiers [`generer-classes`](../generer-classes/memo.md) et [`actions-en-menu`](../actions-en-menu/prd.md)). Le porteur : « occupe-toi des autres points ». Un seul lot : trois correctifs d'affichage indépendants, sans migration ni donnée à réparer.

## Symptômes

1. **« Déjà en cours » affiché comme une erreur.** Sur « Établissements », « Générer les classes manquantes » → « Lancer la génération » pendant qu'une génération tourne : retour sur « Établissements » avec un toast **rouge**, titré « Une erreur est survenue », qui reste affiché jusqu'à fermeture, et « Suivez-la dans « Imports » » sans chemin direct vers le rapport. Attendu : un état normal (une génération à la fois), annoncé comme une information, qui mène au rapport en cours.
2. **Une génération « Import en cours ».** Sur « Imports » (liste, rapport, accueil de l'équipe), une génération des classes en statut `importing` porte le badge « Import en cours » ; `validating` dit « Vérification ». Attendu : « Génération en cours », « Recherche des établissements » — les mots du type, comme le reste du rapport (UDR-0043 §2.4).
3. **Menu ⋮ hors écran au téléphone.** À 390 px, sur les tableaux de l'équipe (DRENA, établissements, séries, niveaux, matières), la colonne des actions est à droite d'un tableau plus large que l'écran (`min-w-2xl` à `min-w-4xl`) : le ⋮ de la première ligne n'est pas visible au chargement ; il faut faire défiler le tableau pour l'atteindre.

## Reproduction

Acteur : membre de l'équipe (second facteur validé), données de développement.

1. Lancer une génération des classes, puis la relancer avant sa fin (ou créer un rapport `kind: "classrooms", status: "importing"`) → `POST /teams/schools/classroom-generations` → 303 vers `/teams/schools`, `flash[:alert]` → toast `error`.
2. Même rapport en cours → `/teams/imports` : badge « Import en cours » sur la ligne « Génération des classes ».
3. Fenêtre 390 × 844, `/teams/schools` avec au moins un établissement : `getBoundingClientRect()` du ⋮ de la première ligne → `left` ≈ 850 px, au-delà des 390 px de l'écran.

## Portée

- 1 et 2 : depuis la génération des classes (PR #43, 2026-09-28). Tout membre de l'équipe qui relance une génération ou regarde « Imports » pendant qu'elle tourne.
- 3 : depuis le passage des actions dans un menu (UDR-0042, 2026-09-28). Tout membre de l'équipe sur téléphone. Le menu, une fois atteint, s'ouvre bien en entier (test existant).
- Aucune donnée corrompue : trois défauts d'affichage.

## Source du comportement attendu

- UDR-0043 §2.3–2.4 : le suivi est celui des imports ; « les mots du rapport suivent le type ». Le toast d'erreur du §3 était une erreur de la décision elle-même : amendée le 2026-09-28.
- UDR-0006 : le toast `error` est réservé à l'échec, il reste affiché ; l'information se ferme seule.
- UDR-0042 §3 : le ⋮ est la seule entrée des actions d'une ligne ; il doit être atteignable au téléphone (amendé le 2026-09-28).
- Demande du porteur du 2026-09-28.

## Hors périmètre

- Le contenu des toasts ne devient pas cliquable (pas de lien dans un toast) : la redirection vers le rapport suffit.
- Aucune colonne des tableaux n'est retirée ni masquée au téléphone ; aucun tableau ne devient une liste de cartes.
- Le tableau des imports n'a pas de ⋮ : il n'est pas concerné par le point 3.
- Le port `ImportReportRepositoryPort#create` ne renvoie pas le rapport en cours dans son `:conflict` : la lecture passe par la query existante.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (recettes du 2026-09-28 ; point 3 mesuré à 390 px, capture avant)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test (`journal.md`)
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : aucune (défauts d'affichage), noté au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application (captures avant/après à 390 px)
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
