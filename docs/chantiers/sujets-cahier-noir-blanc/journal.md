# Journal — Les sujets d'interrogation en cahier noir et blanc

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-05 | Papier cahier `#fbf6e9` à lignes Seyès grises (et non feuille blanche), même gabarit pour `.ps-sheet` (Prépare interros, devoirs, devoir reçu) | Décision du porteur (2026-11-05) : pas de maquette par sujet ; le tableau de l'issue et l'exemple Thalès sont un gabarit générique pour tous les sujets d'interrogation et de devoir, toutes matières. | non, UDR |
| 2026-11-05 | `--color-white` et `--color-paper` valent le papier dans `.exam-sheet` ; `--color-band-ink` vaut `#fff` (le bouton « brand » est texte `ink` sur fond `brand`, deux fois `#1a1a1a`) ; les cartes sont transparentes pour que les lignes passent | une seule feuille, des lignes jamais coupées par une carte | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [x] 2026-11-05 · sujets-cahier-noir-blanc · La demande de confirmation quand des questions sont vides (UDR-0087 §3.2) reste-t-elle ? — appliqué : oui, ce n'est pas une seconde confirmation systématique ; autres : la retirer ; recommandé : la garder
  - Porteur, 2026-11-06 : on la garde (option recommandée).
- [x] 2026-11-05 · sujets-cahier-noir-blanc · Matière et classe dans le cartouche (« MATHÉMATIQUES », « Classe de 3e ») ? — appliqué : non, la copie ne lit pas ces données ; autres : les ajouter à la lecture de la copie ; recommandé : un petit chantier de suivi
  - Porteur, 2026-11-06 : un petit chantier de suivi (option recommandée), à ouvrir par `/feature` ; rien n'est fait ici.

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
