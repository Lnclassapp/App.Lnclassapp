# Memo — Une image glissée dans un article prend le focus à l'auteur qui écrit ailleurs

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-07 |
| **Branche** | `fix/alt-couverture-perdu` |
| **Programme** | — |

---

## Symptôme

Dans la modale « Nouvel article » du blog, l'auteur glisse une image dans le texte, puis tape aussitôt le texte de remplacement de la couverture. Quand l'image réduite entre dans le texte, le curseur saute dans l'éditeur : **ce que l'auteur tape va dans le texte de l'article** (« ￼U↵ne élève… »), et le texte de remplacement de la couverture reste vide.

Vu d'abord comme un test instable : `test/system/teams/blog_management_test.rb`, parcours A, échoue à peu près une fois sur deux en suite complète. Le serveur y reçoit `"cover_alt" => ""` : `[64, 48, nil]` au lieu de `[64, 48, "Une élève révise à sa table"]`. Vu sur l'arbre de la release du 2026-10-07, sur la branche de #196 et sur Develop `2da31c20`. Seul, le test passe.

**Comportement attendu** : le focus reste là où écrit l'auteur. L'UDR-0067 §3.4.2 le dit de l'arrivée d'une image (« Le focus ne bouge pas : l'auteur continue d'écrire », WCAG 3.2.2). Une image est insérée « à la position du curseur » de l'éditeur (§3.4.2, `trix-file-accept`), sans que l'éditeur reprenne le focus.

## Reproduction

| | |
|---|---|
| **Acteur** | membre de l'équipe, rôle Contenu (ou admin) |
| **Environnement** | application locale, Chromium 141 (navigateur des tests système) |
| **Données** | une image de 2000 × 1500 px, que le navigateur doit réduire à 1600 px |
| **Étapes** | 1. `/teams/blog/new`. 2. Glisser l'image dans « Texte ». 3. Aussitôt, cliquer dans « Texte de remplacement » de la couverture. 4. Attendre la ligne « Image 1 » sous l'éditeur. 5. Taper « Une élève ». → Le focus est dans `article_body`, le champ de la couverture est vide, le texte de l'article vaut « ￼U↵ne élève ». |
| **État** | ✅ **Reproduit 3 fois sur 3** le 2026-10-07, par un script de navigateur jetable qui joue ces étapes. Le focus est bien sur `article_cover_alt` juste après le dépôt, puis sur `article_body` une fois l'image entrée dans le texte. |

Le test du parcours A tombe dans la même fenêtre sous charge. Il glisse l'image, attend la couverture, puis remplit son texte de remplacement. Seul, la réduction finit avant la saisie. En suite complète (quatre navigateurs en parallèle), elle finit parfois pendant.

## Portée

- **Depuis** : le 2026-10-03, l'insertion d'images dans le texte du blog (`6a3ba2f4`, #144). En production depuis le 2026-10-07.
- **Acteurs** : l'équipe (rôles Contenu et admin), seuls auteurs du blog. Les éditeurs de cours et de fiches refusent toute image : ils ne passent pas par ce chemin.
- **Champs touchés** : tout champ où l'auteur écrit pendant la réduction d'une image glissée, collée ou choisie par « Insérer une image ». Concrètement : titre, extrait, signature, textes de remplacement.
- **Données corrompues** : aucune en base que l'on sache repérer. Le texte égaré atterrit dans le texte de l'article, sous les yeux de l'auteur, qui le voit avant d'enregistrer. **Pas de réparation** : rien ne distingue un tel texte d'une saisie voulue (dette assumée, `journal.md`).

## Hors périmètre

- Le comportement de Trix lui-même (il place le curseur dans l'éditeur à chaque insertion) : on le corrige chez nous, autour de l'insertion, pas dans Trix.
- La couverture (`cover_picker_controller.js`) : son envoi ne touche ni le focus ni l'éditeur.
- Les autres tests instables de la suite système : chacun son chantier.

## Portes de sortie

Un seul lot, aucune migration, aucun fichier partagé : pas de `plan.md` ni de `prd.md`.

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [ ] Données déjà corrompues : réparées, ou dette explicitement notée au journal
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés

### Contrat d'exécution

1. Écrire le test de reproduction dans `test/system/teams/blog_management_test.rb`. Il faut un vrai navigateur : le focus et Trix n'existent pas plus bas dans la pile. Mettre ce test dans un fichier existant tient le budget de la suite système (ADR-0069 §9 : un fichier sans durée enregistrée est refusé). Le test glisse une image dans le texte, place aussitôt le focus dans le texte de remplacement de la couverture, attend la ligne « Image 1 », vérifie que le focus n'a pas bougé, puis que la frappe arrive dans ce champ.
2. Le lancer et le voir **rouge** pour la bonne raison : le focus est sur `article_body`.
3. Corriger dans `app/javascript/controllers/rich_text_editor_controller.js` (`prepare`, autour de `this.editor.insertFile(ready)`). Si l'auteur écrivait ailleurs que dans l'éditeur au moment de l'insertion, lui rendre le focus, et la sélection de son champ, dès l'insertion faite.
4. Vert ; puis les tests système du blog, de l'éditeur des cours et des fiches (cas symétrique : glisser une image en écrivant dans l'éditeur garde le curseur dans le texte, juste après l'image).
