# Plan d'exécution — La bulle « Badges » de la page de résultat sort de l'écran

Un seul lot. Le plan existe parce que le lot touche un fichier partagé : `app/assets/stylesheets/application.tailwind.css`.

## Lot 0 — Aucune animation d'entrée ne laisse de `transform` derrière elle

- **Couche**       : ui
- **Fichiers**     : `app/assets/stylesheets/application.tailwind.css` *(fichier partagé : jeton `--animate-slide-up` et règle `dialog.dialog-drawer[open]`)*
                     `test/system/assessment/session_result_test.rb`
                     `test/system/identity/account_panel_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/system/assessment/session_result_test.rb`. Sur ordinateur, au survol du « i » du badge, la bulle commence sous l'icône (`top` ≈ `bottom` de l'icône + 4 px) et son bord gauche est aligné sur l'icône. Elle reste dans la fenêtre à 16 px des bords. Mêmes mesures que le contrôleur (`GAP`, `GUTTER`).
                     `test/system/identity/account_panel_test.rb` : une fois le tiroir « Mon compte » ouvert et son animation finie, `getComputedStyle(dialog).transform` vaut `none`.
- **Done quand**   : sur la page de résultat, à la souris, la bulle « Badges » s'ouvre juste sous le « i » et ne fait plus défiler la page de côté ; le tiroir « Mon compte » ouvert ne garde aucun `transform`.

### Contrat d'exécution (ordre imposé)

1. Écrire les deux tests de reproduction : page de résultat et tiroir « Mon compte ».
2. Les lancer et les voir **échouer pour la bonne raison** :
   - la bulle est loin de l'icône (`left` ≈ 1090 contre 582 attendu) ;
   - le tiroir garde `matrix(1, 0, 0, 1, 0, 0)` au lieu de `none`.

   Un test vert du premier coup ne reproduit rien : on le réécrit.
3. Corriger à la cause : `--animate-slide-up` et l'animation de `dialog.dialog-drawer[open]` passent de `both` à `backwards`. L'animation part toujours de son état initial, et l'élément retrouve ensuite son propre style, sans `transform`.
4. Relancer : vert.
5. Relancer `test/system/assessment/`, `test/system/identity/` et `test/system/design_system_test.rb`. Puis `bin/ci-quiet` complet.

### Cas symétrique à vérifier

- L'animation d'entrée du badge, des modales, des toasts et du tiroir se joue toujours : opacité et glissement, sans saut à la fin.
- La bulle au survol de la page du design system et l'infobulle au clic (dans le flux) ne changent pas.
- À 390 px, au toucher, l'infobulle du badge s'ouvre toujours dans le flux.

### Challenger (phase 5)

Rejouer la reproduction du memo dans l'application, à la souris sur ordinateur, avec capture. Puis le cas symétrique : une modale qui s'ouvre et un toast, avec leur animation.
