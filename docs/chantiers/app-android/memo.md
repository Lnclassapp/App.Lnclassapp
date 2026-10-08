# Memo — App Android pour élèves et enseignants

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — **repris** le 2026-10-08 (porteur), app élèves d'abord |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `ccr-e4a51f57-9ve9og` *(branche imposée par la session ; `feature/app-android` selon la convention)* |
| **Programme** | — *(hors plan de `refonte-application` ; la PWA est livrée par `installation-pwa`, ADR-0082)* |

---

## Le problème

Lnclass n'existe que dans le navigateur. Un élève ou un enseignant qui cherche « Lnclass » sur le Play Store ne trouve rien, n'a pas d'icône sur son téléphone, et ne bénéficie d'aucune fonction du téléphone : ni vibration, ni partage natif, ni notification.

L'installation depuis le navigateur (PWA) qui donnerait au moins l'icône n'est pas branchée et reste au backlog (V4). Plusieurs plans antérieurs prévoyaient des applications en magasin (juin 2026, Turbo Native), sans qu'aucune ligne de code natif ne soit écrite.

## Pour qui

- **Élève**, sur un téléphone Android, souvent d'entrée de gamme et en 3G/4G : de l'installation depuis le Play Store jusqu'à la session d'exercice.
- **Enseignant**, sur un téléphone Android : suivi de ses classes et assignation du contenu.
- **Direction d'établissement** : reste sur la web app responsive, sans application.
- **Équipe** : reste sur le web ; voit l'usage des apps dans son pilotage.
- **Direction d'établissement**, côté usage : voit combien d'élèves et d'enseignants de son établissement utilisent l'app.

## Pourquoi maintenant

Pas d'urgence de livraison : le chantier est **cadré puis mis en attente** (décision du porteur, 2026-09-30). Le cadrer maintenant sert à fixer la stratégie mobile par écrit (Android d'abord, Hotwire Native, établissements sur le web, PWA et iOS plus tard) et à trancher tôt les décisions longues : compte Play Store, public mineur, paiement, version d'Android minimale. La décision est consignée dans l'[ADR-0070](../../decisions/adr/0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md) (proposé, en attente). PRD, UDR et plan s'écriront à la reprise.

## Hors périmètre

*Première version, à durcir pendant le grill.*

- Une application iOS.
- L'installation depuis le navigateur (PWA), qui reste au chantier `installation-pwa` de la V4.
- Une application pour la direction d'établissement ou pour l'équipe, et des notifications pour elles : **chantier de suivi** (porteur, grill du 2026-09-30).
- La notification de test envoyée par l'équipe : reportée au même chantier de suivi.
- Le rôle Parent, écarté du plan le 2026-09-22.
- Réécrire des écrans en natif : les écrans restent ceux du site.
- Le paiement dans l'application.
- Les notifications poussées et leur indicateur : chantier **`notifications-push`**, ouvert après celui-ci, qui reprend les réponses aux questions 5 à 11 du grill.

## Ce que le grill a révélé

> Rempli au fil du grill, une question à la fois.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Une app pour élèves et enseignants, ou deux ? | **Deux apps** : « Lnclass » pour les élèves, « Lnclass Teacher » pour les enseignants, comme le plan de juin | Deux fiches Play Store, deux identifiants d'application, deux coques à publier et à tenir à jour. Il faut décider ce que fait chaque app quand un compte de l'autre rôle s'y connecte |
| Un compte connecté dans l'app qui n'est pas la sienne (enseignant dans l'app élèves, élève dans l'app enseignants, direction ou équipe dans l'une ou l'autre) ? | **Refuser et rediriger** : message qui nomme la bonne app avec un lien vers sa fiche Play Store ; direction et équipe renvoyées vers le site | Le serveur doit savoir de quelle app vient la requête et en tenir compte à la connexion : c'est une règle d'identité nouvelle, pas seulement un affichage. Le refus n'intervient **qu'après** un PIN correct, sinon l'app révèle le rôle d'un numéro à n'importe qui |
| L'inscription se fait-elle dans les apps, et où s'ouvre un lien de classe reçu sur WhatsApp ? | **Inscription dans chaque app pour son rôle ; les liens s'ouvrent dans l'app installée**, sinon dans le navigateur | Le site doit publier une déclaration d'association de domaine pour les deux apps, et chaque lien a une app propriétaire : lien ou code de classe → app élèves ; lien de parrainage entre enseignants et inscription par code d'établissement → app enseignants ; invitation de direction ou d'équipe → navigateur. Un lien ouvert dans la mauvaise app retombe sur la règle de la question 2 |
| Un élève dont le téléphone est trop ancien pour l'app (le site accepte Android 6, ADR-0051) ? | **Le site reste le repli complet et la référence** ; l'app vise la version minimale de Hotwire Native | **Aucune fonction n'est réservée à l'app** : tout ce que l'app fait doit exister sur le site, en moins confortable. La version minimale exacte est à mesurer avant l'ADR ; le budget de poids de l'ADR-0051 continue de s'appliquer aux pages, qui sont les mêmes dans l'app |
| Quelles fonctions natives dans la première version, alors que le site n'a pas de notifications ? | **Avec notifications poussées (FCM)**, en exception assumée à la règle précédente : un élève sur le site ne les reçoit pas | Le chantier traverse un second contexte (`communication`) : enregistrement de l'appareil de chaque compte, envoi par un service externe (Firebase, compte Google, clé secrète), désinscription. Il faut un ADR (nouvelle dépendance, nouvelle table, nouveau port) et un amendement de l'ADR-0045, qui exclut aujourd'hui toute notification hors de l'application. Le chantier `canal-whatsapp` et celui-ci doivent se répartir les messages. Le consentement d'élèves mineurs devient une question |
| Quels événements notifient dans la première version ? | **Les quatre** : nouvelle assignation (élèves de la classe), élève qui rejoint la classe (enseignant), résultats d'exercice (enseignant), rappel d'exercice non terminé (élève) | Les déclencheurs vivent dans trois contextes (`classroom` pour l'assignation et l'adhésion, `assessment` pour la clôture de session, un job planifié pour les rappels) mais l'envoi reste dans `communication`. Deux événements peuvent exploser en volume (une classe de 80 élèves qui rejoint en septembre, 80 résultats d'un même exercice) : il faut une règle de regroupement. Le rappel exige une règle d'heure et de fréquence. Le périmètre de la première version grossit nettement |
| Quelle règle de volume et d'horaire (80 élèves qui rejoignent ou terminent le même exercice) ? | **Résumés et horaires** : l'enseignant reçoit un résumé par classe et par jour ; l'élève reçoit l'assignation tout de suite et au plus un rappel par jour, entre 17 h et 20 h ; rien entre 21 h et 7 h (heure d'Abidjan) | Un envoi différé et groupé, donc un job quotidien et une file d'attente des événements à résumer. Une assignation faite à 22 h part à 7 h. Le rappel s'arrête dès que l'exercice est terminé ou que l'assignation est archivée. Pas d'écran de préférences : l'utilisateur coupe les notifications par les réglages Android |
| Un téléphone partagé (deux frères, ou une mère enseignante et son fils) : à qui vont les notifications ? | **Au dernier compte connecté dans chaque app** : la déconnexion désinscrit l'appareil, la connexion suivante le réinscrit | L'inscription de l'appareil suit la session, pas le compte. Tout ce qui ferme une session doit aussi désinscrire l'appareil : déconnexion, changement de PIN ou de numéro qui ferme les autres sessions (ADR-0055), compte désactivé ou anonymisé. Un appareil que le service d'envoi déclare invalide est supprimé. La mère et le fils, chacun dans son app, ne se gênent pas |
| Âge des élèves, et politique « Familles » du Play Store (public de moins de 13 ans) ? | **Les élèves ont 14 ans et plus** en Côte d'Ivoire (porteur) | L'app élèves se déclare pour un public de 13 ans et plus : la politique « Familles » ne s'applique pas. Les élèves restent en partie mineurs (14 à 17 ans) : politique de confidentialité et déclaration des données collectées (numéro, appareil pour les notifications) restent obligatoires sur la fiche |
| Que montre une notification sur l'écran verrouillé d'un téléphone partagé ? | **Sobre** : ni nom d'élève ni note (« Nouvel exercice en Maths », « 34 résultats sur Fonctions — 2nde C ») ; le détail s'affiche dans l'app | Les textes de notification sont des gabarits fermés, traduits, sans donnée personnelle. Un test vérifie qu'aucun nom ni score n'entre dans le texte envoyé au service externe, qui n'en voit donc jamais |
| La session expire après 30 jours d'inactivité (ADR-0050) : l'élève décroché ne reçoit plus de rappels ? | **L'appareil reste inscrit jusqu'à une déconnexion volontaire**, un changement de PIN ou de numéro, ou un compte désactivé ; toucher la notification ramène à la connexion si la session a expiré | Précise la question 8 : l'inscription de l'appareil suit la **connexion**, pas la durée de session. Durées de session de l'ADR-0050 inchangées. Il faut un plafond de rappels par assignation, sinon un élève parti reçoit un rappel par jour indéfiniment |
| L'équipe et la direction, sans app, voient-elles quelque chose ? | **Oui, trois choses** : l'équipe voit dans son pilotage le nombre de comptes connectés par chaque app et de notifications envoyées, et peut s'envoyer une notification de test ; la direction voit combien d'élèves et d'enseignants de son établissement utilisent l'app. **Des notifications et des apps pour l'équipe et la direction : un autre chantier** | Chaque connexion doit retenir l'app d'où elle vient (même détection que la question 2), pour compter l'usage. Le pilotage de l'équipe (ADR-0062) et l'espace direction en lecture seule (ADR-0065) gagnent un indicateur : amendements et UDR à écrire. L'envoi de test exige un appareil inscrit pour un compte équipe, alors que l'équipe n'a pas d'app : tranché à la question suivante |
| Vers quoi part la notification de test de l'équipe, qui n'a pas d'app et est refusée dans les deux ? | **Reportée** au chantier de suivi (apps et notifications de l'équipe) | L'équipe garde ses deux indicateurs (comptes par app, notifications envoyées) ; la vérification de l'envoi en recette se fait avec les comptes de recette élève et enseignant, sans écran dédié |
| Le chantier (deux apps, liens, notifications, indicateurs) tient-il dans une seule PR ? | **Non : deux chantiers.** `app-android` : les deux apps, la connexion par app, l'inscription et les liens, les indicateurs d'usage. Puis `notifications-push` : le service d'envoi, les quatre événements, les résumés et les horaires | Les réponses aux questions 5 à 11 deviennent le point de départ du memo de `notifications-push`, qui aura son ADR (service externe, table des appareils) et l'amendement de l'ADR-0045. L'indicateur « notifications envoyées » de l'équipe part avec lui. `app-android` n'ajoute plus de service externe côté serveur |
| Avec quel compte Google Play publier ? | **Un compte d'organisation** au nom de la société Lnclass | Il faut un numéro D-U-N-S, dont le délai d'obtention est variable : à demander dès la reprise du chantier, avant tout code. Nom d'éditeur « Lnclass » sur les deux fiches ; pas de test fermé imposé par Google, mais une recette sur téléphones réels reste exigée par ce chantier. Les clés de signature des deux apps appartiennent à ce compte |

### Reprise du 2026-10-08 — l'app élèves d'abord

> Le porteur reprend le chantier après la livraison de la PWA, avec un objectif : l'app élèves, de la connexion aux exercices, en une journée de travail. Les questions sont posées en une fois, à sa demande.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Première version : l'app élèves seule ? | **Oui** : « Lnclass » d'abord, « Lnclass Teacher » ensuite | Une seule coque, un seul identifiant d'application. Le refus par rôle (question 2) ne vise qu'un sens : enseignant, direction et équipe dans l'app élèves |
| Toutes les pages de l'élève, ou seulement connexion et exercices ? | **Toutes** | L'app affiche les pages du site : rien à réécrire, mais toutes les pages élève sont à vérifier dans la coque |
| Inscription par code de classe dans l'app ? | **Oui** | Les liens `/c/:code` et `/join` s'ouvrent dans l'app (question 3) |
| Avant le Play Store, l'APK par WhatsApp à des testeurs ? | **Oui, 5 à 10 élèves** sur des Android d'entrée de gamme | Une version signée « test » distribuable hors magasin ; une liste de testeurs à tenir |
| D-U-N-S demandé ? | **Pas encore** ; la société n'est pas créée (2026-10-08) | Le D-U-N-S attend la création de la société ; il ne bloque ni le code ni le test fermé |
| Nom, icône, identifiant | **« Lnclass »**, baobab sur bleu (icônes validées le 2026-10-08), **`com.lnclass.student`** | L'identifiant est définitif dès la première publication |
| Les onglets en bas de l'app ? | *(complété par la ligne « Barres natives » plus bas)* D'abord « aucun onglet, tout dans un panneau ouvert par l'avatar », puis **corrigé le même jour : on garde la barre du bas** ; l'en-tête change : **l'avatar à gauche, à la place du logo ; à droite, des icônes et « Besoin d'aide ? », à la place de l'avatar ; plus de logo dans la barre du haut** | Change l'en-tête du shell (UDR-0006) : une UDR est obligatoire. Contredit la règle du design system qui place le logo à gauche de l'en-tête et l'identifie sur les captures partagées sur WhatsApp : à assumer dans l'UDR. Restent à trancher : app seule ou site aussi, quelles icônes à droite, et ce que l'avatar ouvre |
| En-tête : pour qui, quelles icônes à droite, que fait l'avatar ? | **App et site** pour l'élève. À droite, l'icône d'aide actuelle (`question-mark-circle`) avec « Besoin d'aide ? », puis l'interrupteur clair/sombre, rien d'autre. **L'avatar ouvre un panneau latéral** venant de la gauche : nom, classe, Profil, déconnexion. Le logo quitte l'en-tête (le porteur n'a pas retenu l'alternative proposée) | Une UDR de l'en-tête élève (amende l'UDR-0006 et l'UDR-0065) et un panneau latéral à construire, partagé par le site et l'app : c'est du code Rails, pas de la coque. L'interrupteur de thème, aujourd'hui caché sous `lg`, devient visible sur téléphone. Le chantier gagne un lot « en-tête » côté site, qui peut partir avant la coque |
| Dans l'app, l'affichage natif ? | **Barres natives Android** : l'en-tête et la barre basse du site sont cachés dans l'app, qui affiche sa propre barre d'onglets en bas (Accueil, Cours, Ma classe) et sa barre en haut. Le site garde le nouvel en-tête | Retour à la note « Layout » de l'ADR-0070. Le nouvel en-tête du site et la barre native de l'app sont deux surfaces distinctes, toutes deux à décrire dans l'UDR. Reste à fixer ce que porte la barre native du haut (titre, avatar, aide) |
| Le compte Play Store, alors que la société n'existe pas ? | **Compte personnel** jusqu'à la création de la société | Pas de D-U-N-S possible avant : ADR-0070 R6 remplacée. Test fermé obligatoire (12 testeurs, 14 jours) |
| Barre native du haut, panneau de l'avatar, exercice, autres rôles | **Barre du haut** : l'avatar à gauche, « Besoin d'aide ? » à droite. **Panneau de l'avatar** : nom et classe, thème clair/sombre, Profil, Cours, déconnexion. **Pendant un exercice**, la barre d'onglets est cachée. **Le nouvel en-tête du site ne vaut que pour l'élève** ; les autres rôles gardent l'en-tête actuel | Le panneau est une page du site (servie à l'app comme au navigateur), ouverte par l'avatar natif de l'app ou par celui du site : un seul contenu. Le shell (UDR-0006) prend une variante d'en-tête par rôle. La coque cache ses onglets sur le chemin des sessions d'exercice (règle de la configuration des chemins) |
| Un enseignant dans l'app élèves ? | **Message « Utilisez Lnclass Teacher »**, lien vers le site tant que l'app enseignants n'existe pas | Règle d'identité de la question 2, côté app élèves seulement |
| La pop-up « Installer Lnclass » dans l'app ? | **Jamais** | Le contrôleur `install` se tait quand la page tourne dans l'app (User-Agent de la coque) : amendement de l'UDR-0078 |
| Recette avant production ? | **Oui** : une version qui pointe vers la recette, puis une vers la production | Deux variantes de compilation (adresse du site), même code |
| Version minimale d'Android | **Android 7** (minimum de Hotwire Native) | Les téléphones plus anciens restent sur le site, qui garde toutes les fonctions (question 4) |
| Clé de signature | **Play App Signing** ; une clé de secours chez le porteur, jamais dans le dépôt | La clé d'envoi ne vit ni dans le code ni dans la CI sans secret |
| Mesure | **Oui** : l'équipe voit les élèves qui utilisent l'app, à côté du chiffre de la PWA | La tuile « Ouvert depuis l'app installée » (ADR-0082) gagne l'origine « app Android » |
| Compte Play Store | **Compte personnel tout de suite**, test fermé de 14 jours avec 12 élèves au moins ; passage en compte d'organisation à l'arrivée du D-U-N-S | Remplace la réponse « compte d'organisation d'abord » (ligne précédente) : le test fermé de 14 jours devient la recette sur téléphones réels |
| Où développer et tester ? | **APK compilé ici**, testé par le porteur ; guide pour Android Studio et le téléphone en USB | Les livrables de chaque lot incluent un APK et ses étapes d'installation |

## Cas limites identifiés

- Un enseignant ou un élève qui se connecte dans l'app de l'autre rôle : refusé **après** un PIN correct, jamais avant, pour ne pas révéler le rôle d'un numéro.
- Un compte direction ou équipe qui se connecte dans une app : refusé, renvoyé vers le site.
- Un lien de classe ouvert alors que seule l'app enseignants est installée : il s'ouvre dans le navigateur, pas dans la mauvaise app.
- Un lien reçu avant l'installation de l'app : il s'ouvre dans le navigateur, le parcours reste complet.
- Un téléphone trop ancien pour l'app : l'élève reste sur le site, qui garde toutes les fonctions.
- Un enseignant équipé d'un iPhone : il reste sur le site ; aucune app iOS dans ce chantier.
- Un élève rattaché à plusieurs classes, un enseignant de plusieurs établissements : l'app montre exactement ce que montre le site, puisqu'elle affiche les mêmes pages ; aucune règle propre à l'app.
- Une mise à jour d'écran côté site apparaît dans l'app sans nouvelle publication ; une modification de la coque (onglets, icône, liens déclarés) exige une nouvelle version sur le Play Store.
- Une connexion dans l'app puis dans le navigateur du même téléphone : deux sessions distinctes, chacune comptée à son origine dans les indicateurs.
- Un compte anonymisé ou désactivé alors qu'il est connecté dans l'app : la session tombe, l'app revient à la connexion.

## Questions encore ouvertes

- ~~Le nouvel en-tête vaut-il pour les autres rôles ?~~ Non : élève seulement (porteur, 2026-10-08).
- Sans logo dans l'en-tête, une capture d'écran partagée sur WhatsApp ne porte plus la marque : à confirmer à la relecture des captures.

- Version minimale d'Android exigée par Hotwire Native Android et par la vue web système : à mesurer, puis à comparer au plancher de l'ADR-0051.
- Délai d'obtention du numéro D-U-N-S et structure juridique qui porte le compte Google Play.
- Comment le serveur reconnaît-il chaque app de façon fiable (l'en-tête d'identification se falsifie) ? Le refus de la question 2 n'est pas une barrière de sécurité, seulement un aiguillage : à écrire dans l'ADR.
- Définition exacte d'un « utilisateur de l'app » pour les indicateurs (connecté au moins une fois, ou actif dans les 30 derniers jours).
- Onglets natifs de chaque app : quelles destinations du shell de chaque rôle (UDR-0006) deviennent des onglets.
- Nom, icône et couleurs des deux apps (le plan de juin proposait un fond bleu pour les élèves, blanc pour les enseignants).
- Le paiement : aucune fonction payante dans l'app ; si un accès payant revient, la facturation de Google Play est à étudier avant.
