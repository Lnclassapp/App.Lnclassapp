# Journal — medailles-enseignant

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-09 | Les chiffres quittent les vues, pas les queries (champs `grade`, `best`, `score_percent` gardés dans les DTO) | Chiffres conservés en base ; autres lecteurs (direction, équipe) | Non |
| 2026-11-09 | Page de résultat vue par l'enseignant ou l'équipe : médaille et « x sur y justes » seulement (plus de note, score, maîtrise) | Médaille seule partout où l'enseignant lit | UDR médailles enseignant |
| 2026-11-09 | Historique d'accueil : répartition de médailles du devoir (`Medals.distribution_by_assignment`), élèves présents seulement | Règle de classe par exercice | UDR médailles enseignant |

## À trancher

- [x] 2026-11-09 · medailles-enseignant · Remédiation : seuil du code (75 %) inchangé, comme `medailles-eleve` — appliqué : inchangé ; autres : l'aligner sur l'Argent (68 %) ; recommandé : Argent, dans un chantier code (voir `medailles-eleve`) — réponse du porteur (2026-11-09) : Bronze et Argent sont en remédiation, levée à l'Or ; fait dans `seuil-remediation`
- [ ] 2026-11-09 · medailles-enseignant · Barème « N points » sur la feuille de sujet vue par l'enseignant — appliqué : inchangé (hors écrans listés) ; autres : le retirer ; recommandé : le retirer dans le chantier qui touche la feuille
- [ ] 2026-11-09 · medailles-enseignant · Points pondérés (« 6 points sur 11 ») sur la page de résultat vue par l'enseignant — appliqué : gardés (compte de points, hors des écrans listés) ; autres : les retirer comme pour l'élève ; recommandé : les retirer
- [ ] 2026-11-09 · medailles-enseignant · « Fait seul (7 j) » quitte la liste de classe (E-002) mais reste sur la fiche élève — appliqué : retiré de la liste ; autres : le garder en compteur discret ; recommandé : appliqué

- [ ] 2026-11-09 · medailles-enseignant · Une médaille montée hors du devoir (fait seul, autre classe) rend « Pas encore » à la liste, à la fiche et à la répartition (réécriture de `exercise_session_id`) ; la note qui trahissait l'écart a disparu des vues — appliqué : inchangé, comme `medailles-grading-bronze` ; autres : calculer la médaille du devoir depuis la meilleure session de l'assignation (`Grading.session_medal`) ; recommandé : cette option, dans un chantier code (reprend l'entrée #526 de `medailles-grading-bronze`)
- [ ] 2026-11-09 · medailles-enseignant · Historique d'accueil : une copie vide rendue ne montre aucune pastille (« 3 / 3 faits » sans médaille) — appliqué : rien ; autres : « Pas encore ×N » ; recommandé : appliqué

## Retouches

- …

## Ce qui a dérapé

- `test/system/classroom/classroom_essential_test.rb:57` (toast « Jours de séance enregistrés ») échoue aussi sans ce chantier ; non traité.
- 9 tests système élève cherchaient encore `#session_grade` (retiré par `medailles-eleve`) : alignés sur `#session_badge`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Aides `mastery_label` / `mastery_tip` (« Acquis / Fragile ») sans plus aucune vue | Hors périmètre, tests propres | `retouche` de nettoyage |
| Menu « Gérer la classe » (lien d'inscription, jours de séance), fiches à revoir en compteur (E-002) | Mise en page de la page, pas une mesure | `retouche` ou `feature` dédiée |
