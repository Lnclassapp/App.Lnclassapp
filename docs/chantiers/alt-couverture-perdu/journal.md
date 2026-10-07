# Journal — Une image glissée dans un article prend le focus à l'auteur qui écrit ailleurs

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-07 | Le garde du focus vit dans `rich_text_editor_controller.js`, autour du `SelectionManager` de Trix (`setLocationRange`), et non autour de notre seul `insertFile` | Trix replace son curseur à **chaque** rendu du texte, pas seulement à l'insertion : taille de l'aperçu connue, adresse reçue, image retirée (voir le rapport). Rendre le focus après `insertFile` ne tenait pas 10 ms | Non : précédent de l'ADR-0068 (API privée, gardée par un test). Le test système du blog casse si une montée de Trix change ce point |
| 2026-10-07 | Un fichier glissé dans le texte pendant que l'auteur écrit dans un autre champ ne lui prend plus le focus non plus ; « Insérer une image » le donne toujours au texte | UDR-0067 §3.4.2 à la lettre (« le focus ne bouge pas »). Le bouton reste une demande explicite d'écrire dans le texte : comportement d'avant gardé | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Test classé « instable » pendant trois promotions** (2026-10-06 et 07). Relancé seul, il passait ; on a promu en le signalant comme connu. C'était un vrai défaut de l'interface, visible d'un auteur qui va vite.
- **Première hypothèse fausse** : `SelectionManager#clearSelection` de Trix (`removeAllRanges`) retirerait le focus du champ. Une sonde l'a écartée : vider la sélection ne bouge pas le focus dans Chromium.
- **Reproduction par la charge, sans succès** : 6 passages seuls sous 4 cœurs occupés, puis 5 suites complètes avec un journal des événements du champ, tous verts. Le journal (des allers-retours Selenium de plus) suffisait à décaler la fenêtre. C'est la lecture du code de l'éditeur, puis une reproduction **déterministe** (déposer, puis donner le focus au champ dans le même tour de script), qui a tranché.
- **Premier correctif insuffisant** : rendre le focus au champ juste après `insertFile`. Le test restait rouge. Une sonde (pile d'appels de chaque `focusin`) a montré deux autres vols : Trix lui-même, quelques millisecondes après le dépôt (insertion vide du fichier qu'on lui refuse), puis 6 ms après notre insertion, au rendu suivant (`attachment.setAttributes` de l'aperçu → `SelectionManager#unlock` → `setLocationRange`).
- **Premier test trop tôt** : il donnait le focus au champ dans le tour même du dépôt, avant que Trix ait fini de le traiter. Il mesurait alors le vol propre au dépôt, qu'aucun auteur ne peut devancer. Le test donne désormais le focus une fois `trix-file-accept` passé, et vérifie qu'à cet instant l'image n'est pas encore dans le texte (sinon il serait vert sans rien prouver).
- **`bin/ci` rouge sur le test du bundle** : le garde nommait `trix-toolbar` en toutes lettres, chaîne que `test/javascript_bundle_test.rb` prend pour témoin de Trix dans le point d'entrée commun (ADR-0051). La barre d'outils est désormais lue par `toolbarElement`.
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

**Complément après la sonde** : l'étape 5 n'est pas la seule. Trix verrouille puis rend sa sélection à chaque rendu qui synchronise le texte (`compositionControllerWillSyncDocumentView` → `lock` ; `…DidSyncDocumentView` → `unlock` → `setLocationRange`). Le curseur qu'il retient reste celui d'avant la sortie de l'auteur. Chaque changement du texte par script le remet donc dans la page : l'insertion, la taille de l'aperçu (Trix, `setAttributes`), l'adresse reçue après l'envoi (`upload`, `setAttributes`), le retrait d'une image refusée. L'envoi dure des secondes sur un réseau lent : la fenêtre est bien plus large que la seule réduction.

**Cause, sans les mots du symptôme** : l'éditeur du blog change le texte par script, longtemps après le geste de l'auteur, et Trix, à chaque rendu, remet son curseur dans la page sans vérifier où l'auteur écrit ; Chromium suit ce curseur avec le focus.

**Correctif** : à l'initialisation de Trix, en mode images, `keepFocus` enveloppe `SelectionManager#setLocationRange`. Quand l'auteur écrit dans un autre champ (ni le texte, ni sa barre d'outils, ni « Insérer une image »), Trix met à jour son curseur (`updateCurrentLocationRange`) sans le poser dans la page : l'image suivante va toujours au bon endroit, le focus ne bouge pas. Partout ailleurs, le comportement de Trix est inchangé. Les éditeurs des cours et des fiches, sans images, ne sont pas touchés.

**Pourquoi aucun test ne l'a vu** : le parcours A glisse l'image, puis attend la couverture avant de taper. Seul, la réduction est déjà finie quand il tape ; aucun test ne place le focus hors de l'éditeur **pendant** la réduction, ni ne vérifie le focus après une insertion asynchrone. Le test de reproduction se place donc au niveau système, dans ce même fichier, avec un ordre déterministe : dépôt, puis focus ailleurs une fois le dépôt traité par Trix, l'image encore en réduction (vérifié).

**Trou comblé** : `test/system/teams/blog_management_test.rb`, « an image entering the text once shrunk leaves the focus where the author is writing ». Rouge sans le correctif (`Expected: "article_cover_alt"`, `Actual: "article_body"`), vert avec, 3 fois sur 3. Il couvre aussi le cas symétrique : l'auteur qui écrit dans le texte y garde le focus et continue après l'image. Durée enregistrée : +1,6 s (`script/ci/test_timings.yml`, 13,8 → 15,4 s, budget du chantier `blog`).

**Effets de bord écartés** :
- Insertion suivante au bon endroit : le curseur de Trix est tenu à jour hors de la page (seconde image du test, après la première).
- Lien de la barre d'outils : son champ est dans `trix-toolbar`, exclu du garde ; Trix y garde sa sélection gelée comme avant.
- « Entrée » depuis un texte de remplacement (`image_alts_controller#backToEditor`) : donne le focus au texte **avant** de poser le curseur, donc hors du garde (parcours A, vert).
- Cours, fiches, catalogue, boucle pédagogique, CSP : leurs tests système, verts (17 tests, 582 assertions).

### Rejeu du challenger (2026-10-07)

Un agent distinct, sans avoir écrit le correctif, a rejoué le mémo dans le navigateur, avec un vrai clic et une vraie frappe. Il a aussi joué des témoins, garde retiré dans la page :
- couverture, titre, extrait pendant la réduction : focus et frappe gardés (3 sur 3) ; sans le garde, le bug revient. Il faut une image de 4000 × 3000 pour qu'un clic réel devance à coup sûr la réduction ;
- **pendant l'envoi** (6 s de latence réseau dans le navigateur) : focus gardé ; sans le garde, il saute à la fin de l'envoi. La fenêtre de l'envoi est donc couverte ;
- l'auteur qui écrit dans le texte, « Insérer une image », deux images d'un même dépôt : inchangés ;
- **écart corrigé** : un dépôt sans point dans le texte faisait partir l'image au début du texte (le garde gardait une position vide). Désormais ignoré, comme Trix le fait sans le garde.

Hors périmètre, vus avec et sans le garde : un dépôt sous la dernière image est placé avant elle par Chromium et Trix ; un espace tapé juste après une image qui finit son envoi donne parfois un saut de ligne en trop (« ￼ ↵après »).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Brouillons existants où du texte aurait atterri par erreur | Rien ne le distingue d'une saisie voulue ; l'auteur le voit dans l'éditeur avant d'enregistrer | — (dette assumée) |
| Espace tapé juste après une image qui finit son envoi : saut de ligne en trop, une fois sur trois | Existait avant (même fréquence sans le correctif) ; question de rendu de Trix, hors de ce bug | À ouvrir si l'équipe le voit |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-07 (PR vers `Develop`) |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
