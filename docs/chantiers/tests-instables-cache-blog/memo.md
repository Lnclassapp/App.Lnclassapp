# Memo — Tests instables : cache de l'accueil de la direction et texte alternatif du blog

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré |
| **Ouvert le** | 2026-10-08 |
| **Branche** | `fix/tests-instables-cache-blog` |
| **Programme** | — |

---

## Le problème

Deux tests échouent par intermittence sous la charge de `bin/ci`, et passent quand on les relance seuls. Relevés pendant le chantier [`inscription-enseignant`](../inscription-enseignant/journal.md) (Lots D, F et G), sans lien avec lui. Le porteur a demandé leur correction le 2026-10-08.

### Symptômes

1. **`test/infrastructure/queries/school/direction_home_query_test.rb`**, test « AD-23: a second read within 5 minutes runs no query; … fresh at 5 min 01 s » : `Expected: 2  Actual: 1` (ligne 199). Vu 2 fois sur 6 passages complets de `bin/ci` (Lots F et G).
2. **`test/system/teams/blog_management_test.rb`**, création d'un article : le texte alternatif de la couverture est enregistré **tronqué** — « Une élève ré… », puis « …à sa tab » au lieu de « Une élève révise à sa table ». Vu 3 fois (Lot D, puis 2 passages sur 2 au Lot G) ; vert seul, et vert au passage complet suivant.

### Reproduction

1. Lancer `bin/ci` sur une machine chargée ; ou, de façon déterministe, faire durer la première lecture de l'accueil plus d'une seconde (à écrire au test de reproduction).
2. Équipe connectée, « Nouvel article » : déposer une grande image dans le texte, puis, **pendant qu'elle est réduite, prévisualisée ou envoyée**, cliquer dans « Texte alternatif de la couverture » et taper « Une élève révise à sa table » à vitesse humaine. Le champ garde « Une élève ré », le curseur saute dans le texte de l'article, et « vise à sa table » s'y écrit en silence. Reproduit de façon déterministe (4 cas sur 4, frappe à 100 ms par touche comprise ; témoin sans image : vert) en retenant la réduction ou la réponse de l'envoi et en la relâchant au 12e caractère.

### Portée

- Depuis le chantier `accueil-direction` (2026-10-04) pour (1) ; depuis le chantier `blog` pour (2).
- Acteurs touchés : aucun en production pour (1) (défaut du test seul). **(2) est un vrai défaut** pour l'équipe qui écrit les articles : tout champ du formulaire (titre, résumé, textes alternatifs) perd le focus au profit du texte de l'article quand une image du texte est insérée ou finit son envoi. Même éditeur pour les cours (`course_management`) : à vérifier au correctif.
- Données à réparer : non.

## Pour qui

Les contributeurs (une CI qui échoue au hasard coûte un `bin/ci` de 15 minutes et pousse à relancer jusqu'au vert) ; et, si (2) est un vrai défaut, l'équipe Lnclass qui écrit les articles du blog.

## Pourquoi maintenant

Ils ont fait échouer `bin/ci` pendant `inscription-enseignant` ; la CI GitHub saute ses jobs sur les PR, donc `bin/ci` local est la seule preuve avant fusion.

## Hors périmètre

- Deux lancements de tests simultanés dans le même dossier qui se partagent les bases des workers (cause du `PG::UndefinedColumn national_code` vu pendant `inscription-enseignant`) : outillage, noté au journal, pas un test instable.
- Pourquoi la CI GitHub saute ses jobs sur les PR.
- Tout autre test instable qu'on croiserait : journal, puis chantier suivant.

## Cause en une phrase

1. Le test mesure le délai de 5 minutes depuis un instant pris **avant** que l'entrée ne soit écrite, alors que l'expiration part de son écriture.
2. L'éditeur de texte riche restaure sa dernière position de curseur à chaque redessin, même quand un autre champ a la main, et le navigateur lui donne alors le focus.

Rapport complet : [`journal.md`](journal.md).

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quel document fixe le comportement attendu ? | (1) AD-23 (ADR-0065, amendement du 2026-10-04) : frais après 5 min ; (2) aucun texte écrit, mais une saisie ne doit jamais partir dans un autre champ (attente élémentaire) | (1) défaut du test ; (2) défaut de l'application, corrigé dans l'éditeur |
| (2) est-il un artefact de Capybara ? | Non : reproduit avec un vrai clic et une frappe à 100 ms par touche | Correctif côté application, et le test du blog vérifie désormais le focus et le corps du texte |
| Des données sont-elles fausses en base ? | Peut-être des articles du blog dont le texte contient des morceaux de texte alternatif, si un auteur a tapé pendant un envoi | Pas de réparation automatique possible (on ne sait pas distinguer) : dette notée, l'équipe relira ses brouillons |

## Cas limites identifiés

- Correctif (2) : l'image insérée doit toujours aller **à la position du curseur** dans le texte, même si le focus est ailleurs.
- Le titre, le résumé, les textes alternatifs des autres images et le formulaire des cours passent par le même éditeur.
- Le focus dans l'éditeur lui-même pendant l'envoi : comportement inchangé.

## Questions encore ouvertes

- Le correctif (2) s'appuie sur une API interne de Trix (`editorController.selectionManager`) : à documenter dans le code et à signaler au projet Trix.

## Portes de sortie (lot unique : `plan.md` supprimé)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code *(frappe à 100 ms par touche dans Chrome, et AD-23 par lecture ralentie)*
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [x] Challenger a rejoué les étapes de reproduction dans l'application
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
