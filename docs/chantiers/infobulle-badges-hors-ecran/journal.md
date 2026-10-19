# Journal — La bulle « Badges » de la page de résultat sort de l'écran

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-19 | Corriger le jeton d'animation `--animate-slide-up` (remplissage `both` → `backwards`), pas le contrôleur `info-tip` ni la vue du badge | C'est là que vit la cause. Un contrôleur qui compenserait le repère, ou une vue sans animation, laisserait le piège pour toute autre infobulle dans un élément animé | Non (pas architectural) |
| 2026-10-19 | `drawer-in` (tiroir « Mon compte ») corrigé dans le même lot : `both` → `backwards` | Décision du porteur (« ajoute dans ce correctif ») : même cause, même ligne de correctif ; sans infobulle dans le tiroir aujourd'hui, le test vérifie qu'aucun `transform` ne reste après l'ouverture | Non |
| 2026-10-19 | Pas d'UDR | La correction rend le comportement déjà décrit par UDR-0054, amendement « survol » | — |

## Ce qui a dérapé

- …

## Ce qu'on a appris sur la codebase

### Rapport root cause

**Chaîne d'appels.**
1. `app/views/assessment/session_results/show.html.erb` rend `_badge.html.erb`.
2. `#session_badge` porte la classe `animate-slide-up` (`app/views/assessment/session_results/_badge.html.erb:8`).
3. L'infobulle `ui_info_tip badges_tip` (`components/_info_tip.html.erb`) est rendue dans ce bloc.
4. Au survol, le contrôleur `info-tip` (`app/javascript/controllers/info_tip_controller.js`, `enter` puis `place`) pose `data-floating`, donc `position: fixed`, et écrit `left` et `top` en **coordonnées de la fenêtre**.

**Cause** : `app/assets/stylesheets/application.tailwind.css:118`.

```css
--animate-slide-up: slide-up 0.3s cubic-bezier(0.16, 1, 0.3, 1) both;
```

- Le remplissage `both` garde l'état final de `@keyframes slide-up` après l'animation, donc `transform: translateY(0)`.
- Mesuré en navigateur, `getComputedStyle(#session_badge).transform` vaut `matrix(1, 0, 0, 1, 0, 0)` bien après la fin.
- Or tout `transform` autre que `none` fait de l'élément le **bloc conteneur** de ses descendants en `position: fixed` (spécification CSS Transforms).
- Les `left` et `top` du contrôleur, calculés pour la fenêtre, s'ajoutent donc à la position du bloc du badge. La bulle est décalée d'autant : `left` 1090 au lieu de 582.

**La cause sans les mots du symptôme** : une animation d'entrée qui garde son état final laisse un `transform` permanent sur son élément. Ce `transform` change le repère de tout descendant en position fixe.

**Pourquoi aucun test ne l'a vu.**
- Le seul test de la bulle au survol (`test/system/design_system_test.rb`, « an info tip opens on mouse hover… ») tourne sur la page du design system. L'exemple n'y a aucun ancêtre transformé. Le test vérifie `position: fixed` et que l'icône ne bouge pas, jamais **où** est la bulle.
- Les tests des pages (`finitions/catalog_and_student_test.rb`, `narrow_screens_test.rb`) ouvrent l'infobulle **au clic**, donc dans le flux, où le bloc conteneur ne joue pas.

Le test de reproduction se place donc dans le test système de la page de résultat (`test/system/assessment/session_result_test.rb`). Il ouvre au survol et vérifie la position de la bulle par rapport à l'icône et à la fenêtre.

### Même cause dans le tiroir

- `dialog.dialog-drawer[open]` (même fichier, `animation: drawer-in … both`) garde aussi `transform: translateX(0)` après l'ouverture.
- Toute infobulle future du tiroir « Mon compte » (`shared/navigation/_account_panel.html.erb`) serait décalée de la même façon.
- Corrigé dans ce lot, sur décision du porteur.

### Trou de test comblé

- `test/system/assessment/session_result_test.rb` : sur ordinateur, au survol du « i » de `#session_badge`, la bulle a son `left` sur l'icône (à 1 px), son `top` à `bottom` + 4 px, et finit à 16 px au plus du bord droit. Avant correctif : `left` 1070 contre 562 (écart 507,8 px).
- `test/system/identity/account_panel_test.rb` : tiroir « Mon compte » ouvert et animation finie, `getComputedStyle(dialog).transform` vaut `none`. Avant correctif : `matrix(1, 0, 0, 1, 0, 0)`.
- Correctif : `both` devient `backwards` pour `--animate-slide-up` et `dialog.dialog-drawer[open]`, sans toucher au contrôleur ni aux vues.
- Effets de bord écartés : `test/system/assessment/`, `test/system/identity/` et `test/system/design_system_test.rb` verts (114 runs, 0 échec). Les animations n'ont pas de délai : le remplissage `backwards` ne change que l'état après la fin, l'élément retrouve son style propre. Reste au challenger (phase 5) : le coup d'œil sur l'animation d'entrée (modale, toast, tiroir) dans l'application.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | — |
| **UDR produits** | — |
