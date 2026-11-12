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
