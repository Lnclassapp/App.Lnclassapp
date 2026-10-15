# Memo — Accueil élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planification |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

L'accueil de l'élève connecté (bandeau bleu, carte « Prochain exercice », grille des matières, « À faire ensuite », « Historique ») fonctionne, mais il ne ressemble pas encore à la nouvelle page d'accueil publique : celle-ci vient d'être redessinée sur le modèle de Wave et de Djamo (grande photo, feuille arrondie, bleu foncé, un seul écran au téléphone). En passant de l'une à l'autre, l'élève change d'univers visuel. Plusieurs maquettes de l'accueil élève existent (V2, V3, multi-écrans, états de la carte), chacune avec ses choix ; aucune n'a été tranchée face au design system.

## Pour qui

L'élève (Student), à chaque ouverture de l'application une fois connecté, le plus souvent sur un téléphone Android d'entrée de gamme, parfois avec une connexion faible.

## Pourquoi maintenant

La page d'accueil publique est dessinée et ses décisions sont prises : l'accueil élève est l'écran qui suit immédiatement. Le design system Lnclass existe désormais dans l'outil de design ; c'est le moment de dessiner l'accueil élève avec lui, avant de coder les deux écrans ensemble.

## Hors périmètre

- L'accueil de l'enseignant, de la direction et de l'équipe, sauf l'ajout du chiffre « fait seul » (page de la classe, accueil de la direction).
- Le contenu des pages ouvertes depuis l'accueil (exercice, matière, historique, paiement) : seul leur point d'entrée change.
- Le paiement lui-même : la tuile ouvre le parcours existant.
- La lecture hors ligne (chantier à part, promis par la pastille de la page d'accueil).
- Une barre d'onglets en bas de l'écran (refusée le 2026-10-14).
- Un compteur de jours d'affilée ou de badges en haut de l'accueil (refusé le 2026-10-15).
- Le parent : il ne voit rien de l'accueil de son enfant ; pas de changement de compte sur un téléphone partagé (2026-10-15).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| La grille mélange matières et actions (« Paiement », « Inviter »). On garde ce mélange ? | Oui : on garde « Paiement » et « Inviter » ; Lnclass se limite à 6 matières (porteur, 2026-10-14). | Grille de 8 tuiles : 6 matières + « Paiement » + « Inviter ». La 7e matière (EDHC ou Philosophie selon le cycle) doit trouver sa place ou disparaître de la grille. |
| Faut-il une barre d'onglets en bas, comme Wave et Djamo ? | Non, pas de barre native en bas (porteur, 2026-10-14). | La navigation reste celle du shell actuel (UDR-0006) ; l'accueil doit se suffire sans onglets. |
| Les maquettes ne montrent que le téléphone. Et la tablette, l'ordinateur ? | On adapte le design aux grands écrans (porteur, 2026-10-14). | Il faut dessiner tablette et ordinateur, pas seulement étirer le téléphone. |
| Le téléphone passe d'un enfant à l'autre, ou au parent : qui voit l'accueil ? | Un seul compte par téléphone : l'autre enfant se déconnecte puis se reconnecte (porteur, 2026-10-15). | Pas de sélecteur de comptes ni de vue parent. L'accueil doit dire clairement à qui il appartient (prénom, classe) pour qu'un frère ou une sœur s'en aperçoive, et la déconnexion doit rester trouvable depuis l'accueil. |
| Beaucoup de classes n'auront aucun enseignant sur Lnclass au lancement : la carte « Prochain exercice » reste vide. Que trouve l'élève ? | Les deux : un exercice proposé par Lnclass dans le programme de sa classe, qu'il fait seul, et en dessous un encouragement avec un bouton pour inviter son enseignant (porteur, 2026-10-15). | La carte du haut n'est jamais vide pour un élève qui a une classe : s'il n'a rien à rendre, Lnclass lui propose un exercice de son niveau (le catalogue de l'élève et la session en autonomie existent déjà). Il faut une règle qui choisit cet exercice. L'invitation de l'enseignant est un nouveau message à partager (WhatsApp), distinct de « Inviter » (les camarades). |
| Quel exercice Lnclass propose-t-il ? | Une matière différente chaque jour, à tour de rôle, pour couvrir tout le programme (porteur, 2026-10-15). | Règle : chaque jour, la matière suivante dans le tour des matières du niveau de l'élève, et dans cette matière le premier exercice publié qu'il n'a pas encore fait. La proposition reste la même toute la journée (heure d'Abidjan), elle ne change pas à chaque ouverture. Une matière sans exercice publié pour son niveau est sautée. |
| L'élève a fini l'exercice proposé du jour : que montre la carte ? | « Bravo, à demain ! » avec la matière de demain : un seul exercice proposé par jour (porteur, 2026-10-15). | Un nouvel état de la carte : « fait aujourd'hui », qui annonce la matière du lendemain. La limite ne touche que la proposition : l'élève peut toujours ouvrir d'autres exercices depuis la grille des matières. |
| L'enseignant donne un exercice à rendre : que devient l'exercice proposé par Lnclass ? | Il ne revient que lorsque tout le travail de l'enseignant est fait (porteur, 2026-10-15). | La carte du haut a une priorité stricte : d'abord le travail de l'enseignant (en retard, puis par date limite), ensuite seulement l'exercice proposé. Un travail en retard bloque la proposition tant qu'il n'est pas fait. Le tour des matières avance avec le calendrier, qu'une proposition ait été affichée ou non. |
| Quel chiffre en haut de l'accueil, comme le solde de Wave ? | Aucun ; puis, sur relecture : pas de salutation, ni prénom, ni classe non plus (porteur, 2026-10-15). | Le haut de l'accueil ne porte plus d'identité : l'accueil commence directement par la carte du haut. Pas de nouvelle donnée à calculer ni à stocker. Voir la ligne suivante pour l'identification du compte. |
| L'élève fait seul les exercices proposés : qui voit ses résultats ? | Lui, son enseignant et la direction de l'établissement, dans leurs chiffres de suivi (porteur, 2026-10-15). | Le travail en autonomie entre dans les vues de l'enseignant (page de la classe) et de la direction, mais séparé du travail donné : les chiffres « faits / en retard / pas encore faits » d'un exercice donné ne doivent pas l'absorber. Il faut un libellé « fait seul » et décider où il apparaît dans chaque vue. Le chantier touche donc aussi des écrans de l'enseignant et de la direction. |
| Sans prénom à l'écran, comment un frère ou une sœur voit-il que ce n'est pas son compte ? | Le prénom n'est que dans le menu du profil ; la photo de profil de l'élève est visible sur l'accueil (porteur, 2026-10-15). | La photo de profil (qui existe déjà) devient le seul repère d'identité sur l'accueil ; elle ouvre le profil et la déconnexion. Il faut décider ce qu'on montre quand l'élève n'a pas de photo. Le risque qu'un enfant travaille sur le compte de l'autre est accepté. |
| L'élève n'a pas de photo de profil : que montre-t-on ? | Ses initiales sur un rond de couleur, avec une invitation à ajouter sa photo (porteur, 2026-10-15). | Rond aux initiales (« KA »), d'une couleur stable propre à chaque élève, prise dans la palette du design system avec un contraste suffisant ; un petit « + » sur le rond mène à l'ajout de la photo (qui existe déjà). Une fois la photo ajoutée, le « + » disparaît. |
| Sur tablette et ordinateur, quelle disposition ? | Les sections suivent le même ordre qu'au téléphone, en une seule colonne (porteur, 2026-10-15) ; sur ordinateur, dans le cadre actuel avec le menu à gauche (voir ligne suivante). | Une colonne de 720 px dès 700 px de large ; dès 1 024 px, le menu de 288 px à gauche et une colonne de 960 px au plus. Maquettes : toile « Lnclass Accueil élève ». |
| Les maquettes repartent-elles de l'accueil actuel ? | Oui, après comparaison avec l'accueil de staging : on garde le cadre de l'application (en-tête avec photo, nom, aide et thème ; menu à gauche sur ordinateur) et on redessine les blocs actuels dans leur ordre : Ma classe, Mes matières, Annonces, À faire (et les fiches à revoir), Mes activités récentes (porteur, 2026-10-15). | La « carte du haut » des premières maquettes disparaît : la priorité stricte s'applique dans « À faire » (le travail en retard, puis par date limite), et l'exercice du jour s'y affiche quand aucun travail n'est donné, avec « Inviter mon enseignant ». Les tuiles Paiement et Inviter et l'état « abonnement terminé » sortent de la grille des matières. Les réponses précédentes sur le haut de l'accueil (ni salutation, ni prénom) cèdent devant l'en-tête actuel, qui montre la photo et le nom ; le « Bonjour » reste retiré. |
| Que montre l'en-tête ? | Le logo Lnclass à gauche à la place de l'avatar ; à droite l'aide, le thème, puis l'avatar seul (sans le nom), qui ouvre un menu déroulant (porteur, 2026-10-15). | Le menu du compte porte le nom et la classe, « Mon profil », « Ajouter ma photo » (sans photo) et « Se déconnecter ». C'est un changement de l'en-tête du shell élève (UDR-0080 §3.1), à reporter dans l'UDR du chantier. |
| Où se trouve « Besoin d'aide ? » ? | Sur ordinateur et tablette, dans l'en-tête, en gras bleu foncé avec une icône de tête à casque de support ; sur téléphone, dans le menu de l'avatar, entre « Mon profil » et « Se déconnecter » (porteur, 2026-10-15). | L'en-tête du téléphone ne garde que le logo, le thème et l'avatar. L'icône du casque n'existe pas dans Heroicons : elle est à dessiner pour le code. |
| Comment s'affiche « Mes matières » ? | Quatre matières par ligne au téléphone, six sur tablette et ordinateur ; Physique-Chimie s'écrit « PC » et Histoire-Géo « HG » sous l'icône (porteur, 2026-10-15). | Avec six matières, le téléphone montre une ligne de quatre puis une de deux. Les abréviations ne valent que pour la grille : le nom complet reste dans les listes (À faire, activités récentes) et pour les lecteurs d'écran. |
| Que dit le bouton de « Ma classe » ? | « Entrer en classe », avec l'icône d'une porte ouverte devant et la flèche après (porteur, 2026-10-15). | Demandé pour le téléphone ; le même libellé est repris sur tablette et ordinateur pour garder une seule clé de traduction. |
| Garde-t-on la barre d'onglets en bas du téléphone (Accueil, Cours, Ma classe) ? | Non, on la retire (porteur, 2026-10-15). | Au téléphone et sur tablette, ces trois liens passent en tête du menu de l'avatar, la page en cours en surbrillance ; sur ordinateur, le menu de gauche reste. À reporter dans l'UDR (amende UDR-0080). |
| Un chantier pour le dessin, un autre pour l'exercice du jour ? | Non : toute la phase en un seul chantier (PRD, ADR, UDR, plan par lots), le 2026-10-15, après avoir d'abord choisi de séparer. | Le chantier couvre le nouvel accueil, l'exercice du jour, le travail « fait seul » vu par l'enseignant et la direction, et « Inviter mon enseignant ». Une seule PR ; documents écrits ici, code dans une nouvelle session. |

## Cas limites identifiés

- Aucune matière de son niveau n'a d'exercice publié : rien à proposer, la carte ne garde que l'encouragement et l'invitation de l'enseignant.
- L'élève a fait tous les exercices publiés d'une matière : la matière est sautée dans le tour.
- Un travail de l'enseignant reste en retard des semaines : l'exercice proposé ne revient jamais tant qu'il n'est pas fait.
- L'élève est dans plusieurs classes de niveaux différents : le tour des matières porte sur l'union de leurs matières, comme son catalogue.
- Deux enfants partagent un téléphone : seule la photo (ou les initiales) les distingue sur l'accueil ; risque accepté.
- L'élève fait l'exercice proposé à 23 h 50 et le termine après minuit : il compte pour le jour où il a été commencé.

## Questions encore ouvertes

- **Rentrée, élève sans classe de la nouvelle année** : laissé de côté par le porteur (2026-10-15). On garde le comportement actuel (catalogue vide, invitation à rejoindre sa classe) tant qu'il n'est pas tranché.

## Questions fermées par défaut (à confirmer par le porteur)

- **Où apparaît le travail « fait seul »** : pour l'enseignant, une colonne « Fait seul (7 j) » dans la liste des élèves de la page de la classe ; pour la direction, un chiffre « Faits seul (7 j) » par niveau sur son accueil, à côté du taux de rendu. Rien dans les comptes d'un exercice donné. Voir UDR-0084 §3.7.
- **Message d'invitation de l'enseignant** : « Bonjour ! Je suis en %{classroom} à %{school}. Sur Lnclass, vous pouvez nous donner des exercices et suivre nos résultats. Inscrivez-vous ici : %{link} ». Le lien ouvre l'inscription enseignant existante (`/teacher-signup`) ; l'élève n'a pas de jeton de parrainage, l'établissement n'est donc pas prérempli. Voir ADR-0089 §4.3.
