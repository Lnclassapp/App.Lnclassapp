# Journal — Accueil élève : le QR en grand, avec le partage WhatsApp

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-24 | Plein écran sous 700 px (palier du téléphone), pas sous lg | « sur mobile » pour le porteur ; la tablette reçoit la fenêtre, comme « Plus » (`:phone_sheet`) | non |

## À trancher

> Format : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-24 · accueil-eleve-qr-agrandi · Palier du plein écran — appliqué : sous 700 px (téléphone) ; autres : sous lg (1024 px, tablette comprise, consigne de l'orchestrateur) ; recommandé : 700 px
- [ ] 2026-11-24 · accueil-eleve-qr-agrandi · Place de la croix — appliqué : à droite, comme toutes les fenêtres du projet ; autres : à gauche, comme Wave ; recommandé : à droite
- [ ] 2026-11-24 · accueil-eleve-qr-agrandi · Contrôle segmenté de Wave (« Scanner un code | Ma carte ») — appliqué : absent, faute de scanner ; autres : le reprendre quand un scanner existera ; recommandé : absent
- [ ] 2026-11-24 · accueil-eleve-qr-agrandi · Thème sombre : le panneau du QR suit la surface sombre, le QR garde son fond blanc — appliqué : comme le petit QR de la carte ; autres : panneau blanc dans les deux thèmes ; recommandé : comme le petit QR

## Retouches

- …

## Ce qui a dérapé

- La mesure de la fenêtre au test système tombait pendant son animation d'entrée (y = 6) : on attend la fin des animations avant de mesurer.

## Ce qu'on a appris sur la codebase

- `modal#backdrop` ferme sur un clic qui tombe sur la `<dialog>` elle-même : en plein écran, centrer le corps laisse ce vide cliquable sans JavaScript de plus.
