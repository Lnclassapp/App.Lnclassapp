# Journal — Les trois premières leçons de 1ère et de 2nde, comme Thalès

> Rempli **pendant** le chantier, pas reconstitué à la fin.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | En 1ère, le 2e exercice de chaque notion est ajouté même pour les fichiers `sujets-manquants` ; leur `practice` reste tel quel | C'est le format Thalès (Tle C, 36 fichiers de la même catégorie) ; `practice` (3 ou 4 questions) n'est pas l'exercice de 6 questions | Non |
| 2026-11-12 | Une leçon de même fiche dans plusieurs séries est écrite une fois et recopiée, avec le `series_name` et le `theme` de chaque série | Demande du porteur ; une seule source à relire | Non |

## Ce qui a dérapé

- **Contre-exemple hors programme** : en Mathématiques 1ère C (Généralités sur les fonctions), deux corrections prenaient $f(x)=x \bmod 6$ comme contre-exemple de période. Le reste modulo n'est pas au programme : les deux phrases ont été réécrites sans lui.
- **Références de rang** : en SVT 1ère C (gonades, sujet 2), « la première fonction » et « la seconde fonction » de l'ovaire ; réécrites (« liée aux gamètes », « liée aux hormones »). Les autres « premier » et « second » trouvés renvoient à l'énoncé de la question elle-même (strophe, axe, coupe), pas à une autre question.
- **`core.hooksPath` absolu** : la création des worktrees des rédacteurs l'a réécrit en chemin absolu dans le dépôt ; remis à `.githooks` après chaque intégration.
- **Doublons d'accents refusés** : `valider.rb` refuse deux réponses acceptées qui ne diffèrent que par l'accent (`duplicate_accepted`) ; les rédacteurs n'en gardent qu'une.

## Ce qu'on a appris sur la codebase

- `valider.rb` ne valide toujours pas `subjects` (dette déjà notée en Tle C) ; le script hors dépôt le relance avec chaque sujet à la place des 4 problèmes.
- Les fichiers `sujets-manquants` de 1ère avaient un seul `exercise` par notion plus un `practice` de 3 ou 4 questions : `base-de-lecons` comptait le `practice` comme 2e exercice.
- `standard_activity_test.rb` charge les 27 premières leçons du manifeste : avec les 21 couples de 1ère revenus en tête, ce sont de nouveau « la 1ère et la 3ème » de son commentaire. Empreinte `be0ef46649` → `3dc776ea12`, mise à jour sciemment.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets | Le chantier ne touche que du contenu | À ouvrir (déjà noté en 3ème et Tle C) |
| Leçons de rang 4 et plus en 1ère et en 2nde | Demande limitée aux 3 premières | Chantiers suivants |

## À trancher

Options prudentes appliquées ; un enseignant de la matière relit avant publication.

- **Valeurs illustratives** : les données chiffrées des énoncés ajoutés (mesures, effectifs, prix, résultats d'expérience) sont fictives. En Histoire-Géographie 1ère, seuls les recensements (1975, 1988, 1998, 2014, 2021) et la population de 2021 de la fiche sont des chiffres réels.
- **Textes supports** : en Français et en Philosophie, tous écrits pour Lnclass (aucune citation d'auteur ajoutée).
- **Réponses saisies à une seule graphie** (« testostérone », « propène »…) : une faute de frappe compte faux. Option possible : plus de formes acceptées.
- **Mathématiques 1ère** : convention de signe de l'aiguille d'une montre (sens indirect) ; quelques `written` dans les sujets 3 et 4, barème à valider ; en Généralités sur les fonctions (C, D), les variations sont prouvées par le signe de $f(b)-f(a)$, sans dérivée.
- **Philosophie 1ère** : « Ainsi » est la seule bonne réponse pour ouvrir une conclusion (comme la fiche) ; « Pour conclure » n'est pas proposé.
- **SVT 1ère A (drogues)** : un document fictif montre la cocaïne raccourcissant le temps de réaction, ce que la fiche ne dit pas en ces termes (« stimulante »).
- **SVT 1ère C et D** : les corrections de sujets sont courtes et complétées d'un rappel automatique de la méthode et du piège de la notion ; à étoffer.
- **Histoire-Géographie 1ère** : le procédé Bessemer (1856) est rattaché à la seconde révolution industrielle, comme la fiche.

### 2nde (réécriture complète depuis `format-v1/`)

- **Thème** : aucun v1 de 2nde n'avait de `theme` ; les fichiers v3 n'en ont pas (bleu par défaut), sauf Mathématiques 2nde C (bleu, sarcelle, bordeaux). Option possible : un thème par matière, comme en Tle.
- **Mathématiques 2nde A** : « Racines carrées simples » (leçon 1), « Tableau à double entrée » et « Diagramme et réunion de deux ensembles » (leçon 2) ne sont pas dans le v1 ; dénombrement par produits décroissants sans notation factorielle ; `card(A)` employé. Unités « m² », « cm² » en `numeric`.
- **Mathématiques 2nde C** : symétrie axiale limitée aux axes (Ox) et (Oy) ; composition de transformations exclue ; périmètre de la colinéarité, du déterminant, de la valeur absolue et des encadrements repris du v1, à confirmer contre la progression.
- **Physique-Chimie 2nde** : « classification simple » (leçon 2) traitée comme mélange / corps simple / corps composé ; le nombre d'électrons d'un ion à partir de Z est demandé en leçon 3, sans structure électronique ni octet.
- **SVT 2nde A** : insuline sans glucagon ni glande mixte, glycémie ≈ 1 g/L ; mangrove traitée comme un milieu littoral à part ; notions « à compléter » du v1 (potentiel d'action, toundra, taïga, forêt tempérée) non écrites.
- **SVT 2nde C** : composition de la solution de Knop donnée de mémoire ; hypotonique, hypertonique, isotonique écartés ; « chlorose » employé.
- **Histoire-Géographie 2nde** : aucune périodisation (Antiquité, Moyen Âge) faute de bornes sûres ; dates réelles citées : 1893, 1914, 1945, 20 septembre 1960 (ONU), 2012 (Grand-Bassam à l'UNESCO) ; documents d'archive des exercices fictifs.
- **Français 2nde** : adjuvant et opposant gardés (le v1 les marquait « à faire valider ») ; une question de sujet porte sur un retour en arrière ; 4e notion « lettre personnelle et lettre formelle » (leçon 2), à retirer si hors programme ; fonctions du langage non traitées ; résumé au quart, marge de 10 % et décompte des mots repris du modèle de 3ème.

## Correctif après le train #571

- **Débordement à 390 px** : en Mathématiques 2nde A (Calcul littéral), une réponse d'ordonnancement portait une formule d'une seule pièce de 72 caractères (développement d'un produit) ; la feuille à remplir faisait 538 px. La preuve de #570 ne l'a pas vu : le test d'affichage ne rend que 5 leçons tirées au hasard parmi les changées (`Selection::MAX`), et ce fichier n'était pas tiré. Correctif : les formules en ligne de 50 caractères ou plus des Mathématiques et de la Physique-Chimie de 2nde sont coupées en plusieurs `$…$` aux signes « = », « + », « − » de premier niveau (27 formules, 3 fichiers, corrections comprises) ; les 6 leçons de Mathématiques de 2nde rendues une à une, vertes.
- **À retenir** : pour une vague de leçons, rendre toutes les leçons touchées par lots de 5 (`LECONS=<5 chemins>`), pas seulement le tirage de `bin/ci-quiet`.
- **1ère, rendu complet après #573** : les 63 leçons de 1ère rendues d'un coup (copie hors dépôt du test d'affichage sans la limite de 5, 9 min). Un défaut, le même en A1 et A2 : Généralités sur les fonctions, feuille « Étudier le sens de variation et les extremums », 432 px à 390 px, à cause d'une réponse portant $f(b) - f(a) = b^2 - a^2 = (b - a)(b + a)$ d'une pièce. Corrigé comme en 2nde : formules en ligne de 40 caractères ou plus coupées dans ce fichier, de 50 ou plus dans les autres leçons de Mathématiques et de Physique-Chimie de 1ère (14 fichiers) ; les 14 rendues vertes.

## Correctif « Je m'entraîne » (2nde)

- **Constat** : aucune des 90 notions des 27 fichiers de 2nde n'avait le bloc « Je m'entraîne » (`practice`, UDR-0147) : la fiche de révision n'y proposait aucun exercice. Cause : les consignes de réécriture v1 → v3 ne l'exigeaient pas, et `docs/contenus/prompt-redaction.md` ne le citait pas. Même défaut en 1ère Philosophie (14 notions × 4 séries) et Histoire-Géographie (12 notions), corrigés dans une PR à part.
- **Correctif** : un `practice` de 3 ou 4 questions corrigées automatiquement, d'au moins 2 types, sur chaque notion (le même pour A et C en Français et Physique-Chimie) ; rien d'autre ne change dans les fichiers (vérifié par script contre `Develop`). `prompt-redaction.md` rend le bloc obligatoire, avec une ligne de la liste de contrôle.
- **Rendu** : les 27 leçons de 2nde rendues à 390 px (copie du test d'affichage sans la limite de 5).
- **À faire vérifier par un enseignant** : SVT 2nde C (Knop et carences, sol inondé, mots attendus des textes à trous) ; Mathématiques 2nde A (distracteur $2\sqrt{16}$) ; Français (lettre formelle, marge de 10 %) ; Physique-Chimie (Fe³⁺, argon (K)2(L)8(M)8, propane) ; Histoire-Géographie (distracteurs sur les devises, Grand-Bassam 2012).
## Correctif « Je m'entraîne » (1ère)

- **Constat** : en 1ère, la Philosophie (14 notions, recopiées dans les 4 séries) et l'Histoire-Géographie (12 notions) n'avaient pas le bloc « Je m'entraîne » (`practice`, UDR-0147). Les autres matières de 1ère l'avaient déjà. La règle qui le rend obligatoire est ajoutée à `prompt-redaction.md` par la PR 2nde.
- **Correctif** : 3 ou 4 questions corrigées automatiquement, d'au moins 2 types, sur chaque notion. La Philosophie compte 48 questions par série, identiques en A1, A2, C et D ; l'Histoire-Géographie en compte 45. Hors `practice`, aucun fichier ne change (vérifié par script contre `Develop`). Les 15 leçons sont rendues à 390 px.
- **À faire vérifier par un enseignant** :
  - Philosophie : « travail » et « seulement » comme termes à définir ; la thèse sur l'argent et le bonheur ; paraphrase contre explication ; les synonymes acceptés dans les textes à trous (« mais » ou « cependant », « enfin » ou « finalement »).
  - Histoire-Géographie : la vraisemblance des montants en F CFA et des taux démographiques, qui sont des valeurs d'exercice ; la réponse « La sécurité » à la question sur l'IDH ; les écarts de dates calculés à la main.
