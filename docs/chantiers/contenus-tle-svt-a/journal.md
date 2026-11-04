# Journal — Les 7 leçons de SVT de Terminale A1 et A2

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | Leçons écrites dans `tle-a1/`, copiées dans `tle-a2/` avec la seule `series_name` changée (même rang, même `subtitle`) | Progressions A1 et A2 identiques | Non |
| 2026-10-31 | Notions au rattachement incertain non écrites (L1 : système sympathique / parasympathique, hypothalamus, amygdale, cortisol ; L2 : hippocampe ; L6 : diagnostic prénatal, probabilité conditionnelle 2/3 ; L5 : compatibilité transfusionnelle) | Règle « une notion fausse ou hors programme est pire qu'une notion absente » ; la relecture de L1 juge l'omission juste en série A | Non (points enseignant) |
| 2026-10-31 | Notation des génotypes `A//O`, `X//Y`, Rhésus `R`/`r`, phénotypes entre crochets ; drépanocytose `A`/`S` ; une seule notation de L5 à L7 | Cohérence entre leçons communes à la série | Non (point enseignant) |
| 2026-10-31 | Frises en millions ou milliards d'années remplacées par du texte, une `stat_chart` ou une question d'échelle | `timeline` ne couvre que −3000 à 2100 | Non (besoin signalé) |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Recopies entre fiche, exercice noté et entraînement** dans les 7 leçons : l'exercice reprend l'exemple corrigé ou le contre-exemple du piège, l'entraînement reprend l'exercice noté avec d'autres mots. Le contrôle mécanique ne voit que les énoncés identiques. C'est le défaut le plus fréquent des relectures : il faut l'ajouter au brief de rédaction.
- **Erreurs de fond trouvées seulement en relecture** : addition fausse (L5, 36 au lieu de 38) ; Lucy présentée comme le début de la lignée alors que Toumaï est enseigné juste après, et peintures à 300 000 ans (L4) ; expérience à deux facteurs présentée comme à un seul facteur (L3) ; aires de la vue et de l'ouïe rangées parmi les aires sensitives (L2) ; probabilité écrite comme une proportion certaine (L6) ; mutation de deux bases dans une méthode qui en repère une (L7). La relecture indépendante (Opus) reste indispensable.
- **Limite de 3 sous-agents dépassée une fois** (4 en même temps) : la reprise d'un auteur pour corrections compte comme un sous-agent actif.

## Ce qu'on a appris sur la codebase

- `timeline` est bornée à −3000..2100 : aucune frise des temps géologiques ni de la préhistoire.
- `unit` ne dépasse pas 10 caractères (« milliards d'années » refusé).
- `duplicate_accepted` ignore aussi la casse (« A » et « a » sont un doublon).
- Un `matching` dont la colonne de gauche porte des formules de génotypes proches est refusé (`duplicate_left`, `duplicate_match`) : écrire les côtés en mots.
- `valider.rb` ne contrôle pas `practice` ; le contrôle de l'entraînement (règles du test 3e) a été joué à part avec `NotionPractice.errors_for`, par `bin/rails runner`.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points « à faire valider par un enseignant » (journal du programme, vague T5) | Programme officiel détaillé non accessible ici | — (avant publication) |
| Planches manquantes : cerveau (lobes, aires), système nerveux et surrénales, caryotype, cellule (noyau, ribosomes), double hélice d'ADN, hématies normales et falciformes, crânes et squelettes Homme / chimpanzé | Aucune sorte nouvelle dans ce chantier (hors périmètre) | à proposer au programme |
| Frise en millions d'années, tracé d'EEG, hypnogramme, arbre généalogique (deux parents), échiquier de croisement, courbe à deux séries | Code des figures | à proposer au programme |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-31 (PR prête, fusion par l'orchestrateur) |
| **PR** | `feature/contenus-tle-svt-a` vers `Develop` |
| **ADR produits** | aucun (ADR-0116, ADR-0117 du programme) |
| **UDR produits** | aucune (UDR-0142, UDR-0147 du programme) |
