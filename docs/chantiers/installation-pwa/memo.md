# Memo — Installer Lnclass sur le téléphone (PWA)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-07 |
| **Branche** | `ccr-e4a51f57-9ve9og` *(branche imposée par la session ; `feature/installation-pwa` selon la convention)* |
| **Programme** | `refonte-application`, vague V4 (ID-26, TR-24, TR-25), avancée à la demande du porteur le 2026-10-07 |

---

## Le problème

Lnclass ne vit que dans un onglet du navigateur. Pour revenir faire un exercice, un élève doit rouvrir son navigateur, retrouver l'adresse ou le lien reçu sur WhatsApp, et la page s'affiche avec la barre d'adresse du navigateur. Il n'a aucune icône Lnclass sur son écran d'accueil.

Le navigateur sait pourtant installer un site comme une application (icône, plein écran, nom « Lnclass »). Chez Lnclass, cette installation n'est pas branchée : la fiche d'application du site est celle laissée par le générateur (nom « AppLnclassapp », couleur rouge), elle n'est pas déclarée dans les pages, et le programme qui permet au navigateur de reconnaître une application est vide. L'ancienne application proposait un bandeau d'installation, mais il enregistrait « installée » sur iPhone sans rien installer et acceptait n'importe quelle valeur.

## Pour qui

- **Élève**, sur un téléphone Android d'entrée de gamme, en 3G/4G : retrouver Lnclass en un geste depuis son écran d'accueil, entre deux exercices.
- **Enseignant**, sur téléphone : ouvrir ses classes sans passer par le navigateur.
- **Direction d'établissement** et **équipe** : peuvent installer par le menu du navigateur, sans être invitées par un bandeau.
- **Équipe**, dans son pilotage : voit si l'installation prend, par rôle.
- **Visiteur non connecté** : aucun bandeau sur les pages publiques ; il peut installer par le menu du navigateur.
- **Parent** : rôle écarté du plan depuis le 2026-09-22.

## Pourquoi maintenant

Le porteur a vu qu'on peut « avoir son app sur le téléphone » et choisit, le 2026-10-07, la voie la plus courte : rendre le site installable, avant les apps Android du chantier `app-android` (en attente). Aucun compte de magasin, aucun délai de validation, et les écrans restent ceux du site.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- **Les exercices hors ligne** : chantier **`exercices-hors-ligne`**, ouvert après celui-ci, qui reprend les réponses aux questions 1 à 6 du grill. Ici, sans réseau, l'élève voit la page « Pas de connexion ».
- Garder sur le téléphone une page de compte (accueil, leçons, résultats) pour la relire hors ligne.
- Les apps Android publiées sur le Play Store (chantier `app-android`, en attente).
- Les notifications poussées (chantier `notifications-push`).
- Réécrire ou adapter des écrans pour l'application installée : ce sont les pages du site.
- Un bandeau d'installation pour la direction, l'équipe ou les visiteurs.
- Mémoriser le choix « Plus tard » sur le compte : il vit sur le téléphone.
- Une app pour iPhone autre que l'installation par Safari.

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Sans réseau, que peut faire l'élève dans l'app installée ? | **Faire des exercices hors ligne**, envoyés au retour du réseau (porteur) | Le chantier change de taille : il faut un ADR (stockage sur le téléphone, envoi différé, budget de poids de l'ADR-0051) et un amendement de l'ADR-0054, qui corrige chaque question **sur le serveur** au moment où elle est soumise. Le contexte `assessment` porte la règle. La question Q10 de la feuille de route est tranchée |
| Hors ligne, qui corrige ? Corriger sur le téléphone exige d'y mettre les bonnes réponses, lisibles par un élève | **Correction au retour du réseau** : l'élève répond sans savoir si c'est juste, ses résultats arrivent à la reconnexion (porteur sans préférence, option recommandée retenue) | Les bonnes réponses ne quittent jamais le serveur : la règle de l'ADR-0054 (aucune bonne réponse servie à l'élève avant sa tentative) tient. Le serveur reste seul juge : il reçoit un lot de réponses et le rejoue question par question, dans l'ordre. Hors ligne, l'écran de question n'affiche plus « juste » ni « faux » : une vue nouvelle ou un état nouveau, donc UDR |
| Quels exercices le téléphone garde-t-il, sachant que les données sont payées par la famille ? | **Les exercices assignés et non terminés**, téléchargés automatiquement (porteur) | Aucun bouton à ajouter, aucun choix demandé à l'élève. Un exercice de fiche ouvert librement depuis le catalogue ne marche pas hors ligne. Les exercices sont du texte seul (ni image ni son) : le poids reste faible, mais il faut un plafond chiffré dans l'ADR. Le téléchargement suit la liste d'assignations de l'élève : une assignation archivée ou un exercice terminé sort du téléphone |
| Téléphone partagé : Awa a des réponses non envoyées, son frère veut se connecter sur le même téléphone | **Les réponses d'Awa restent en attente** et partent à son nom (porteur) | Se connecter et se déconnecter exigent le réseau (le PIN est vérifié par le serveur) : la déconnexion **envoie d'abord** les réponses en attente. Si l'envoi échoue, elles restent sur le téléphone, rangées au nom d'Awa, et partent à sa prochaine connexion. **Aucune clé d'envoi ne survit à la déconnexion** : une session fermée ne peut plus rien envoyer, sinon la révocation des sessions (ADR-0055) ne vaut plus rien. Le frère ne voit jamais les exercices ni les réponses d'Awa à l'écran ; elles restent cependant lisibles par quelqu'un qui fouille le stockage du navigateur (coût à écrire dans l'ADR). Le contexte `identity` est touché |
| Réponses faites hors ligne avant la date limite, reçues après (ou après l'archivage de l'assignation) ; l'heure du téléphone se falsifie | **Comptées, datées de leur réception** par le serveur (porteur) | L'heure du téléphone n'est jamais crue : elle peut être gardée pour information, jamais pour décider. Un rendu reçu après la date limite apparaît en retard chez l'enseignant. Une assignation archivée entre-temps n'empêche pas l'envoi : la session compte comme un entraînement de l'élève, hors de l'assignation (ADR-0048 à relire : ce que devient le lien de la session vers l'assignation archivée) |
| Exercice commencé en ligne (3 réponses sur 10), refait en entier hors ligne sur le téléphone | **Le premier arrivé gagne** : les réponses déjà enregistrées restent, le téléphone complète les autres, ses doublons sont ignorés et montrés à l'élève (porteur) | La règle de l'ADR-0054 (une réponse par question et par session, immuable) ne bouge pas. Le lot hors ligne se rejoue question par question dans la session ouverte : un doublon donne le refus « déjà répondu » existant, que l'envoi traite comme normal et non comme une erreur. Si la session en ligne a été terminée ou recommencée entre-temps, le lot ouvre ou complète la session ouverte du moment. L'écran de résultat après envoi distingue « envoyée » et « déjà répondue avant » : UDR |
| Qui voit l'invitation à installer ? | **Élèves et enseignants** connectés sur téléphone ; direction et équipe peuvent installer par le menu du navigateur, sans bandeau ; pas de bandeau sur les pages publiques (porteur) | Le bandeau vit dans le shell des deux rôles (UDR-0006) : collision avec tout chantier qui touche le shell, à vérifier au plan. La fiche d'application (nom, icône, couleurs) vaut pour tous : n'importe qui peut installer. L'enseignant n'a aucun hors-ligne : sans réseau, il voit la page « Pas de connexion ». Les exercices hors ligne ne sont téléchargés que pour un compte élève |
| Sur iPhone, aucun bouton ne peut installer : que montre le bandeau ? | **Un mode d'emploi en deux étapes** (« Partager », puis « Sur l'écran d'accueil ») ; l'app n'est tenue pour installée que lorsqu'elle s'ouvre réellement depuis l'écran d'accueil (porteur) | Corrige le défaut de l'ancien bandeau (ID-26 : « installée » enregistré sur iOS sans installation). « Installée » ne se déduit que d'un signal réel : ouverture en mode application, ou événement d'installation du navigateur sur Android. Le hors-ligne vaut aussi sur iPhone, avec un risque à écrire dans l'ADR : Safari peut effacer le stockage d'un site, d'où l'intérêt d'envoyer les réponses dès que le réseau revient |
| « Plus tard » : quand le bandeau revient-il, et pour quel appareil ? | **3 jours plus tard, sur ce téléphone seulement**, sans rien enregistrer sur le serveur (porteur ; 7 jours d'abord, ramené à 3 jours le 2026-10-07, comme l'ancienne application) | Les colonnes de bandeau prévues sur les comptes par la feuille de route (`install_banner_status`, ID-26, TR-25) **ne sont pas créées** : l'installation est une affaire d'appareil. Le bandeau n'a ni table ni route serveur ; un stockage du navigateur absent ou vidé fait simplement réapparaître le bandeau. La feuille de route est à amender |
| Installer (quelques jours) et exercices hors ligne (plusieurs semaines) : ensemble ou séparément ? | **Deux chantiers, installation d'abord** (porteur) | `installation-pwa` livre : la fiche d'application, le programme d'arrière-plan minimal, la page « Pas de connexion », le bandeau Android et iPhone. Le nouveau chantier **`exercices-hors-ligne`** suit, avec son ADR et l'amendement de l'ADR-0054 ; il reprend les réponses des questions 1 à 6 comme point de départ de son memo. Dans `installation-pwa`, **aucune page de compte n'est gardée sur le téléphone** et l'élève sans réseau voit la page « Pas de connexion », comme l'enseignant |
| L'équipe veut-elle savoir si l'installation prend ? | **Oui, dans son pilotage** : la part des comptes actifs qui ouvrent Lnclass depuis l'app installée, par rôle, mesurée côté serveur (porteur) | Aucun traceur, aucun cookie de plus (ADR-0049) : le serveur repère l'ouverture depuis l'icône (adresse de départ propre à l'app installée) et le note sur la session de connexion. C'est une donnée nouvelle sur une table existante : ADR. Le pilotage de l'équipe (ADR-0062, UDR-0049) gagne un indicateur : amendement et UDR. Le contexte `identity` porte la marque, la query de pilotage la lit |

## Cas limites identifiés

- Sur Android, l'app installée et le navigateur partagent la même connexion : se déconnecter dans l'un déconnecte l'autre. Une session ouverte dans le navigateur puis reprise depuis l'icône est comptée comme ouverte depuis l'app.
- Un élève qui ouvre l'app sans réseau voit la page « Pas de connexion » de Lnclass, jamais l'erreur du navigateur ; quand le réseau revient, « Réessayer » recharge la page demandée.
- Une page de compte (accueil, résultats d'un élève, code à usage unique) n'est jamais gardée sur le téléphone : sur un téléphone partagé, le frère d'Awa ne retrouve rien d'elle hors ligne.
- Un navigateur qui ne sait pas installer (ancienne version, navigateur intégré de Facebook ou WhatsApp) : pas de bandeau Android ; le site marche comme avant.
- Un navigateur sans stockage (navigation privée, données effacées) : le bandeau réapparaît, sans erreur.
- L'app déjà installée et ouverte depuis l'icône : jamais de bandeau.
- L'utilisateur désinstalle l'app : le navigateur ne le dit pas au site ; le bandeau revient à sa visite suivante dans le navigateur.
- Une mise à jour du site apparaît dans l'app installée sans rien réinstaller ; un changement de l'icône ou du nom peut mettre plusieurs jours à apparaître sur l'écran d'accueil.
- Le gabarit du shell est aussi touché par d'autres chantiers : un seul propriétaire à la fois (feuille de route, tableau de collision de la V4).

## Questions encore ouvertes

- ~~Définition exacte de l'indicateur~~ : tranchée à la décision (ADR-0082 §4.4) : le nombre de comptes, par rôle, qui ont ouvert l'app installée sur la période du pilotage.
- ~~Couleur de la barre d'état~~ : tranchée (ADR-0082 §4.1) : le bleu de marque `#00a0ff` pour tous les rôles.
- ~~ADR-0070 à amender~~ : fait (amendement du 2026-10-07).
- Le bandeau doit-il attendre une deuxième visite avant de s'afficher, pour ne pas gêner la toute première session d'un élève ?
