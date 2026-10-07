# Journal — Une image glissée dans un article prend le focus à l'auteur qui écrit ailleurs

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Test classé « instable » pendant trois promotions** (2026-10-06 et 07). Relancé seul, il passait ; on a promu en le signalant comme connu. C'était un vrai défaut de l'interface, visible d'un auteur qui va vite.
- **Première hypothèse fausse** : `SelectionManager#clearSelection` de Trix (`removeAllRanges`) retirerait le focus du champ. Une sonde l'a écartée : vider la sélection ne bouge pas le focus dans Chromium.
- **Reproduction par la charge, sans succès** : 6 passages seuls sous 4 cœurs occupés, puis 5 suites complètes avec un journal des événements du champ, tous verts. Le journal (des allers-retours Selenium de plus) suffisait à décaler la fenêtre. C'est la lecture du code de l'éditeur, puis une reproduction **déterministe** (déposer, puis donner le focus au champ dans le même tour de script), qui a tranché.
- **Recherche du texte perdu** : on le croyait perdu, il était dans le texte de l'article, coupé par Trix (« ￼U↵ne élève »). La recherche d'une phrase entière dans les paramètres ne pouvait pas le trouver.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

### Rapport de root cause (2026-10-07)

**Chaîne d'appels** :
1. Dépôt, collage ou « Insérer une image » dans l'éditeur du blog → `trix-file-accept`.
2. `rich_text_editor_controller.js#accept` refuse le fichier à Trix, puis le met en file (`queueMicrotask`) → `insertFiles` → `track(prepare(files))`.
3. `prepare` attend `prepareImage` (`lib/image_upload` : décodage, réduction dans un `canvas`, encodage). C'est long pour une photo de 2000 px, et bien plus long sous charge. Pendant ce temps, l'auteur peut écrire ailleurs.
4. **`app/javascript/controllers/rich_text_editor_controller.js:124`, `this.editor.insertFile(ready)`**.
5. Trix insère la pièce jointe à sa dernière position de curseur, puis demande la sélection juste après elle (`compositionDidRequestChangingSelectionToLocationRange` → `EditorController#compositionControllerDidRender` → `SelectionManager#setLocationRange` → `setDOMRange` → `selection.addRange` dans `trix-editor`).
6. Chromium donne le focus à l'élément éditable qui reçoit une sélection posée par script : il le retire au champ où l'auteur écrivait (sonde : `article_cover_alt` → `editable`). Les frappes suivantes vont dans le texte de l'article.

**Cause, sans les mots du symptôme** : le contrôleur de l'éditeur insère une image de façon asynchrone, sans tenir compte de l'endroit où se trouve l'auteur à ce moment-là, et l'insertion par Trix déplace le focus.

**Pourquoi aucun test ne l'a vu** : le parcours A glisse l'image, puis attend la couverture avant de taper. Seul, la réduction est déjà finie quand il tape ; aucun test ne place le focus hors de l'éditeur **pendant** la réduction, ni ne vérifie le focus après une insertion asynchrone. Le test de reproduction se place donc au niveau système, dans ce même fichier, avec un ordre déterministe : dépôt, puis focus ailleurs dans le même tour de script.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Brouillons existants où du texte aurait atterri par erreur | Rien ne le distingue d'une saisie voulue ; l'auteur le voit dans l'éditeur avant d'enregistrer | — (dette assumée) |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
