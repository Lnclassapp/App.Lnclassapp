# Journal — Entonnoir AARRR des élèves

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-16 | Pas d'ADR : une query de lecture de plus sous ADR-0049 / ADR-0062, définitions dans le PRD §3 | Ni port, ni table, ni dépendance, ni contrat modifié | Non |
| 2026-11-16 | Nouvelle query `StudentFunnelQuery` à côté de `GrowthMetricsQuery` (même contexte `identity`, même page), plutôt que d'alourdir sa `Row` | `GrowthMetricsQuery` a déjà 12 champs ; la page reste le toit commun | Non |
| 2026-11-16 | Seuil « réussi » calculé depuis `Grading.reaches?` et passé à la requête | Une seule règle de réussite (ADR-0106) | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.

- [ ] 2026-11-16 · entonnoir-aarrr · « Actif à Jn » : revenu à partir de J+n (non borné) ou actif le jour n pile ? — appliqué : non borné (seule la dernière date de lecture d'une notion est gardée, le « jour pile » sous-compterait) ; autres : jour pile sur les seules traces datées (sessions, réponses) ; fenêtre glissante J7–J13 ; recommandé : non borné
- [ ] 2026-11-16 · entonnoir-aarrr · La voie `code` (ancien code de classe, avant ADR-0085) compte-t-elle comme « amené par sa classe » ? — appliqué : oui (avec `link`) ; le brut garde `code` séparé ; autres : la compter à part à l'écran ; recommandé : oui
- [ ] 2026-11-16 · entonnoir-aarrr · **Décision non réversible (données)** : faut-il une table d'événements pour mesurer connexions, visites d'écran, temps passé, première ouverture de l'app, cours commencé/terminé ? — appliqué : rien, version sans table livrée, ces mesures sont listées « Non mesuré » à l'écran ; autres : une table `student_events` ajout seul (amende ADR-0049/0062, impose une durée de conservation et une base légale pour des mineurs) ; ne garder que l'historique des connexions réussies (`login_attempts` en a déjà les succès) ; recommandé : attendre la sortie de `entonnoir:brut` en production — si l'acquisition est le problème, aucune table n'est utile
- [ ] 2026-11-16 · #650 · **Sécurité, hors chantier, non tranché ici** : la garde `test_no_ignored_yarn_advisory_is_past_its_review_date` est rouge sur toutes les branches, `Develop` compris, depuis le 2026-11-16 (avis Yarn `1240992`, `braces`, réexamen prévu le 2026-11-15, chantier `audit-yarn-braces`). Elle rend rouge la ligne de preuve de `bin/ci-quiet` — appliqué : rien, le registre n'est pas modifié par ce chantier ; autres : repousser la date après réexamen, mettre à jour `braces` ; recommandé : réexamen par le chantier `audit-yarn-braces`, puis fusion de #650 sur une preuve où seule cette garde est rouge
- [ ] 2026-11-16 · entonnoir-aarrr · Un élève anonymisé sort-il de l'entonnoir ? — appliqué : oui (compte actif = non anonymisé, ADR-0062) ; autres : le garder dans « Inscrits » seulement ; recommandé : oui

## Suivi après fusion

- L'orchestrateur lance `bin/rails entonnoir:brut` en production ; la sortie dit si le problème est l'acquisition ou l'activation, et tranche le point « table d'événements » ci-dessus.

## Retouches

- …

## Ce qui a dérapé

- La section posée en `grid` faisait déborder la page à 390 px (largeur minimale auto d'un élément de grille + tableau `min-w`) : vu par le test système existant de la page, corrigé en pile `space-y-5`.
- Environnement cloud : Ruby 3.4.9 absent (compilé), chromedriver 147 du `PATH` incompatible avec Chrome 153 (retiré du `PATH`), locale US-ASCII qui casse `script/docs/build_index` (`LANG=C.UTF-8`).

## Revues du diff final (#650)

- Sécurité : rien de bloquant ; `statement_timeout` de 60 s ajouté à `entonnoir:brut` pour borner la charge en production.
- Tests : le scénario « reprises » ne distinguait pas `COUNT(DISTINCT)` de `COUNT` ; test dédié ajouté, mutation vérifiée tuée.
- Pannes silencieuses : première semaine tronquée affichée comme entière → marquée « partielle » ; abonnés anonymisés comptés → exclus.
- Les agents de revue du dépôt (`.claude/agents/`) n'étaient pas chargés dans la session cloud : joués par des agents généraux lisant leur définition.

## Ce qu'on a appris sur la codebase

- `joined_via` d'une adhésion est réécrit à `link` quand un élève retiré revient par le lien (ADR-0085) : la « première voie » est celle de la première adhésion, pas une donnée historique pure.
- `Grading.reaches?` arrondit sur la note sur 20 : le seuil « réussi » de 50 % est atteint dès 48 %.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Entonnoir par établissement / DRENA | Volumes trop faibles aujourd'hui | à ouvrir selon la sortie de `entonnoir:brut` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-16 (PR prête, fusion par l'orchestrateur) |
| **PR** | [#650](https://github.com/Lnclassapp/App.Lnclassapp/pull/650) |
| **ADR produits** | aucun |
| **UDR produits** | UDR-XXXX-entonnoir-aarrr |
