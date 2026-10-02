# Memo — Interface épurée

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision — grill terminé le 2026-10-02 ; la décision d'interface attend les maquettes des écrans disponibles, promises par le porteur |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `feature/interface-epuree` |
| **Programme** | — *(hors plan de `refonte-application` ; précède le chantier `app-android`, ADR-0070)* |

---

## Le problème

Le porteur juge l'application trop chargée : pas assez épurée, pas assez simple à utiliser pour tout le monde. Le constat n'est pas encore mesuré ni localisé écran par écran.

Ce que l'on sait : l'interface compte environ 230 vues, construites écran par écran depuis la V1, chacune avec sa propre décision d'interface (plus de 50 UDR). Un design system fondateur existe (UDR-0005), ainsi qu'un shell par rôle (UDR-0006) et une passe de finitions (UDR-0054). Aucune décision ne fixe de règle de sobriété commune : combien d'actions, de textes ou d'éléments un écran peut montrer.

## Pour qui

- **Élève**, souvent sur un Android d'entrée de gamme. C'est le seul public de ce chantier (grill, Q1).

L'enseignant, la direction et l'équipe sont traités dans un chantier suivant, qui appliquera la règle de sobriété fixée ici. Seule exception : les trois écrans communs du parcours d'entrée (bienvenue, connexion, récupération du PIN) sont épurés ici pour tous les rôles (grill, Q9).

## Pourquoi maintenant

Les apps Android (ADR-0070, en attente) afficheront les pages du site telles quelles. Ce que ce chantier simplifie, les apps en héritent sans travail de plus ; ce qu'il laisse chargé, elles l'emportent sur le Play Store.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Toute nouvelle fonctionnalité métier.
- Les écrans de l'enseignant, de la direction et de l'équipe : chantier suivant (grill, Q1).
- Les échéances et les retards, la durée des exercices, le paiement et l'abonnement, les annonces, la lecture audio : chantier `fonctions-espace-eleve` (grill, Q8).
- Les apps Android (chantier `app-android`) et la PWA (`installation-pwa`).
- Les finitions déjà livrées par `finitions-ux` (retour, auto-focus, infobulles, « Copier », recherche, titres).

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1 — Quels publics ce chantier couvre-t-il ? Tout épurer d'un coup, 4 publics et environ 230 écrans, est le moyen le plus sûr de ne rien finir. | **L'élève seulement.** La maquette V2 de l'accueil élève, validée par le porteur le 2026-10-02, sert d'écran de référence. | Le périmètre se réduit aux écrans de l'élève. Enseignant, direction et équipe passent hors périmètre, dans un chantier suivant qui reprendra la règle. |
| Q2 — Comment sait-on qu'un écran élève est « assez épuré » ? Sans règle mesurable, chaque écran est épuré à l'œil et le chantier ne finit jamais. | **Une règle chiffrée.** Par écran : une seule action principale ; au plus 5 blocs visibles avant de faire défiler ; au plus 3 lignes par liste, puis « Voir plus » ; aucun texte d'aide affiché en permanence ; une seule couleur d'accent, hors signal d'urgence. | La règle devient une décision d'interface commune aux écrans élève, et chaque point devient un critère vérifiable par un test. Un écran est « fini » quand il respecte les cinq points. |
| Q3 — Épurer, c'est retirer. Quand une information ou une action disparaît d'un écran, où va-t-elle ? | **Éviter les répétitions d'information et la surcharge.** Le porteur vise d'abord ce qui est dit deux fois et ce qui encombre, pas un déplacement systématique vers un autre écran. | Sixième point de la règle : une information n'apparaît qu'une fois par écran (pas de matière répétée dans l'icône, le libellé et un badge, pas de statut redit en texte et en couleur sans raison d'accessibilité). Le sort d'une information unique mais secondaire reste à trancher (Q4). |
| Q4 — Une ligne d'exercice montre titre, matière, badge, meilleur score, maîtrise, nombre de sessions et une action. Rien n'est répété, mais c'est surchargé. Que deviennent badge, maîtrise et sessions ? | **Ils passent dans l'écran de détail** (l'exercice ou la matière). | Une ligne de liste ne garde que ce qui sert à choisir : titre, matière, échéance ou note, et une action au plus. Le reste est montré un tap plus loin : aucune information n'est supprimée de l'interface élève. |
| Q5 — La grille tient en 8 cases (6 matières, Paiement, Inviter). Un élève de Terminale a 9 à 11 matières : la grille déborde ? | **Non : Lnclass ne couvre que 6 matières.** Maths, Physique-Chimie, SVT, Français, Histoire-Géographie, et EDHC (1er cycle) ou Philosophie (2nd cycle). Les autres matières ne seront pas proposées. | La grille est fixe : 6 matières, Paiement, Inviter. Pas de case « Toutes », pas de tri dynamique, pas de débordement. Seule variation : EDHC devient Philosophie selon le cycle de l'élève. |
| Q6 — La carte du haut « Prochain exercice » suppose un exercice à faire. Qu'affiche-t-elle s'il n'y en a aucun (rien d'assigné, ou tout est fini) ? | **Elle présente la classe avec un message d'encouragement.** Le porteur pense qu'une carte existe déjà pour cet état. Il ajoute : sur tablette et ordinateur, la grille peut aligner 6 éléments par rangée. | La carte du haut a au moins deux états, « Prochain exercice » et « Ma classe + encouragement », à reprendre de la planche d'états existante. La disposition tablette et ordinateur entre dans le chantier : la grille passe de 4 à 6 éléments par rangée sur les grands écrans. |
| Q7 — L'élève a une douzaine d'écrans (accueil, ma classe, matière et cours, fiche essentielle, exercice, session, résultat, profil, inviter, rejoindre une classe, connexion). Lesquels entrent dans ce chantier ? | **Tous les écrans élève.** Le porteur partagera ensuite les maquettes des écrans déjà disponibles. | Le chantier couvre tout le parcours élève, livré par lots, l'accueil en premier puisqu'il fixe la référence. Les maquettes du porteur entrent dans la décision d'interface ; un écran sans maquette suit la règle seule. |
| Q8 — Plusieurs éléments de la maquette V2 reposent sur des fonctions qui n'existent pas encore (échéances et retards, durée d'un exercice, paiement et abonnement, annonces, lecture audio). Le memo exclut toute nouvelle fonctionnalité. Qu'en fait-on ? | **Interface seule.** Le chantier n'épure que ce qui existe déjà. | Ces éléments n'apparaissent pas encore : ni échéance ni signal de retard, ni durée, ni case Paiement, ni annonces, ni audio. Ils sont regroupés dans le chantier `fonctions-espace-eleve`, ouvert le 2026-10-02 à la demande du porteur. Tant que le paiement n'existe pas, la grille compte 7 cases (6 matières, Inviter). « À faire ensuite » reste trié par date d'assignation, la plus récente d'abord. La barre de la carte du haut compte les exercices faits sur les exercices assignés, sans notion de semaine. |
| Q9 — Trois écrans de l'élève sont aussi vus par les autres rôles : l'écran de bienvenue, la connexion et la récupération du PIN. Les épurer change aussi ce que voient l'enseignant, la direction et l'équipe. Que fait-on ? | **Épurés pour tous les rôles**, dans ce chantier. | Exception assumée à Q1 : ces trois écrans communs suivent la règle pour tout le monde. L'écran de bienvenue a déjà sa maquette, validée par le porteur. On évite deux styles côte à côte sur le parcours d'entrée. |
| Q10 — Sur grand écran, la grille aligne 6 éléments par rangée. Avec 7 cases (6 matières et Inviter), Inviter tombe seul sur une deuxième rangée. Que fait-on ? | **On accepte 6 + 1.** | Pas de cas particulier : la grille garde 6 colonnes sur grand écran et 4 sur téléphone, quel que soit le nombre de cases. Quand le paiement arrivera (`fonctions-espace-eleve`), la deuxième rangée aura 2 cases. |

## Cas limites identifiés

- **Rien à faire** (élève nouveau sans exercice assigné, ou tout est fait) : la carte du haut présente la classe avec un message d'encouragement (Q6).
- **Élève sans classe active** : comportement actuel conservé, un seul saut vers l'écran de sortie, sans boucle.
- **Listes longues** (beaucoup d'exercices à faire, historique fourni) : 3 lignes, puis « Voir plus » (règle, Q2).
- **Listes vides** : un état vide qui dit quoi attendre, jamais une section blanche.
- **Élève du 2nd cycle** : la case EDHC devient Philosophie (Q5).
- **Nom d'établissement trop long** dans l'en-tête : il passe à sa forme courte (sigle) plutôt que de déborder ou d'être coupé au milieu.
- **Exercice archivé ou retiré** alors qu'il figurait dans « À faire » : il disparaît de la liste, comme aujourd'hui.
- **Petit téléphone (360 px) et grand écran** : grille de 4 colonnes sur téléphone, 6 sur tablette et ordinateur, une dernière rangée incomplète acceptée (Q6, Q10).

## Questions encore ouvertes

- Maquettes des écrans disponibles : à recevoir du porteur avant la décision d'interface.
- Message d'encouragement de la carte « Ma classe » : texte unique, ou plusieurs textes selon la situation (rien d'assigné, ou tout est fait) ?
- Un niveau ou une série où l'une des 6 matières n'est pas enseignée (exemple à vérifier : SVT dans certaines séries du 2nd cycle) : case masquée, ou grille à 7 cases ?
