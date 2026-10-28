# Memo — Fiches de révision en blocs

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | exécution — phase 2 (Lentilles, Texte argumentatif) ouverte par le porteur le 2026-10-28 |
| **Ouvert le** | 2026-10-12 |
| **Revu le** | 2026-10-13 (grill repris avec l'algorithme en 5 étapes : questionner, supprimer, simplifier, accélérer, automatiser) ; 2026-10-27 (périmètre élargi aux maquettes à l'identique, voir ci-dessous) |
| **Pilote** | Touré (`toure-bangaly`), avec l'accord du porteur |
| **Branche** | `feature/fiches-de-cours` (l'ancienne `feature/contenu-en-blocs` du 12/10 est laissée telle quelle) |
| **Programme** | — |

---

## Le problème

Une fiche essentielle n'est aujourd'hui qu'un long texte mis en forme : titres, listes, gras, formules. L'élève lit un mur de texte sur son téléphone. Rien ne distingue une propriété à retenir d'un piège à éviter, aucun mot difficile n'est expliqué sur place, aucune figure ne peut être montrée. Une leçon est découpée en 2 à 5 fiches qu'il faut ouvrir l'une après l'autre.

Côté exercices, l'élève ne peut répondre qu'en cochant (vrai/faux, choix unique, plusieurs bonnes réponses). Il ne peut pas taper le résultat d'un calcul, alors que c'est ce que demandent les devoirs de mathématiques, de physique-chimie et de SVT. Il n'a aucune aide quand il bloque.

L'équipe a reçu 9 fiches maquettées (Thalès, Lentilles, Texte argumentatif, Digestion, Colonisation, Devoirs des parents, Dissertation philosophique, Cinématique, plus une version mobile à onglets de Colonisation). Ce sont des fiches de cours de 3 à 4 pages A4, pas des fiches de révision. Elles servent de matière première, pas de cahier des charges. Passées à l'algorithme en 5 étapes, elles laissent un noyau de 9 blocs et 2 ajouts aux exercices.

213 leçons déjà rédigées existent sous forme de texte mis en forme.

## Pour qui

- **L'élève**, qui révise seul, le soir avant un devoir, sur un téléphone d'entrée de gamme et une connexion lente.
- **L'équipe**, qui écrit ou fait écrire les fiches et les importe.
- **L'enseignant**, qui ouvre la même fiche pour la projeter, assigne les exercices et lit qui a compris. Aucun geste nouveau pour lui dans ce chantier.

## Pourquoi maintenant

Le modèle de fiche est validé par le porteur (style cahier, mobile d'abord, import avant tout éditeur). Tant que le format n'existe pas, chaque nouvelle leçon est écrite dans l'ancien format et devra être reprise. Les classes d'examen (3ème, Tle) sont les premières à en profiter.

## Ce que le chantier livre

**Une fiche de révision par leçon.** À l'écran, la leçon affiche une seule fiche qui défile, avec un sommaire. Les fiches essentielles actuelles en deviennent les parties. Rien ne change dans le découpage des données, et la remédiation reste précise : une lacune vise une partie.

**Le nom « Fiche de révision »** remplace « Fiche essentielle » partout à l'écran.

**Les 9 blocs d'une partie :**

| Bloc | Rôle |
|---|---|
| Tu dois savoir | 1 à 3 objectifs en verbes d'action, que les exercices vérifient |
| À retenir | Définition, propriété, règle ou formule exacte, avec un nom (« Propriété de Thalès ») |
| En clair | 1 à 3 phrases avec l'image du quotidien, sous le « À retenir » qu'elles expliquent ; l'élève peut les afficher ou les masquer |
| Méthode | Étapes numérotées avec les phrases modèles de l'examen |
| Exemple rédigé | Énoncé, puis la solution rédigée comme sur la copie |
| Attention | Le piège le plus fréquent et comment le repérer |
| Tableau | Comparer ou choisir (« Quelle propriété utiliser ? ») ; une carte par ligne sur téléphone |
| Document | Citation, texte de loi ou extrait, avec sa source et une ligne de lecture critique |
| Figure | Image fixe et légende : schéma, figure de géométrie, carte |

S'y ajoutent **le lexique** (mots soulignés, définition en bulle, liste complète en bas de fiche) et **les sources** (une ligne en bas de fiche). Règle : **un mot est défini une seule fois**, dans « À retenir » ou à sa première apparition ; le lexique reprend cette définition, il n'en écrit pas une deuxième.

**L'habillage cahier** : fond Seyès et écriture manuscrite (titres, « En clair », notes en marge, solutions rédigées), avec une couleur fixe par type de bloc.

**Les exercices** gardent leurs 3 rôles (Comprendre, Appliquer, S'évaluer) et leurs 4 types. Deux ajouts :
- **la réponse numérique** : l'élève tape un nombre, avec la virgule ou le point, dans une tolérance fixée ; l'unité est affichée ;
- **l'indice** : facultatif par question, affiché à la demande avant de répondre, sans effet sur la note.

Chaque type d'exercice s'affiche comme sur les maquettes : retour « juste / à revoir » en couleur, bouton « Indice », case de saisie avec son unité, explication après la réponse. Associer, classer et compléter un texte à trous s'écrivent avec des questions à choix unique qui partagent les mêmes propositions ; aucun type de plus n'est nécessaire pour eux.

## Révision du 2026-10-27 : les maquettes à l'identique

> Décision de Touré, pilote du chantier avec l'accord du porteur. Elle **remplace** les lignes du grill et du hors-périmètre qui la contredisent ; le reste du memo tient.

Les maquettes deviennent le cahier des charges. La référence est le handoff de design rangé dans [`docs/design/fiches-cours/`](../../design/fiches-cours/README.md) : 3 fiches (Thalès, Lentilles, Texte argumentatif), en haute fidélité. Couleurs, typographie, espacements et interactions s'y reproduisent au pixel près.

**Entre dans le périmètre** (retiré du hors-périmètre) :
- la mise en page des maquettes : papier Seyès, pages, thème de couleurs propre à chaque fiche, Kalam et Source Serif 4 hébergées par Lnclass ;
- les médias interactifs des 3 fiches : figure de Thalès à points déplaçables, simulateur de lentille, surligneurs du texte argumentatif, exercice de construction ;
- les exercices dans la fiche, comme sur les maquettes : « Vérifier », retour « juste / à revoir » par champ, « Indice », « Correction », tolérance de ±0,011 sur les réponses numériques ;
- « Je m'entraîne » : générateur d'énoncés au hasard et score ;
- la rédaction libre et ses vérifications automatiques (fiche Texte argumentatif), la zone « Ma rédaction » ;
- « Explications simples : oui/non » et le lexique en bulle avec le bouton « Lexique ».

**Reste hors périmètre** :
- le mode relecture enseignant « Signaler une erreur » : chantier à part (table, API, file de traitement pour l'équipe) ;
- un éditeur dans l'interface de l'équipe, le serveur MCP, la conversion des 213 leçons.

**Réponses aux questions ouvertes, induites par cette décision** :
- Exercices : ceux de la fiche se corrigent dans la page, sans note. Les exercices actuels (session, note, badge, remédiation) ne changent pas.
- Tolérance : une règle unique, ±0,011, celle des maquettes.
- Remplacement d'une leçon en ligne et conversion des 213 leçons : hors de ce chantier.

**À trancher au plan** : où vit le contenu d'une fiche (données importées et composants communs, ou une vue par fiche) ; comment une figure propre à une fiche reste maintenable ; le rendu sous 1 000 px (les maquettes ont une largeur fixe de 880 à 1 000 px, le téléphone à 390 px reste obligatoire) ; le nom à l'écran (« Fiche de cours » sur les maquettes, « Fiche de révision » dans ce memo).

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler. Nettoyée le 2026-10-27 (#318) : la mise en page, les médias interactifs, la rédaction libre et les énoncés générés sont entrés dans le périmètre (voir la révision ci-dessus).

- Le mode relecture enseignant « Signaler une erreur » : chantier à part (table, API, file de traitement pour l'équipe).
- Un éditeur de fiches dans l'interface de l'équipe : l'import vient d'abord.
- Le serveur MCP pour créer, lire et importer les fiches depuis un assistant : chantier à part.
- La conversion des 213 leçons : chantier de contenu à part, qui reste à ouvrir par le porteur.
- Le remplacement d'une fiche déjà en ligne par sa nouvelle version : un import qui retrouve une fiche existante l'ignore, comme aujourd'hui.
- Les exercices actuels (session, note, badge, lacune, remédiation) : inchangés. Les exercices de la fiche ne donnent ni note ni lacune.
- Des médias interactifs ou des générateurs au-delà des 3 fiches : la liste des figures et des générateurs est fermée, chaque nouveau demande du code et un lot.
- Une figure fournie comme fichier image ou SVG dans l'import : les figures des 3 fiches sont dessinées par Lnclass.
- Parent (n'existe pas) et direction d'établissement : rien ne change pour eux.

## Ce que le grill a révélé

> Grill du 2026-10-12, repris le 2026-10-13 avec l'algorithme en 5 étapes. Les réponses marquées « revu » remplacent celles de la veille.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les maquettes sont-elles le cahier des charges ? | Non : ce sont des fiches de cours sorties d'un outil de design. On garde ce qui sert à réviser. | 9 blocs sur une trentaine d'éléments ; tout ce qui demande du code propre à une fiche est écarté. |
| Une fiche de révision par leçon, alors qu'une leçon a 2 à 5 fiches essentielles ? | Une seule fiche à l'écran, dont les fiches essentielles deviennent les parties. | Pas de migration des données ; la lacune et la remédiation restent par partie ; le sommaire mène à chaque partie et à ses exercices. |
| Quel nom à l'écran ? | « Fiche de révision ». | Le vocabulaire de l'interface et le glossaire changent ; « Fiche essentielle » disparaît de l'écran. |
| Que deviennent les 213 leçons déjà rédigées ? *(revu)* | Elles passent au nouveau format leçon par leçon, en commençant par les classes d'examen. | Deux affichages coexistent tant que la conversion n'est pas finie : l'ancien texte mis en forme et les blocs. Le premier retour d'élèves arrive dès la première leçon convertie. |
| Que se passe-t-il quand le contenu d'une fiche ou d'un exercice change ? *(revu)* | Les contenus doivent s'adapter. | Une leçon déjà en ligne doit pouvoir être remplacée par sa nouvelle version, ce que l'import refuse aujourd'hui (un cours existant est ignoré). Voir les cas limites sur les exercices déjà faits. |
| Qui convertit ? | Un modèle de langue convertit, l'équipe relit sur la recette, puis la leçon passe en production. | Le prompt de rédaction passe au nouveau format ; le contrôle automatique des fichiers aussi. |
| À quoi le lexique est-il rattaché ? *(revu)* | À la fiche ; un mot est défini une seule fois, dans « À retenir » ou à sa première apparition. | Le lexique en bulle est gardé ; la liste complète en bas de fiche se déduit des mots définis, elle ne se saisit pas. Le contrôle des fichiers refuse un mot défini deux fois. |
| Sur téléphone, onglets ou page qui défile ? | Une page qui défile, un sommaire en tête, le lexique en bas. | La lecture marche sans JavaScript ; la bulle et « En clair » en demandent, avec un repli lisible sans. |
| Les exercices d'application à correction affichable ? *(revu)* | Retirés pour le moment ; le concept sera retravaillé. | Le verrou de correction par classe et par enseignant disparaît : plus de réglage par classe, plus d'élève « sans classe » à traiter, rien dans la classe. |
| Le chantier ouvre-t-il les images ? *(revu)* | Oui : la figure fixe entre dès ce chantier. | Premier fichier envoyé par l'équipe dans une fiche : la menace « fichier envoyé » s'écrit avant le code. Les images s'importent avec la fiche et comptent dans le poids de la page. |
| Fond Seyès et écriture manuscrite ? *(revu)* | Intégrés dans ce chantier. | Une police manuscrite de plus, hébergée par Lnclass et chargée seulement sur les fiches, dans le budget de poids des pages. Couleur fixe par type de bloc. |
| Quels types d'exercices ? *(revu)* | Les 4 actuels, plus la réponse numérique et l'indice, affichés comme sur les maquettes. | Un nouveau type de question et un nouveau champ ; l'écran de session change pour chaque type ; la correction compare un nombre avec une tolérance. |
| Un bloc mal formé dans un import ? *(revu)* | Le fichier est refusé, comme aujourd'hui, avec un avertissement. | Pas de perte silencieuse : rien n'est importé, et le rapport nomme chaque bloc en cause (fiche, position, raison). |
| Où l'équipe relit-elle ? | Sur la recette. | Chaque leçon convertie y est importée et relue avant la production. |
| *(lu dans le code)* Parent, direction d'établissement ? | Le Parent n'existe pas ; la direction ne lit pas les fiches. | Rien pour eux. |

## Cas limites identifiés

- Une leçon remplacée alors que des élèves ont déjà fait ses exercices : une question déjà tentée ne se modifie pas. Les anciens exercices sont archivés, pas modifiés ; les notes, badges et lacunes déjà obtenus restent lisibles.
- Une leçon remplacée qui perd une partie : les lacunes ouvertes sur cette partie doivent rester visibles ou se fermer, sans erreur.
- Pendant la conversion, une même matière a des leçons dans l'ancien format et d'autres en blocs : les deux s'affichent correctement côte à côte.
- Une réponse numérique écrite « 4,2 », « 4.2 », « 4,20 » ou « 4,2 cm » : les trois premières sont justes ; l'unité est déjà affichée.
- Une réponse numérique dans la tolérance mais arrondie autrement que la solution : elle est juste.
- Une question sans indice : pas de bouton « Indice ».
- Une figure absente du fichier importé ou trop lourde : le fichier est refusé avec la raison.
- Un mot défini deux fois dans la même fiche : le fichier est refusé avec la raison.
- Une formule KaTeX invalide : le fichier est refusé avec la raison.
- Une fiche très longue (20 blocs et plus) sur un téléphone d'entrée de gamme : le sommaire doit rester utile.
- JavaScript coupé : la fiche se lit en entier, « En clair » visible, le lexique en bas de fiche.

## Questions encore ouvertes

- « Les contenus doivent s'adapter » : vise-t-on (a) le remplacement d'une leçon déjà en ligne par sa nouvelle version, (b) la mise à jour automatique des leçons converties si le format des blocs évolue, ou les deux ?
- Les exercices « comme sur les maquettes » : on garde la session actuelle (une question à la fois, une note, un badge, la remédiation) en adoptant l'aspect des maquettes, ou les exercices s'affichent dans la fiche, avec un bouton « Vérifier » et sans note ?
- La tolérance d'une réponse numérique : fixée par question dans le fichier, ou une règle unique (par exemple au centième) ?
- Le chantier de conversion des 213 leçons : qui l'ouvre, avec quel prompt et quel contrôle de relecture.
