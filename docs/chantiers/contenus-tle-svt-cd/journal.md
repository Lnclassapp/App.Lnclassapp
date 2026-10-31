# Journal — Les 10 premières leçons de SVT de Terminale C et D

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | 38 ATP par glucose pour la respiration, dans C3 et C4 (rendement ≈ 40 %) | C3 disait 36, C4 calculait avec 38 ; une seule valeur dans la série | Non (point à faire valider) |
| 2026-10-31 | Courbes de potentiel décalées de +100 mV, le décalage écrit dans la description et l'énoncé | `stat_chart` refuse les valeurs négatives | Non (besoin signalé) |
| 2026-10-31 | Données expérimentales inventées marquées « résultats simplifiés » ou « expérience fictive », jamais attribuées à un organisme réel | Relectures C8, D6 : valeurs plausibles lues comme réelles | Non |
| 2026-10-31 | Deux PR : Tle C (lot C) puis Tle D (lot D) | Limite d'usage atteinte en cours de lot D ; consigne de l'orchestrateur | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Corrections qui renvoient à une position** (« la première proposition », « les deux premières ») dans C2, C6, C8, D1, D2 : bloquant, car l'application mélange les propositions. Règle ajoutée aux briefs de rédaction et de relecture dès la 2e leçon ; il a fallu la vérifier quand même à chaque relecture.
- **Erreurs scientifiques trouvées seulement en relecture** : 36 / 38 ATP entre C3 et C4 ; racine dorsale « non motrice » par un raisonnement faux (C7) ; blastocyste qui « entre dans l'utérus » (D1) ; seuil du diabète à 1 g/L (D6) ; gènes ebony et vestigial de la drosophile présentés comme liés (D5). La relecture indépendante (Opus) est indispensable.
- **Fichiers temporaires partagés** : deux relecteurs parallèles écrivaient `flat.txt` dans le même dossier et ont lu la mauvaise leçon. Règle : préfixer par le code de la leçon.
- **Rapports d'auteur non fiables** : un rédacteur a rendu « placeholder », un autre a reconnu ne pas avoir refait ses calculs. Toujours relire.
- **Redémarrage du conteneur, puis limite d'usage** pendant le lot D : agents repris par message ; le lot C, déjà commité, a été poussé aussitôt. Un correcteur interrompu n'avait rien écrit : vérifier le fichier (grep d'une formule attendue) avant de croire une correction faite.
- **Leçon D10 trop proche de C7** : deux énoncés recopiés mot pour mot malgré la consigne « ne la recopie pas » ; trouvé en relecture, réécrits.
- **Geste volontaire présenté comme réflexe médullaire** (D10, relais) et dressage présenté comme réflexe conditionnel (D9) : les situations de la vie courante doivent être choisies pour la notion, pas l'inverse.

## Ce qu'on a appris sur la codebase

- `valider.rb` refuse « u.a. » dans `unit` (`unit_invalid`) : écrire « ua » ou rien.
- `duplicate_accepted` compare les variantes acceptées sans accents : « ovocyte » et « ovocyté » sont un doublon.
- `hint` et `blank` ne sont admis que dans `practice`.
- Une `stat_chart` ne porte qu'une série et des valeurs de 0 à 1 000 000 ; un `diagram` en arbre n'a qu'un parent par nœud (pas d'arbre généalogique).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points « à faire valider par un enseignant » (journal du programme, vague T4) | Programme officiel détaillé non accessible ici | — (avant publication) |
| Planches manquantes : neurone, synapse, plaque motrice, sarcomère, mitochondrie, anticorps, cycle du VIH, coupe d'ovaire, testicule, fleur, coupe géologique et piège pétrolier, coupe sismique, gamètes et segmentation | Aucune sorte nouvelle dans ce chantier (hors périmètre) | à proposer au programme |
| Courbe à valeurs négatives, courbe à plusieurs séries, arbre généalogique (deux parents) | Code des figures | à proposer au programme |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-31 (PR prêtes, fusion par l'orchestrateur) |
| **PR** | #421 (Tle C, `feature/contenus-tle-svt-cd`) · Tle D (`feature/contenus-tle-svt-d`), toutes deux vers `Develop` |
| **ADR produits** | aucun (ADR-0116, ADR-0117 du programme) |
| **UDR produits** | aucune (UDR-0142, UDR-0147 du programme) |
