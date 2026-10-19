# Memo — La bulle « Badges » de la page de résultat sort de l'écran

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | décision |
| **Ouvert le** | 2026-10-19 |
| **Branche** | `fix/infobulle-badges-hors-ecran` |
| **Programme** | — |

---

## Symptôme

Sur ordinateur, à la souris, l'élève survole le « i » à côté du nom de son badge (« ARGENT ») sur la page de résultat d'une session. L'infobulle s'ouvre **en bas à droite de la page, loin de l'icône**, coupée par le bord droit de la fenêtre, et une barre de défilement horizontale apparaît. Attendu : la bulle juste sous l'icône, bord gauche aligné, contenue dans la fenêtre à 16 px des bords.

**Source du comportement attendu** : [UDR-0054, amendement du 2026-09-29 « survol »](../../decisions/udr/0054-finitions-d-interface.md#amendement-du-2026-09-29--textes-validés-ouverture-au-survol), « Panneau au survol : une bulle ».

## Reproduction

Constatée dans l'application en navigateur réel (Chromium 141, fenêtre 1400 × 1261), sur `Develop` (`fb846b9d`) comme sur `cf7b0730` :

1. Un élève a terminé une session avec un badge (ici 7/10, soit 14/20, badge Argent).
2. Il ouvre la page de résultat `exercise_session_result_path(session.public_id)` sur ordinateur.
3. Il pose la souris sur le « i » à côté de « ARGENT ».

Mesures en navigateur : icône à `left 582, bottom 337` ; bulle à `left 1090, top 526`, large de 448 px, qui finit donc à 1538 px dans une fenêtre de 1400 px. Attendu : `left 582, top 341`.

Captures : celles de la PR 263, `1-resultat-infobulle-badges-ordinateur.png` (envoyées au porteur, non commitées).

## Portée

- **Depuis quand** : depuis l'ouverture au survol en bulle fixe (UDR-0054, amendement du 2026-09-29). Le badge de la page de résultat avait déjà son animation d'entrée `animate-slide-up`.
- **Acteurs** : tout élève à la souris, sur la page de résultat, dès qu'il a un palier, ou « Pas encore de badge ». Au toucher, au clavier et au clic, l'infobulle s'ouvre dans le flux : rien ne change.
- **Même cause ailleurs** : toute infobulle placée dans un élément animé par `animate-slide-up`. Cela couvre les modales (`dialog` ouvertes avec `motion-safe:open:animate-slide-up`) et les toasts. Le tiroir « Mon compte » (`dialog.dialog-drawer`, animation `drawer-in`) a le même remplissage `both` sur un `transform`.
- **Données** : aucune. C'est un défaut d'affichage, sans rien en base.
- **Multi-appartenance** : sans objet, la page ne dépend que de la session.

## Hors périmètre

*Le tiroir `drawer-in` était d'abord hors périmètre ; le porteur l'a ajouté au correctif le 2026-10-19 (« ajoute dans ce correctif »).*

- Les textes des infobulles (UDR-0131, livrés par la PR 263).
- Le placement de la bulle quand elle est ouverte pendant les 0,3 s de l'animation : l'élève arrive sur la page, la bulle n'est pas encore sous sa souris.

## Portes de sortie (lot unique, plan dans `plan.md`)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit dans l'application (navigateur réel) avant toute ligne de code
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test (`journal.md`)
- [ ] Test de reproduction écrit **avant** le correctif
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : aucune (défaut d'affichage)
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
