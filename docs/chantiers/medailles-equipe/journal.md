# Journal — Médailles : écrans de l'équipe

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-09 | Médailles décernées = `exercise_badges` de la période (palier du moment, une par élève et exercice) | Médaille lue en base, sans recalcul ni moyenne ; même source que `Queries::Assessment::Medals` | Non |
| 2026-11-09 | « Barème des classes » → « Plan des classes », libellés seuls | Libère « barème » pour les seuils de médaille | Non (UDR médailles) |

## À trancher

- [ ] 2026-11-09 · medailles-equipe · Une médaille qui monte (Argent → Or) réécrit `awarded_at` : le Pilotage la compte à son palier du moment, pas deux fois — appliqué : palier du moment ; autres : compter les médailles par session terminée ; recommandé : appliqué
- [ ] 2026-11-09 · medailles-equipe · Pilotage « Par DRENA » / « Par établissement » : colonne « Élèves médaillés » proposée par l'audit (option) — appliqué : non ajoutée (pas de besoin exprimé) ; autres : l'ajouter ; recommandé : non
- [ ] 2026-11-09 · medailles-equipe · Allègement du Pilotage (E-003) et de la fiche établissement (E-004, ≈ 13 500 px sur téléphone) — appliqué : non touchés, la fiche n'affiche aucune note ; autres : repli des sections ; recommandé : chantier propre (L)
- [ ] 2026-11-09 · medailles-equipe · Page publique de confidentialité (« exercices faits, réponses, notes »), hors /teams — appliqué : inchangée ; autres : « médailles » ; recommandé : à voir avec le texte juridique
- [ ] 2026-11-09 · medailles-equipe · Le partial `teams/answer_keys/_practice` (« Je m'entraîne (sans médaille) ») n'est rendu par aucune vue (Lot C du corrigé non fait) — appliqué : libellé mis à jour, non visible ; autres : aucune ; recommandé : appliqué

## Ce qui a dérapé

- Assets non compilés en début de session : `yarn build` et `yarn build:css`.
