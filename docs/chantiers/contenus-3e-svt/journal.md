# Journal — Les 10 premières leçons de SVT de 3ème et leurs planches

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Lot P : le contexte de dessin passé à `draw` ajoute à `{ highlighted, el }` les aides `part`, `tube`, `sketch`, `pattern`, `uid`, `defs`, `label` ; `fill: "ghost"` pour une zone superposée à un dessin | Les 8 planches partagent surlignage, motifs et identifiants uniques sans importer `plate.js` ; la vague 4 n'a rien à changer dans `plate.js` | Non (détail d'UDR §3 plate) |
| 2026-10-30 | Rédaction des 10 leçons avant la fusion de la vague 2, aux formes de l'ADR, contrôlées à la main pour les sortes nouvelles | Ne pas attendre la vague 2 ; le contrôle final a tout confirmé sans retouche | Non |
| 2026-10-30 | Jachère et rotation des cultures rangées en leçon 10 (protection des sols), retirées de la leçon 9 | La relecture les voyait dans les deux ; une notion appartient à une seule leçon | Non |
| 2026-10-30 | Après revues : une étiquette de planche n'admet que `part` et `text` (domaine et navigateur) ; texte compté en points de code côté navigateur | Une faute de frappe (`texte`) faisait perdre le texte en silence | Non |
| 2026-10-30 | Lot D : `plate` exige `plate`, `labels` (non vide) et `numbering`, comme `diagram` exige `nodes` ; `figure_kinds.rb` charge `figure_catalogs` lui-même (l'enum des planches lit `PLATES` au chargement, hors Zeitwerk pour `valider.rb`) ; `item_range` (0..1) car aucun élément de `plate` ne porte de nombre | Cohérence avec la vague 2 ; une planche sans étiquette n'a pas de sens | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Relecture IA indépendante : aucune erreur scientifique bloquante, mais des confusions classiques (amylase → glucose au lieu de maltose, pepsine → acides aminés, terre calcinée non séchée, sang « apporté » par le sol dans une expérience où tout est arrosé) et des barèmes qui ne collent pas aux critères ; à garder dans la grille de relecture des vagues suivantes.
- Les questions de légende dépendent de l'ordre de `labels` en `numbers` : plusieurs rédacteurs n'ont pas pu le voir rendu ; vérifié par la relecture et le challenger.
- Courbe : un libellé d'abscisse long (« 5 min après l'arrêt ») est coupé à 390 px ; raccourci dans la leçon (la courbe vient de la vague 2).
- Les tests système demandent `yarn build` et `yarn build:css` sur un poste neuf (`application.css` introuvable sinon).

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `valider.rb` charge le domaine hors Zeitwerk : une constante lue au chargement (l'enum des planches) impose un `require_relative` explicite.
- Le contrôleur de figures attend désormais `create` (asynchrone depuis la vague 2) : un module synchrone comme `plate.js` marche tel quel.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Relecture des 8 planches par un enseignant de SVT (captures envoyées au porteur) | Hors de portée d'un agent | — (avant publication) |
| Points « à faire valider par un enseignant » des 10 leçons (vocabulaire du programme, valeurs illustratives) | Programme officiel non accessible ici | — (avant publication) |
| Libellés longs d'abscisse d'une courbe coupés à 390 px | Code de la vague 2 ; contourné dans la leçon | à signaler à la vague 2 / train |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 (PR prête, fusion par l'orchestrateur) |
| **PR** | PR unique de `feature/contenus-3e-svt` vers `Develop` |
| **ADR produits** | aucun (ADR-0117 du programme, §4.2 `plate`) |
| **UDR produits** | aucune (UDR-0142 du programme, §3 `plate`) |
