# Memo — Accueil de la direction : établissement, niveaux, annonces, activité

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/accueil-direction` |
| **Programme** | — |

---

## Le problème

Une direction connectée arrive sur « Travail des élèves » : un tableau d'une ligne par classe (élèves, devoirs donnés, taux de rendu, moyenne). Il répond à une seule question, « nos élèves font-ils leurs devoirs ? », et il la pose à plat : toutes les classes de l'établissement, de la 6ème à la Terminale, dans une seule liste qui défile.

Rien n'y dit à la direction ce qui demande son attention (une classe sans enseignant, une classe vide, des enseignants en attente), rien ne lui permet d'aller droit à un niveau, et elle ne reçoit aucune information de l'équipe Lnclass ni ne voit ce qui s'est passé récemment dans son établissement.

Le porteur demande (2026-10-04) que la page principale de la direction s'organise en quatre sections :

1. **Établissement** : une carte qui réunit les alertes et les informations sur les classes ;
2. **Niveaux** : tous les niveaux de l'établissement, chacun avec son icône et son nom, sur le même principe que la section « Cours » de l'accueil enseignant (une bulle par niveau) : un niveau mène aux seules classes de ce niveau ;
3. **Annonces** ;
4. **Activité récente**.

## Pour qui

- **La direction (SchoolStaff)**, à chaque connexion, souvent au téléphone : c'est sa page d'arrivée.
- **L'équipe, l'enseignant, l'élève, le parent** : rien ne change pour eux. L'équipe continue de recevoir 403 sur les pages de la direction ; elle reste l'unique rédactrice des annonces que la direction lit (D-A1).

## Pourquoi maintenant

L'espace direction simple est en production depuis la V2 et s'est enrichi (page « Établissement », retrait d'enseignants, anciens élèves) ; les premières directions s'en servent. Le porteur juge que le tableau seul ne suffit pas comme page d'arrivée (2026-10-04), et le chantier `annonces` donne enfin un contenu à la section « Annonces » prévue dès l'ancienne application (CO-11).

## Hors périmètre

*(à compléter au grill)*

- **Construire les annonces** (rédiger, publier, lire, masquer, retirer) : chantier `annonces`, en cours sur sa branche. Ce chantier ne fait qu'afficher son carrousel.
- **Changer qui rédige et qui masque les annonces** (D-A1) : décidé par le porteur, mis en œuvre par le chantier `annonces` (ADR-0078, UDR-0071 amendés là-bas).
- Toute rédaction d'annonce par la direction : seule l'équipe rédige (D-A1).
- Le tableau « Travail des élèves » sous sa forme actuelle : remplacé par les cartes de classe de chaque niveau (Q4).
- Toute couleur relative (classement des classes entre elles), tout historique ou évolution dans le temps du taux de rendu, tout export.
- Une bulle par série, une bulle pour un niveau sans classe, l'ajout d'une classe depuis l'accueil (il reste sur « Établissement »).
- Les sessions d'exercice terminées comme événements d'activité, le journal d'audit comme source, une table d'événements.
- Un réglage des seuils de la pastille par l'établissement ou l'équipe.
- La page d'une classe : inchangée, hormis son lien de retour.
- Toute écriture par la direction qui n'est pas explicitement décidée ici.
- La page « Enseignants » : inchangée.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Les annonces n'existent pas sur `Develop` : ce chantier les construit-il ? | **Non** : un chantier `annonces` est en cours sur sa propre branche (porteur, 2026-10-04). | Ce chantier **ne construit rien** des annonces : il les **affiche** sur l'accueil de la direction, en lisant ce que le chantier `annonces` fournit. **Dépendance** : la section ne peut se coder qu'après le merge d'`annonces` dans `Develop`. Écart à trancher : `annonces` a décidé que le carrousel reste propre à l'accueil élève et que la direction lit ses annonces sur une page « Annonces » de sa navigation ; une section sur l'accueil de la direction est un **ajout** à l'UDR-0071, pas une contradiction. Fichier partagé probable : `navigation_helper` (le Lot D d'`annonces` y ajoute « Annonces »). |
| Q2. Que montre la section « Annonces » de l'accueil de la direction ? (A aperçu des reçues · B aperçu + « Rédiger » · C ses annonces en ligne · D le carrousel de l'élève) | **D : le carrousel de l'élève, à l'identique** (porteur, 2026-10-04). | On réutilise le carrousel du chantier `annonces` (5 cartes au plus, ordre direction → enseignants → Lnclass, lien « Toutes les annonces » vers la page « Annonces »), alimenté par la même règle de lecture : la direction y voit les annonces nationales et celles de son établissement destinées à « tous » ou « aux directions ». Pas de bouton « Rédiger » sur l'accueil : on rédige depuis la page « Annonces ». Le gabarit du carrousel porte aujourd'hui des identifiants propres à l'accueil élève : il faudra le paramétrer (fichier du chantier `annonces`, donc **après son merge**). Point dur : « masquer » est réservé à l'élève par le chantier `annonces` (voir Q3). |
| Q3. Dans son carrousel, la direction peut-elle masquer une annonce ? (le chantier `annonces` réserve le masquage à l'élève) | **Non** (porteur, 2026-10-04). | Le carrousel de la direction s'affiche **sans aucune croix** ; la règle de masquage du chantier `annonces` (ADR-0078 §4.2) ne change pas. Une annonce de l'équipe reste dans le carrousel jusqu'à sa date de fin. Un test vérifie l'absence de croix, et le serveur refuse déjà un masquage forgé par une direction (403). Le carrousel doit donc accepter « jamais masquable » comme paramètre, en plus de la règle « officielle ». **Revu par la décision D-A1 ci-dessous : toute annonce devient masquable, la croix revient.** |
| D-A1. *(décision du porteur, hors question, 2026-10-04)* « Nous allons alléger tout. Seule l'équipe peut créer les annonces. Toutes les annonces peuvent être masquées. » | **L'équipe seule rédige** ; ni la direction ni l'enseignant ne publient. **Toute annonce est masquable**, par tout lecteur. | Cette décision appartient au chantier **`annonces`**, pas à celui-ci : elle y défait l'auteur « direction » et l'auteur « enseignant » (ciblage par classes, Lot A déjà mergé sur sa branche), la notion d'annonce « officielle » et le retrait par la direction (Lot C). Elle amende l'ADR-0078 et l'UDR-0071, et se reporte dans le memo d'`annonces`. **Pour ce chantier** : le carrousel de la direction ne montre que des annonces de l'équipe (nationales ou pour son établissement) ; **chaque carte a sa croix** et le toast « Annuler », comme chez l'élève. Dépendance : la règle de masquage d'`annonces` doit accepter la direction comme lecteur qui masque. |
| Q4. Quand la direction touche la bulle d'un niveau, qu'est-ce qui s'ouvre ? (A le tableau filtré · B des cartes de classe · C tableau complet en plus) | **B, avec une icône par classe**, et **un signal** : une pastille posée sur le rond de la classe, comme une notification, **rouge, jaune ou verte**, pour comparer les classes (porteur, 2026-10-04). | Le tableau « Travail des élèves » quitte la page : la page d'un niveau montre ses classes en ronds à icône, chacun avec sa pastille, puis mène à la page de la classe (inchangée). **Écarts à trancher dans l'UDR** : la charte (§5) réserve l'ambre à l'urgence et interdit le rouge pour juger un résultat ; l'UDR-0052 interdit qu'une information ne passe que par la couleur — la pastille doit donc avoir un équivalent texte (lecteur d'écran et légende). À trancher au grill : ce que mesure la couleur, ses seuils, l'icône d'une classe. |
| **Mode de décision** *(porteur, 2026-10-04)* : « Prendre des décisions, c'est autonome. Pose-moi la question si et seulement si tu doutes de ta décision. » | Les questions suivantes sont **tranchées par l'agent** (décisions par défaut), sans aller-retour. | Chaque ligne ci-dessous marquée *(décision par défaut)* reste révisable par le porteur à la relecture du PRD et de l'UDR ; aucune n'a été jugée douteuse au point de bloquer. |
| Q5. Que mesure la couleur de la pastille ? *(décision par défaut)* | Le **taux de rendu**, à **seuils fixes** : vert à partir de 70 %, jaune de 40 à 69 %, rouge sous 40 %. Sans devoir donné ou sans élève, **pas de pastille**. | La question de la direction est « nos élèves font-ils leurs devoirs ? » ; le taux de rendu existe dès le premier devoir, la moyenne attend 5 élèves ayant rendu. Une couleur relative au niveau aurait toujours mis une classe en rouge. Les seuils sont une **règle métier** : ils vivent dans le domaine, testés à leurs bornes (39/40, 69/70). Le taux s'affiche toujours en chiffres à côté : la couleur n'est jamais seule. |
| Q6. Quelle icône pour une classe ? Les classes n'en ont pas, les niveaux non plus. *(décision par défaut)* | **Une illustration par niveau**, choisie par le slug figé du niveau (6ème crayon, 5ème règle, 4ème équerre, 3ème diplôme du BEPC, 2nde loupe, 1ère ampoule, Tle toque du BAC), sur une teinte propre au niveau. Une classe porte l'illustration de son niveau. | Aucune colonne en base : sept fichiers d'illustration et une table de correspondance, comme les matières (UDR-0069). Un niveau inconnu prend l'illustration générique. Sur la page d'un niveau, toutes les classes ont la même icône : c'est leur nom et leur pastille qui les distinguent. |
| Q7. « Tous les niveaux » : un niveau, ou un couple niveau-série (« Tle D ») ? Et un niveau sans classe ? *(décision par défaut)* | **Une bulle par niveau**, pas par série : la page « Tle » liste les classes de toutes les séries. Seuls les niveaux où l'établissement a **au moins une classe active de l'année** ont une bulle, triés de la 6ème à la Tle. | Un collège a au plus 4 bulles, un lycée au plus 7 : une ligne au téléphone. Ajouter une classe à un niveau vide reste sur la page « Établissement ». Un niveau sans classe a une adresse qui répond 404. |
| Q8. La bulle d'un niveau porte-t-elle aussi une pastille ? *(décision par défaut)* | **Oui** : le taux de rendu **du niveau** (devoirs rendus de ses classes ÷ élèves × devoirs, toutes classes confondues), mêmes seuils. | La direction voit dès l'accueil quel niveau regarder ; la page du niveau dit quelle classe. Même règle, même légende, aux deux endroits. |
| Q9. Que contient la carte « Établissement » ? *(décision par défaut)* | Le **nom**, le type et l'année ; **trois chiffres** (classes, élèves, enseignants) ; puis les **alertes**, une ligne chacune : établissement non actif ; classes sans enseignant ; classes sans élève ; classes au signal rouge ; enseignants sans classe. Sans alerte : « Rien à signaler ». En pied : « Voir l'établissement » et « Anciens élèves ». | Les alertes ne demandent aucune donnée nouvelle. Chaque alerte nomme au plus trois classes (« 3ème 2, 4ème 1 et 2 autres ») et mène là où l'on agit, quand un geste existe (lien d'inscription des enseignants, page « Enseignants »). Le lien « Anciens élèves », aujourd'hui sous le tableau, déménage dans le pied de la carte. Les chiffres reprennent les définitions existantes : un élève présent dans deux classes compte une fois dans l'établissement ; « enseignants » = le compte de la page « Enseignants ». |
| Q10. Que contient « Activité récente » ? *(décision par défaut)* | Les **10 derniers événements des 30 derniers jours**, groupés par jour : un devoir donné (« M. Kouassi a donné « Les fractions » à 3ème 2 »), un élève arrivé dans une classe (« Awa K. a rejoint 3ème 2 »), un enseignant arrivé dans l'établissement. Chargée **en différé** (frame paresseux), comme l'activité de l'élève. | Lu dans les tables existantes, sans table d'événements ni journal (le journal d'audit ne porte pas l'établissement). Un élève est nommé par son prénom et l'initiale de son nom : l'accueil se capture et circule sur WhatsApp (charte §1). Les sessions terminées par les élèves ne sont pas des événements : elles seraient des centaines par jour. |
| Q11. Que devient l'entrée « Travail des élèves » de la navigation ? *(décision par défaut)* | Elle devient **« Accueil »** (icône maison), comme pour les autres rôles ; l'adresse `/school-admin/classrooms` ne change pas. La page d'une classe et la page d'un niveau marquent « Accueil » comme entrée active. | La navigation est un fichier partagé avec le chantier `annonces` (qui y ajoute « Annonces ») : il appartient au Lot 0 et se fusionne avec soin. Le retour de la page d'une classe mène à la page de son niveau, plus au tableau. |
| Q12. Acteurs, multi-appartenance, autres établissements *(angles obligatoires)* | Une direction n'a qu'un établissement (contrainte en base) ; l'établissement vient toujours du compte, jamais de l'adresse. Un élève inscrit dans deux classes compte dans chacune, et une fois dans l'établissement. L'équipe, l'enseignant, l'élève : 403. Le parent n'existe pas. | Un test de refus par nouvelle adresse (autre rôle 403 ; niveau d'un autre établissement ou sans classe 404). La page d'un niveau ne lit que les classes de l'établissement du compte. |

## Cas limites identifiés

- **Aucune classe cette année** : carte « Établissement » avec « 0 classe » et ses alertes ; section « Niveaux » à l'état vide (« Aucune classe cette année ») avec un lien vers « Établissement ».
- **Un seul niveau** (établissement d'un seul niveau) : une bulle.
- **Classe sans élève** ou **sans devoir** : pas de pastille, la carte dit « Aucun élève » ou « Aucun devoir donné » ; elle compte dans l'alerte « sans élève ».
- **Niveau dont toutes les classes sont sans devoir** : bulle sans pastille.
- **Taux à la borne** : 40 % est jaune, 70 % est vert, 39 % rouge, 69 % jaune (arrondi à l'entier, comme l'affichage).
- **Niveau dont la dernière classe vient d'être retirée** : la bulle disparaît ; son adresse répond 404.
- **Slug de niveau inconnu** (`/school-admin/levels/7eme`) : 404.
- **Classe archivée ou d'une autre année** : absente partout (règle existante).
- **Établissement non actif** : tout se lit ; l'alerte le dit en premier.
- **Aucune annonce lisible** : pas de section « Annonces » (règle du carrousel).
- **Toutes les annonces masquées** : la section garde son lien « Toutes les annonces », sans bande (règle du carrousel).
- **Aucune activité en 30 jours** : « Rien de nouveau ces 30 derniers jours ».
- **Enseignant anonymisé ou parti** : ses devoirs passés restent dans l'activité, signés de sa fonction seule (« Un enseignant a donné … »).
- **Élève anonymisé** : son arrivée disparaît de l'activité.
- **Plus de 3 classes dans une alerte** : trois noms puis « et N autres ».

## Questions encore ouvertes

- **D-A1 à reporter dans le chantier `annonces`** (l'équipe seule rédige, tout se masque) : c'est au porteur ou à la session qui mène `annonces` de l'y inscrire (memo, ADR-0078, UDR-0071). Ce chantier ne touche pas sa branche. Tant que ce n'est pas fait, le lot « Annonces » de ce chantier attend.
- **Seuils 70 / 40** : décision par défaut, à confirmer par le porteur après les premiers retours de directions.
- **Écart avec la charte** (§5 : ambre = urgence seulement, jamais de rouge pour juger un résultat) : demandé explicitement par le porteur pour la direction ; l'UDR l'acte comme exception propre à l'espace direction. La charte de l'élève ne change pas.
