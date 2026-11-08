# Journal — Médailles : vocabulaire et garde-fous

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-08 | Clés I18n gardées, valeurs changées ; `%{badge}` → `%{medal}` (3 vues, sans effet visible) | Le regex lit aussi les marqueurs ; renommer les clés toucherait les écrans | Non (UDR) |
| 2026-11-08 | `trophée` reste interdit dans le test I18n ; page design « Badges » → « Pastilles » | Le porteur n'a levé que « Médaille » | Non |
| 2026-11-08 | Pas de médaille de participation : tout exercice traité donne au moins Bronze ; « Pas encore » = rien fait (porteur, relayé par l'orchestrateur) | Question ouverte tranchée | Non (UDR) |
| 2026-11-08 | « Non acquis » → « Pas encore » (libellé de palier absent) | Libellé unique voulu par le porteur | Non |

## À trancher

- [ ] 2026-11-08 · medailles-vocabulaire · Remédiation « sous Bronze » : le code résout une lacune dès 75 % (`REMEDIATION_THRESHOLD`, 15/20) — appliqué : doc seulement, code inchangé ; autres : aligner le seuil sur Bronze dans un chantier code ; recommandé : décider au chantier élève

## Ce qui a dérapé

- Assets non compilés en début de session : `yarn build` et `yarn build:css` avant les tests de contrôleur.
