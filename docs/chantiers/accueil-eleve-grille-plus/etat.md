# État — accueil-eleve-grille-plus

> Tenu par l'orchestrateur ([`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md)). Mis à jour une fois, en fin de session ; toute session d'orchestration commence par le lire. Ni secret, ni identifiant.

**Mis à jour le** : 2026-11-24 · **Vague** : 1 · **Où on en est** : lots 0, A, B faits sur une branche ; PR vers `Develop` ouverte, non fusionnée (CI locale rouge pour l'environnement : audit puma déjà sur Develop). Préalable : #688 fusionnée avant.

## Lots

| Lot | Session | Branche | PR | SHA de tête vérifié | État |
|---|---|---|---|---|---|
| 0 — socle | executant-lot | `feature/accueil-eleve-grille-plus` | voir PR | | fait (`7ca440a4`) |
| A — téléphone | executant-lot | `feature/accueil-eleve-grille-plus` | voir PR | | fait (`4e605d61`) |
| B — ordinateur | executant-lot | `feature/accueil-eleve-grille-plus` | voir PR | | fait (`af9cb824`) |

## Décisions

Prises :

- 2026-11-24 · « Inviter » et « Plus » complètent la grille à 8 cases ; « Plus » ouvre une feuille basse de 25 % ; pas de « Plus » sur ordinateur — par le porteur
- 2026-11-24 · Contenu de « Plus » : S'abonner, Salle d'étude, Littera, Composa, Devoirs CI ; 4 par rangée ; icônes seulement — par le porteur
- 2026-11-24 · Entrée sans écran : message « Bientôt disponible » — par le porteur
- 2026-11-24 · Sur ordinateur, les entrées vont dans le menu de gauche — par le porteur
- 2026-11-24 · Élève sans classe : matières + « Plus », sans « Inviter » — par le porteur

- 2026-11-24 · « S'abonner » dit « Bientôt disponible » tant que la bêta est ouverte (UDR-0169) — option prudente, à confirmer

Ouvertes : `## À trancher` du journal.
