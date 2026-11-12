# Journal — L'élève sans enseignant a quelque chose à faire dès l'accueil

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-12 | Le dernier niveau connu sert aussi au catalogue et aux sessions, pas seulement à l'accueil | Sinon les matières de la grille mènent à des pages introuvables | oui, ADR-0035 (amendement) |
| 2026-11-12 | Consigne du porteur en cours de session : « Mes matières » titrée partout, annonces même sans classe, « À faire » revient sur l'accueil | Message du porteur | non (UDR-0132, amendement) |
| 2026-11-12 | L'exercice du jour lit le niveau par la query de niveau : deux requêtes au lieu d'une | Une seule règle de niveau ; le nombre de requêtes reste fixe | non |

## À trancher

- [x] 2026-11-12 · eleve-sans-prof · Un élève qui n'a jamais eu de classe (compte importé) : que lui montrer ? — appliqué : rien de plus que « Choisis ta classe » ; autres : les matières de tous les niveaux, lui demander son niveau ; recommandé : rien de plus (l'inscription met toujours l'élève dans une classe) → **tranché le 2026-11-12 : option appliquée conservée**
- [x] 2026-11-12 · eleve-sans-prof · Un niveau sans leçon publiée (6e, 5e, 4e, 2nde ; 1ère hors production) : que proposer ? — appliqué : la phrase « Les cours de ton niveau arrivent bientôt. » ; autres : proposer les leçons du niveau voisin qui en a (ouvre la lecture hors niveau : décision de droits), masquer la grille ; recommandé : la phrase, et prioriser les contenus de ces niveaux → **tranché le 2026-11-12 : option appliquée conservée**
- [x] 2026-11-12 · eleve-sans-prof · Sans classe, l'exercice du jour est un bloc secondaire sous « Rejoindre » — appliqué : « Rejoindre » reste le bouton principal ; autres : l'exercice du jour en bouton principal et le code en dessous ; recommandé : appliqué (rejoindre sa classe reste la tâche de l'écran) → **tranché le 2026-11-12 : option appliquée conservée**
- [x] 2026-11-12 · eleve-sans-prof · « À faire » reprend-il l'exercice déjà montré dans la carte ? — appliqué : non, il commence au suivant (charte : dire chaque chose une fois) ; autres : la liste complète ; recommandé : appliqué → **tranché le 2026-11-12 : option appliquée conservée**
- [x] 2026-11-12 · eleve-sans-prof · « Mes matières » sur téléphone : titre visible — appliqué : oui, à toutes les tailles ; autres : titre seulement sur ordinateur (avant) ; recommandé : appliqué → **tranché le 2026-11-12 : option appliquée conservée**

## Ce qui a dérapé

- Première reproduction faussée : la query de l'accueil garde le niveau en mémoire par instance, et le script la réutilisait pour tous les élèves. Une instance par élève, comme le contrôleur, donne les vrais chiffres.

## Ce qu'on a appris sur la codebase

- L'accueil, l'exercice du jour et le catalogue lisent le niveau de l'élève par la même query de niveau ; l'exercice du jour la recopiait en SQL corrélé. Elle l'utilise maintenant directement.
- Le jeu standard local ne publie que des cours de 3e et de Tle : les classes des autres niveaux ont un accueil vide, quel que soit l'enseignant.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Leçons des niveaux 6e, 5e, 4e et 2nde | Contenu, pas code | chantiers `contenus-*` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-12, en production le jour même (train #553, promotion #554) |
| **PR** | #552 |
| **ADR produits** | ADR-0035, amendement du 2026-11-12 |
| **UDR produits** | UDR-0132, amendement du 2026-11-12 |
