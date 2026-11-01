# Journal — Les 10 premières leçons de SVT de 1ère C et D

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-01 | Rédaction Sonnet, relecture indépendante Opus, 3 sous-agents au plus | Consigne du porteur (prompt de vague) | Non |

## Ce qui a dérapé

- **Erreurs de fond trouvées seulement en relecture Opus** : « un seul nucléotide change » entre GGG et GCU (C5) ; vitesses de 5 cm/an irréalistes pour l'Atlantique et inversion datée de 400 000 ans (C8) ; ovogenèse dite « achevée » (C3) ; compost donné comme limitant le lessivage des nitrates, contraire à la leçon (C9) ; plumage du coq présenté comme hormonodépendant (D1, corrigé par l'orchestrateur) ; données impossibles, 12 ms de conduction pour 9 ms au total (D10). La relecture indépendante reste indispensable.
- **Questions qui ne tiennent pas seules** : récurrent dans C6, C7, D1, D4, D9 (notation, chiffres ou génotypes définis dans une autre question). Corrigé en relecture ; à ajouter au brief des rédacteurs.
- **Énoncés recopiés** dans les leçons adaptées (D1 depuis C1, D3 depuis C3) malgré la consigne : relevé et réécrit en relecture.
- **Corrections qui citent une étape inexistante** (« Observer / Interpréter » absent de la méthode) : D3, C2, C1.
- **Commits intermédiaires** : le hook de fin de tour exige un commit à chaque tour, d'où des commits « en cours » au lieu d'un commit par lot (CLAUDE.md). une trentaine de commits en tout, sous la limite de 40.

## Ce qu'on a appris sur la codebase

- Le contrôle d'entraînement (`NotionPractice.errors_for`, au moins une question à plusieurs cases et un indice, une rédigée au plus, aucune question recopiée de l'exercice noté) n'a pas de test pour la 1ère : il a été joué par un script local (`bin/rails runner`).
- Le nom d'un fichier suit l'intitulé de la progression sans accents : « La gamétogénèse » (D3) donne le même nom que le v1 « La gamétogenèse », remplacé.
- Les planches `soil_profile` et `root_hairs` couvrent le sol ; `map africa` et `map world` ne montrent pas de coupe ni de dorsale.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Points « à faire valider par un enseignant » (journal du programme, vague P5) | Programme officiel détaillé non accessible ici | — (avant publication) |
| Planches manquantes : testicule et tube séminifère, méiose, fécondation, ribosome, coupe du globe et de subduction, complexe argilo-humique, chloroplaste, moelle épinière, œil | Aucune sorte nouvelle dans ce chantier (hors périmètre) | à proposer au programme |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-01 (PR prête, fusion par l'orchestrateur) |
| **PR** | #435 vers `Develop` (`feature/contenus-1ere-svt-cd`), 16 leçons distinctes, 20 fichiers |
| **ADR produits** | aucun (ADR-0116, ADR-0117 du programme) |
| **UDR produits** | aucune (UDR-0142, UDR-0147 du programme) |
