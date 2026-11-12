# État — ci-lecons-rendu

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-12 · **Vague** : trains #541, #545, #549, #553 vers Staging · **Où on en est** : #553 a touché aux écrans (rendu complet) et une part a atteint 288 s : le porteur a décidé de ne rendre que 5 leçons au plus, tirées au hasard, en 1 part (PR `perf/ci-lecons-5-au-hasard`). Le chantier attend la mesure du prochain train pour se clore.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| Correctif 24 → 32 parts | orchestrateur | `ci/lecons-32-parts` | #542 | `75dd25d4` | fusionné |
| A — leçons changées ou 2 témoins, ⌈N/10⌉ | orchestrateur (executant-lot) | `perf/ci-lecons-rendu` | #543 | `93066d05` | fusionné |
| B — rendu complet si écrans touchés | orchestrateur (executant-lot) | `perf/ci-lecons-rendu-ecrans` | #544 | `5f9ac93b` | fusionné |
| ADR-0131 numéroté | orchestrateur | commit direct Develop | — | `bd1d61bd` | fusionné |
| 8 leçons par part | orchestrateur | `perf/ci-lecons-8-parts` | #546 | `ff8d3b01` | fusionné |
| 5 leçons au plus, au hasard, 1 part (seuil 280 s franchi au #553) | orchestrateur | `perf/ci-lecons-5-au-hasard` | voir GitHub | — | ouverte |

Hors chantier, même session :

| Sujet | PR | État |
|---|---|---|
| Numéros d'ADR / UDR dans les vues | #540 | fusionné (Develop) |
| Modale annulée juste après une fermeture (`modal_controller.js`) — chantier `assignation-catalogue-modale-jours` | #548 | fusionné (Develop) |
| Accueil : version unique, photo éclaircie, macaron étoilé — chantier `page-d-accueil-photo` | #547 | fusionné (Develop) |
| Trains vers Staging | #541, #545, #549, #553 | fusionnés ; promotion vers main #554 |

## Décisions

Prises :

- 2026-11-12 · Le train ne rend que les leçons nouvelles ou modifiées ; sinon 2 témoins (`script/ci/lecons_temoins.txt`) — par le porteur.
- 2026-11-12 · Rendu complet seulement quand le train touche aux écrans ; pas de rendu hebdomadaire — par le porteur.
- 2026-11-12 · 10 puis 8 leçons par part (#545 : 283 s au plus ; #549 : 269 s) — par le porteur.
- 2026-11-12 · 5 leçons au plus, tirées au hasard, en 1 part, dans tous les cas (y compris écrans touchés) ; #553 avait 3 parts au-delà de 280 s — par le porteur.
- 2026-11-12 · Macaron de l'accueil en bleu clair malgré un contraste de 2,8:1 — par le porteur (journal de `page-d-accueil-photo`).

Ouvertes : `script/docs/a_trancher`, et les sections `## À trancher` des journaux des chantiers de la vague. Le seuil des 280 s ne s'applique plus (une part de 5 leçons ≈ 150 s).

## Prochaine action

1. Fusionner la PR `perf/ci-lecons-5-au-hasard` vers Develop (preuve `bin/ci-quiet` écrite dedans).
2. Au prochain train vers Staging : relever les check runs `lecons *` (protocole du memo), compléter « Mesure après ». Attendu dans tous les cas : 1 part, ≤ 3 min.
3. Mesure relevée : clore le chantier (statut « livré », portes de sortie du plan cochées, journal : leviers abandonnés).

## Prompt de reprise

```
Orchestrateur de ci-lecons-rendu. Lis docs/chantiers/ci-lecons-rendu/etat.md, vérifie sur GitHub les PR qu'il cite, puis : au prochain train Develop → Staging, relève la mesure des tâches lecons (memo, « Mesure après »), repasse à 6 leçons par part si une part dépasse 280 s, et clos le chantier. Réponses en français, courtes ; jamais de fusion vers Staging sans l'accord explicite du porteur.
```
