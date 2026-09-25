# PRD — Boucle pédagogique (V1)

> Les specs sont figées ici. Toute évolution après la phase 3 modifie explicitement ce fichier.
> Ce PRD **hérite** du [PRD cadre](../refonte-application/prd.md) : matrice des permissions, exigences transverses, critères §5. En cas de contradiction, le PRD cadre gagne, sauf décision contraire consignée dans un ADR ou une UDR.
> Chaque critère porte l'ID d'inventaire de la feature ([feuille de route §6](../refonte-application/feuille-de-route.md#6-traçabilité--chaque-feature-de-lexistant-a-une-vague)). Le lot qui l'implémente est donné dans la traçabilité de [`plan.md`](plan.md).

## 1. Contexte

L'équipe publie un cours, ses fiches et leurs exercices, puis crée les classes des établissements. Un enseignant s'inscrit, déclare ses classes et leur assigne du contenu. Un élève rejoint sa classe par code, fait l'exercice assigné, voit la correction, son résultat et son badge.

La V1 pose aussi le socle des vagues suivantes :

- toutes les tables de la boucle ;
- les contrats de port ;
- l'authentification avec limite de débit, rotation de session, TOTP pour l'équipe et récupération assistée du PIN ;
- le shell par rôle.

## 2. Acteurs et permissions

Les policies sont des objets de domaine. Chacune est injectée dans le use case et appelée en premier. Un refus renvoie `:forbidden`, que le contrôleur traduit en 403 ou en redirection accompagnée d'un toast (ADR-0028). Le compte équipe dont le second facteur n'est pas vérifié n'atteint aucune policy : le socle d'authentification le bloque avant.

| Capacité (V1) | Visiteur | Student | Teacher | Team | Policy |
|---|---|---|---|---|---|
| S'inscrire comme élève avec un code de classe | ✅ | — | — | — | `Classroom::JoinPolicy` |
| S'inscrire comme enseignant | ✅ | — | — | — | — (use case public, rôle imposé par le serveur) |
| Accepter une invitation équipe | ✅ *avec le lien* | — | — | — | — (jeton à usage unique) |
| Inviter un membre de l'équipe | — | — | — | ✅ | `Identity::InviteTeamPolicy` |
| Générer un code de récupération de PIN | — | — | ✅ *élève de sa classe* | ✅ *tout compte sauf le sien* | `Identity::AssistPinRecoveryPolicy` |
| Voir le catalogue publié (cours, fiches, exercices) | — | ✅ | ✅ | ✅ *brouillons et archives compris* | `Catalog::ReadPublishedPolicy` |
| Créer, modifier, archiver un cours, une fiche ou un exercice | — | — | — | ✅ | `Catalog::ManageContentPolicy` |
| Voir les bonnes réponses hors correction | — | — | ✅ *exercice assigné à une de ses classes* | ✅ | `Assessment::RevealAnswersPolicy` |
| Démarrer ou reprendre une session | — | ✅ *exercice publié et assigné à sa classe* | — | — | `Assessment::StartSessionPolicy` |
| Répondre, clôturer, voir le résultat | — | ✅ *sa session* | ✅ *voir : élève de sa classe* | ✅ *voir* | `Assessment::ReadSessionPolicy` |
| Ouvrir une classe | — | ✅ *la sienne* | ✅ *s'il y enseigne* | ✅ | `Classroom::AccessPolicy` |
| Voir la liste nominative et le code d'une classe | — | — | ✅ *s'il y enseigne* | ✅ | `Classroom::ReadRosterPolicy` |
| Déclarer les classes qu'on enseigne | — | — | ✅ *de son école principale* | — | `Classroom::TeachPolicy` |
| Assigner / retirer une ressource | — | — | ✅ *s'il y enseigne* | ✅ | `Classroom::AssignPolicy` |
| Créer une classe | — | — | — | ✅ | `School::ManageSchoolPolicy` |

Écart assumé avec le PRD cadre : l'élève ne voit **pas** le code de sa classe dans la V1. Il l'a déjà utilisé, et le partage revient à l'enseignant (CL-05, V3). La ligne « Ouvrir une classe (… code d'adhésion) » du cadre est donc découpée en deux policies.

## 3. Parcours utilisateur

### Chemin nominal

1. L'équipe se connecte avec son numéro, son PIN et son code TOTP. Elle crée le cours « Génétique et évolution » (Tle D, SVT), une fiche et un exercice de 2 questions, et publie les trois.
2. L'équipe crée la classe « Tle D 1 » au Lycée Classique d'Abidjan. Le code `KFM37` s'affiche.
3. Un enseignant s'inscrit : DRENA Abidjan 1, Lycée Classique d'Abidjan, SVT. Il arrive sur « Quelles classes enseignez-vous ? », coche « Tle D 1 » et termine sa configuration.
4. Il ouvre « Tle D 1 », puis le cours, puis la fiche, et assigne l'exercice. Le bouton passe à « Assigné ».
5. Un élève ouvre `/c/KFM37`, voit « Tle D 1 — Lycée Classique d'Abidjan », remplit Nom, Prénom(s), genre, numéro et PIN, puis arrive sur son accueil : « Bienvenue sur Lnclass ! ».
6. Sur son accueil, il voit l'exercice assigné et le démarre. Il répond aux 2 questions, avec une correction immédiate après chacune.
7. Il termine et voit sa note (2/2), son pourcentage (100 %) et son badge « Or ». Les confettis s'affichent.
8. L'enseignant voit la session de l'élève. L'élève ne voit jamais les bonnes réponses avant d'avoir répondu.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code de classe inconnu sur `/c/<code>` | Redirection vers l'inscription élève, toast « Code de classe invalide. » |
| Numéro déjà utilisé à l'inscription | Formulaire réaffiché en 422 avec « Ce numéro est déjà utilisé. » |
| 6e échec de connexion en une minute pour un même numéro | Refus sans vérifier le PIN, message « Trop de tentatives. Réessayez dans une minute. », événement journalisé |
| Enseignant sans configuration terminée | Toute page enseignant redirige vers la déclaration des classes, qui s'affiche sans jamais rediriger |
| Enseignant sans école principale | Écran de sortie « Votre établissement n'est pas encore rattaché » avec le bouton Déconnexion. Aucune redirection. |
| Élève sans classe principale | Écran de sortie « Vous n'êtes rattaché à aucune classe. Demandez le code de votre classe à votre enseignant. » avec le bouton Déconnexion. Aucune redirection. |
| Réponse vide | 422 dans le cadre de la question, « Veuillez sélectionner au moins une réponse. » |
| Question déjà répondue soumise à nouveau | Rien n'est écrit. Redirection vers la question suivante, toast « Question déjà répondue. » |
| Brouillon ouvert par URL par un non-équipe | 404 : le brouillon n'existe pas pour lui |
| Ressource d'une autre classe | 403 et toast « Accès interdit. », aucune donnée de la classe dans la réponse |

## 4. Critères d'acceptation

Chaque bloc devient au moins un test, écrit avant le code et rouge d'abord. Les messages entre guillemets sont des valeurs de la locale `fr`. Le test les compare par la clé `t()`, jamais par une chaîne en dur dans le test.

### 4.1 Critères transverses de la porte V1 (PRD cadre §5, repris tels quels)

```gherkin
Scénario: [TR-cadre-1] Aucun rôle privilégié par l'inscription
  Étant donné un visiteur sur le formulaire d'inscription élève
  Quand il soumet le formulaire avec un paramètre role=team ou role=school_admin ajouté à la main
  Alors le compte créé a le rôle student
  Et aucun compte team ni school_admin n'existe

Scénario: [TR-cadre-2] Verrouillage après 5 échecs
  Étant donné un compte au numéro 0700000001
  Quand 5 connexions échouent en moins d'une minute pour ce numéro
  Alors la 6e tentative est refusée même avec le bon PIN
  Et un événement "login_locked" est écrit dans le journal d'audit

Scénario: [TR-cadre-3] Aucune bonne réponse servie à un élève
  Étant donné le cache de fragments actif
  Et un enseignant qui a affiché l'exercice « Méiose » avec ses bonnes réponses
  Quand un élève de sa classe affiche le même exercice
  Alors le HTML reçu ne contient aucun marqueur de bonne réponse ni l'identifiant d'une réponse correcte

Scénario: [TR-cadre-4] Un enseignant hors de la classe est refusé
  Étant donné un enseignant qui n'enseigne pas en 3ème B
  Quand il ouvre la page de la 3ème B
  Alors il reçoit un refus
  Et la réponse ne contient ni le code d'adhésion ni un nom d'élève de la 3ème B

Scénario: [TR-cadre-5] L'équipe ne passe pas sans second facteur
  Étant donné un compte team qui a saisi le bon numéro et le bon PIN
  Et qui n'a pas encore validé son code TOTP
  Quand il ouvre l'accueil équipe
  Alors il est redirigé vers la saisie du code TOTP

Scénario: [TR-cadre-6] Archiver ne détruit pas l'historique
  Étant donné un exercice qui a 3 sessions terminées, leurs tentatives et 2 badges
  Quand l'équipe l'archive
  Alors les 3 sessions, leurs tentatives et les 2 badges existent toujours
  Et l'exercice n'apparaît plus dans les listes des élèves
```

### 4.2 Identity

```gherkin
Scénario: [ID-01] S'inscrire comme élève avec un code
  Étant donné la classe « 6ème 1 » de code kfm37
  Quand un visiteur soumet Nom « Kouassi », Prénom(s) « Aya Marie », genre féminin, numéro « 07 01 02 03 04 », PIN « 4821 », code « KFM37 »
  Alors un compte student existe avec le numéro 0701020304
  Et il est membre principal de « 6ème 1 », avec une date d'adhésion
  Et il est connecté et arrive sur son accueil avec « Bienvenue sur Lnclass ! »

Scénario: [ID-01] Non-régression : le PIN est obligatoire et jamais dérivé du numéro
  Quand un visiteur soumet le formulaire avec un PIN vide, puis avec le PIN « 0304 » pour le numéro 0701020304
  Alors le formulaire est réaffiché en 422 les deux fois
  Et aucun compte n'est créé

Scénario: [ID-01] Non-régression : la création est atomique
  Étant donné l'adhésion qui échoue en base après la création du compte
  Quand un visiteur s'inscrit
  Alors ni l'utilisateur ni le profil élève ni l'adhésion n'existent

Scénario: [ID-02][CL-06] S'inscrire par le lien de classe
  Quand un visiteur ouvre /c/KFM37
  Alors il voit « 6ème 1 » et le nom de l'établissement
  Et le champ code est pré-rempli avec « KFM37 »

Scénario: [ID-02] Lien avec un code inconnu
  Quand un visiteur ouvre /c/ZZZ99
  Alors il est redirigé vers l'inscription élève avec « Code de classe invalide. »

Scénario: [ID-07][CL-08] Vérifier un code en direct, sans rien révéler de plus
  Quand un visiteur interroge la vérification avec « kfm37 »
  Alors la réponse JSON contient exactement les clés classroom_name et school_name
  Quand il interroge avec un code vide
  Alors il reçoit 400
  Quand il interroge avec « zzz99 »
  Alors il reçoit 404
  Quand il interroge 11 fois en une minute depuis la même adresse
  Alors la 11e réponse est 429

Scénario: [ID-03][SC-27] S'inscrire comme enseignant
  Quand un visiteur soumet Nom, Prénom(s), genre, numéro, PIN, la DRENA « Abidjan 1 », l'établissement « Lycée Classique d'Abidjan » et la matière « SVT »
  Alors un compte teacher existe, rattaché à cet établissement comme école principale
  Et il arrive sur la déclaration de ses classes avec « Bienvenue ! Sélectionnez vos classes pour commencer. »

Scénario: [ID-03] Établissement hors de la DRENA choisie
  Quand le formulaire associe une DRENA et un établissement d'une autre DRENA
  Alors il est réaffiché en 422 et aucun compte n'est créé

Scénario: [ID-08] Établissements d'une DRENA
  Quand un visiteur choisit la DRENA « Abidjan 1 »
  Alors la liste des établissements ne contient que ceux d'Abidjan 1, triés par nom
  Et aucun sélecteur « école + niveau → classe » n'existe dans l'application

Scénario: [ID-12] Se connecter
  Étant donné un élève au numéro 0701020304 et au PIN 4821
  Quand il se connecte avec « 225 07 01 02 03 04 » et « 4821 »
  Alors il arrive sur son accueil avec « Connexion réussie ! »
  Et l'identifiant de session Rails a changé

Scénario: [ID-12] Échec sans indice
  Quand il se connecte avec un mauvais PIN, puis avec un numéro inconnu
  Alors il voit les deux fois « Numéro de contact ou mot de passe incorrect. »
  Et le champ PIN est de type password et vide

Scénario: [ID-12] Limite de débit par adresse
  Quand 11 requêtes de connexion partent de la même adresse en une minute
  Alors la 11e reçoit 429

Scénario: [ID-12] Expiration de session
  Étant donné une session élève ouverte il y a 31 jours
  Quand il ouvre son accueil
  Alors il est redirigé vers la connexion

Scénario: [ID-13][TR-02] Être dirigé vers son espace
  Alors après connexion un student arrive sur /students
  Et un teacher dont la configuration est terminée arrive sur /teachers
  Et un teacher dont la configuration n'est pas terminée arrive sur /teachers/classrooms
  Et un team dont le second facteur est vérifié arrive sur /teams
  Et un connecté qui ouvre / est redirigé vers son accueil

Scénario: [ID-13] Non-régression : aucune boucle de redirection
  Étant donné un enseignant sans école principale, puis un élève sans classe principale
  Quand chacun ouvre / puis son accueil
  Alors chacun obtient une page 200 d'écran de sortie en au plus une redirection

Scénario: [ID-14] Se déconnecter
  Quand un connecté se déconnecte
  Alors sa ligne de session est supprimée, la session Rails est réinitialisée
  Et il arrive sur / avec « Déconnexion réussie ! »

Scénario: [ID-15] Récupérer un PIN oublié avec un code
  Étant donné un code de récupération émis il y a 10 minutes pour l'élève 0701020304
  Quand l'élève saisit son numéro, ce code et le nouveau PIN « 7351 »
  Alors il peut se connecter avec « 7351 » et plus avec l'ancien PIN
  Et toutes ses autres sessions sont fermées
  Et les événements "pin_recovery_issued" et "pin_recovery_redeemed" sont journalisés

Scénario: [ID-15] Code expiré, déjà utilisé ou faux
  Quand le code a plus de 15 minutes, ou a déjà servi, ou est faux
  Alors le PIN n'est pas changé et le message est « Code invalide ou expiré. »
  Et après 5 codes faux le code en cours est invalidé

Scénario: [ID-15] Qui peut émettre un code
  Alors un enseignant peut émettre un code pour un élève d'une classe où il enseigne
  Et il est refusé pour un élève d'une autre classe
  Et un membre de l'équipe peut émettre un code pour tout compte sauf le sien
  Et un élève n'a aucun moyen d'émettre un code
  Et le code n'apparaît qu'une fois à l'écran, ni dans le flash ni dans les journaux

Scénario: [ID-16] Chaque espace est restreint par une policy testée
  Alors chaque policy de la V1 a un test unitaire par rôle, sans base de données
  Et un élève qui ouvre /teachers reçoit un refus
  Et aucun contrôleur ne contient de condition sur le rôle hors du socle d'authentification

Scénario: [ID-28] Normaliser et valider le numéro
  Alors « 00225 05 11 22 33 44 », « +225 0511223344 » et « 05.11.22.33.44 » sont enregistrés 0511223344
  Et « 0811223344 » et « 051122334 » sont refusés avec « doit être 10 chiffres commençant par 01, 05 ou 07 »

Scénario: [ID-29] Identifiant public
  Alors chaque compte, classe et session a un public_id de 16 caractères base58, sans préfixe de rôle
  Et aucune URL de compte, de classe ou de session ne contient l'identifiant numérique
  Et une URL avec un identifiant numérique à la place du public_id renvoie 404

Scénario: [F-16][ID-04 remplacée] Inviter un membre de l'équipe
  Étant donné un membre de l'équipe authentifié avec son second facteur
  Quand il invite le numéro 0100000009 avec Nom et Prénom(s)
  Alors un lien d'invitation valable 72 heures s'affiche une seule fois
  Quand la personne ouvre ce lien, choisit son genre et un PIN
  Alors un compte team existe et sa première connexion exige l'enrôlement TOTP
  Et le lien ne fonctionne plus une seconde fois
  Et aucune route /team-signup n'existe

Scénario: [F-07] Enrôler puis vérifier le second facteur
  Étant donné un compte team sans second facteur, qui vient de saisir numéro et PIN
  Alors il voit un QR code et un champ de code
  Quand il saisit un code TOTP valide
  Alors 10 codes de secours s'affichent une seule fois
  Et un code TOTP déjà utilisé est refusé à la connexion suivante
  Et un code de secours ne sert qu'une fois
```

### 4.3 Communication

```gherkin
Scénario: [CO-09] Le toast conserve son message
  Quand une action Turbo Stream échoue avec un message d'erreur
  Alors le toast affiche ce message, reste affiché jusqu'à sa fermeture et porte role="alert"
  Et après une redirection le toast de succès affiche le message du flash
```

### 4.4 School

```gherkin
Scénario: [SC-01] DRENA seedées, en lecture seule
  Quand le seed est rejoué deux fois
  Alors il y a exactement 41 DRENA
  Et aucune route ne crée, modifie ou supprime une DRENA

Scénario: [SC-03] Établissements seedés
  Alors chaque établissement seedé appartient à une DRENA et a un statut, un secteur et un nom unique dans sa DRENA
  Et aucune route ne crée un établissement

Scénario: [SC-26] API des établissements d'une DRENA
  Quand on demande les établissements de la DRENA « Abidjan 1 »
  Alors la réponse JSON est une liste de { id, name } triée par nom
  Quand drena_id est absent
  Alors la réponse est 400
  Quand 31 requêtes partent de la même adresse en une minute
  Alors la 31e reçoit 429
```

### 4.5 Classroom

```gherkin
Scénario: [CL-01][CL-04] L'équipe crée une classe
  Quand l'équipe crée « Tle D 1 » au Lycée Classique d'Abidjan, niveau Tle, série D
  Alors la classe existe avec un code de 3 lettres sans i ni o suivies de 2 chiffres de 2 à 9, stocké en minuscules
  Et la page de la classe affiche ce code en majuscules
  Quand elle crée une seconde « Tle D 1 » dans le même établissement
  Alors le formulaire est réaffiché en 422

Scénario: [CL-01] Non-régression : série incompatible et code trop long
  Quand l'équipe choisit la série D pour la 6ème
  Alors le formulaire est réaffiché en 422
  Et la longueur de la colonne du code est égale à la longueur du code généré (test de schéma)

Scénario: [CL-04] Le code s'affiche toujours en majuscules
  Alors toute page qui affiche un code d'adhésion l'affiche en majuscules
  Et le bouton « Copier » copie la version en majuscules

Scénario: [CL-07] Code saisi n'importe comment
  Quand un visiteur saisit « Kfm 37 » ou « kfm37 »
  Alors la classe « 6ème 1 » est trouvée

Scénario: [CL-09][TR-08 remplacée] Déclarer ses classes
  Étant donné un enseignant dont l'école principale a 6ème 1, 6ème 2 et 3ème B
  Quand il coche 6ème 1 et 3ème B puis clique « Terminer la configuration »
  Alors il enseigne exactement ces deux classes
  Et sa configuration est enregistrée comme terminée
  Et il arrive sur /teachers avec « Vos classes ont été mises à jour avec succès. »

Scénario: [CL-09] Sélection vide, classe d'une autre école
  Quand il ne coche rien
  Alors il voit « Veuillez sélectionner au moins une classe. » et rien ne change
  Quand la requête contient une classe d'une autre école
  Alors cette classe est ignorée

Scénario: [CL-09] Non-régression : le remplacement ne touche que l'école principale
  Étant donné un enseignant qui enseigne aussi une classe d'une autre école (donnée de test)
  Quand il enregistre une nouvelle sélection
  Alors la classe de l'autre école est conservée

Scénario: [CL-10] Fiche d'une classe
  Étant donné un enseignant qui enseigne « 6ème 1 », qui a un cours et un exercice assignés
  Quand il ouvre la classe
  Alors il voit le nom, le niveau, l'établissement, le code en majuscules, l'effectif, les cours assignés et la liste des élèves
  Et la page répond 200 avec au moins un exercice assigné (non-régression)

Scénario: [CL-10] Accès d'un élève à sa classe
  Quand un élève ouvre sa classe
  Alors il ne voit ni la liste nominative ni le code

Scénario: [CL-11] Cours dans la classe
  Quand l'enseignant ouvre un cours depuis sa classe
  Alors il voit les fiches du cours et, pour chacune, « Assignée » ou « Assigner »

Scénario: [CL-12][AS-20] Fiche dans la classe
  Quand l'enseignant ouvre une fiche depuis sa classe
  Alors il voit les exercices publiés de la fiche et, pour chacun, « Assigné » ou « Assigner »

Scénario: [CL-16][CL-17][CL-20][AS-18][AS-19] Assigner, retirer, réassigner
  Quand l'enseignant clique « Assigner » sur l'exercice « Méiose » dans « 6ème 1 »
  Alors le bouton devient « Assigné » sans rechargement et le toast dit « Méiose ajouté à 6ème 1. »
  Et la ligne d'assignation est active et son auteur est l'utilisateur connecté
  Quand il clique « Retirer »
  Alors la ligne est archivée, pas supprimée, et le toast dit « Méiose retiré de 6ème 1. »
  Quand il clique de nouveau « Assigner »
  Alors la même ligne redevient active, sans erreur d'unicité
  Et la réponse est un Turbo Stream qui remplace le bouton, jamais une réponse 204

Scénario: [CL-16] Assigner dans une classe qu'on n'enseigne pas
  Quand un enseignant poste une assignation pour une autre classe
  Alors il reçoit 403 et rien n'est écrit

Scénario: [CL-22] Ma classe (élève)
  Quand un élève ouvre « Ma classe »
  Alors il voit sa classe principale, son établissement et les cours assignés actifs et publiés, avec leur nombre de fiches publiées
  Et un cours retiré de la classe ou archivé n'apparaît pas (non-régression)

Scénario: [CL-23][TR-04][AS-36] Accueil élève
  Quand un élève ouvre son accueil
  Alors il voit son établissement, son niveau, sa classe, l'effectif, et les exercices assignés actifs et publiés
  Et pour chaque exercice : le badge, le meilleur score, le nombre de sessions terminées, et « Reprendre » si une session est en cours
  Et ses 10 dernières sessions terminées
```

### 4.6 Catalog

```gherkin
Scénario: [CA-01] Parcourir le catalogue publié
  Étant donné un cours publié, un brouillon et un archivé
  Quand un élève ouvre /courses
  Alors il ne voit que le cours publié, sur une carte avec la matière, le niveau, la série, le titre et le sous-titre
  Quand l'équipe ouvre /courses
  Alors elle voit les trois, avec leur statut

Scénario: [CA-04] Consulter un cours
  Quand un élève ouvre un cours publié
  Alors il voit le fil d'Ariane, les badges, le contenu riche et la liste des fiches publiées
  Et les formules $…$ sont rendues par KaTeX servi par le bundle de l'application

Scénario: [CA-04] Non-régression : brouillon par URL directe
  Quand un élève ou un enseignant ouvre l'URL d'un brouillon
  Alors il reçoit 404

Scénario: [CA-05] Créer un cours
  Quand l'équipe clique « Nouveau cours » dans le catalogue et soumet Nom, sous-titre, niveau, série, matière, contenu et le statut Brouillon
  Alors le cours existe en brouillon, son auteur est l'utilisateur connecté et son nom est enregistré sans changement de casse
  Et le libellé du statut Brouillon est « Brouillon — visible uniquement par l'équipe »

Scénario: [CA-05] Non-régression : un point d'entrée existe
  Alors le catalogue affiche « Nouveau cours » à l'équipe et à personne d'autre

Scénario: [CA-06] Modifier et publier un cours
  Quand l'équipe modifie le nom et passe le statut à Publié
  Alors le cours relu par le même agrégat porte le nouveau nom et une date de publication

Scénario: [CA-07] Archiver un cours
  Étant donné un cours assigné à une classe
  Quand l'équipe l'archive
  Alors il n'apparaît plus aux élèves ni aux enseignants
  Et ses fiches, ses exercices et ses assignations existent toujours en base

Scénario: [CA-10][CA-11] Fiches d'un cours, fiche et progression
  Quand un élève ouvre une fiche publiée
  Alors il voit son contenu et ses exercices publiés
  Et pour chaque exercice son badge et son meilleur score
  Et « Commencer » seulement si l'exercice est assigné à sa classe

Scénario: [CA-12][CA-13][CA-14] Créer, modifier, archiver une fiche
  Alors seule l'équipe atteint ces actions ; un enseignant ou un élève reçoit 403
  Et deux fiches du même cours ne peuvent pas porter le même nom
  Et archiver une fiche conserve ses exercices et leurs sessions

Scénario: [CA-16][CA-20] Référentiel seedé
  Alors les niveaux 6ème, 5ème, 4ème, 3ème, 2nde, 1ère, Tle existent dans cet ordre
  Et les séries A1, A2, C, D existent et sont reliées à 1ère et Tle
  Et chaque matière seedée a une catégorie et une icône

Scénario: [CA-26] Couleur et icône de la matière
  Alors la couleur d'une matière vient de sa catégorie et son icône de sa colonne icône
  Et renommer une matière ne change ni sa couleur ni son icône

Scénario: [CA-27] Assigner un cours depuis sa page
  Quand un enseignant ouvre un cours publié puis « Assigner à mes classes »
  Alors il voit chacune de ses classes avec « Assigné » ou « Assigner »
  Et le bouton fonctionne (non-régression : il était inatteignable)

Scénario: [F-32] Un seul terme pour la fiche
  Alors aucune vue ni locale de la V1 ne contient « Habilité », « Habiletés » ni « Notions clés »
```

### 4.7 Assessment

```gherkin
Scénario: [AS-02] Détail d'un exercice
  Quand un élève ouvre un exercice publié et assigné
  Alors il voit le titre, la description, le nombre de questions, son meilleur score, son badge et « Commencer » ou « Reprendre »

Scénario: [AS-39] Aperçu des questions, sans fuite
  Quand un enseignant ouvre un exercice assigné à une de ses classes
  Alors il voit les questions avec les bonnes réponses marquées
  Quand un enseignant ouvre un exercice non assigné à ses classes
  Alors il voit les questions sans marque de bonne réponse
  Et le critère TR-cadre-3 est vert

Scénario: [AS-03] Créer un exercice complet
  Quand l'équipe crée l'exercice « Méiose » dans une fiche, avec une question Vrai/Faux et une question à choix unique de 3 réponses
  Alors l'exercice, ses 2 questions et leurs 5 réponses sont enregistrés en une transaction
  Et « + Ajouter une question » et « + Ajouter une réponse » fonctionnent sans rechargement
  Et le titre est enregistré sans changement de casse

Scénario: [AS-03] Règles structurelles
  Alors Vrai/Faux exige exactement 2 réponses dont 1 bonne
  Et choix unique exige au moins 2 réponses dont exactement 1 bonne
  Et 2 bonnes réponses exige au moins 3 réponses dont exactement 2 bonnes
  Et 3 bonnes réponses exige au moins 4 réponses dont exactement 3 bonnes
  Et un exercice sans question ne peut pas être publié
  Et une question invalide réaffiche le formulaire en 422 sans rien enregistrer

Scénario: [AS-04] Modifier un exercice
  Étant donné un exercice sans session
  Quand l'équipe remplace une question
  Alors l'exercice relu contient la nouvelle question et plus l'ancienne
  Étant donné un exercice qui a une session
  Alors le formulaire n'offre plus que le titre, la description et le statut

Scénario: [AS-05] Archiver un exercice
  Alors le critère TR-cadre-6 est vert
  Et aucune route ne supprime un exercice

Scénario: [AS-07] Démarrer une session
  Quand un élève démarre un exercice publié et assigné à sa classe
  Alors une session en cours existe, avec le nombre total de questions figé
  Et il voit la question de position la plus basse, avec une barre de progression à 0 sur 2

Scénario: [AS-07] Refus
  Quand un élève démarre un exercice non assigné à sa classe, ou en brouillon
  Alors il reçoit 403, respectivement 404, et aucune session n'est créée

Scénario: [AS-08] Reprendre
  Étant donné une session en cours avec 1 question répondue sur 2
  Quand l'élève clique « Reprendre »
  Alors il voit la 2e question
  Quand il clique « Recommencer »
  Alors l'ancienne session passe à « abandonnée » et une nouvelle commence

Scénario: [AS-09] Répondre une fois
  Quand l'élève valide une réponse à la question 1
  Alors une tentative est enregistrée avec les identifiants choisis
  Quand il soumet à nouveau la question 1, par double clic ou depuis un autre onglet
  Alors la tentative n'est pas modifiée, aucun doublon n'existe et le score n'en tient pas compte
  Et l'unicité (session, question) est garantie par un index en base

Scénario: [AS-09] Réponse vide
  Quand il valide sans rien cocher
  Alors il reçoit 422 dans le cadre Turbo avec « Veuillez sélectionner au moins une réponse. »

Scénario: [AS-09] Widgets
  Alors Vrai/Faux et choix unique s'affichent en boutons radio
  Et 2 ou 3 bonnes réponses s'affichent en cases à cocher avec « Plusieurs choix possibles »
  Et l'ordre des réponses est mélangé, mais stable pour une même session

Scénario: [AS-10] Correction immédiate
  Quand l'élève valide une réponse
  Alors il voit « Bonne réponse » ou « Mauvaise réponse », les bonnes réponses de cette question et l'explication
  Et la correction exige l'égalité exacte des ensembles d'identifiants, sans crédit partiel

Scénario: [AS-11][AS-12] Clôture, résultat et badge
  Étant donné 2 questions répondues dont 2 bonnes
  Quand l'élève clique « Voir mon résultat »
  Alors la session est terminée avec la note 2/2 et le score 100 %
  Et il voit « Félicitations ! », le badge « Or » et les confettis pendant 3 secondes
  Et le détail question par question

Scénario: [AS-11] Barème et remplacement
  Alors un score de 100 donne Or, de 80 à 99 Argent, de 50 à 79 Bronze, en dessous « Non acquis »
  Et un badge existant n'est remplacé que par un niveau strictement supérieur
  Et le badge gagné s'affiche sur le résultat, l'accueil élève et la fiche (non-régression : badge jamais affiché)

Scénario: [AS-11] Clôture prématurée
  Quand l'élève demande son résultat alors qu'une question n'a pas de réponse
  Alors la session reste en cours et il revient à la question manquante

Scénario: [AS-12] Échec
  Étant donné un score de 40 %
  Alors il voit « Courage ! », « Non acquis », aucun confetti, et « Recommencer »

Scénario: [AS-13] Recommencer
  Étant donné un score inférieur à 100
  Quand l'élève clique « Recommencer »
  Alors une nouvelle session commence, et l'ancienne reste terminée avec son score

Scénario: [AS-12] Lecture d'une session
  Alors l'enseignant d'une classe de l'élève et l'équipe peuvent voir le résultat
  Et un autre élève reçoit « Accès interdit. » avec un statut 403

Scénario: [AS-37] Exercices non publiés
  Alors aucun exercice en brouillon ou archivé n'est listé à un élève, sur la fiche comme sur l'accueil
```

### 4.8 Transverse

```gherkin
Scénario: [TR-01] Landing
  Quand un visiteur ouvre /
  Alors il voit les deux entrées « Je suis élève » et « Je suis enseignant »
  Et chacune ouvre une modale avec « Se connecter » et « Créer un compte » vers les bonnes pages
  Et aucun lien de la page ne pointe vers une route inexistante

Scénario: [TR-05] Accueil enseignant
  Quand un enseignant configuré ouvre /teachers
  Alors il voit ses classes, avec pour chacune l'effectif et le nombre d'exercices assignés
  Et un lien vers « Modifier mes classes »

Scénario: [TR-09] Accueil équipe (minimal)
  Quand l'équipe ouvre /teams
  Alors elle voit le nombre de DRENA et d'établissements, les niveaux avec leurs séries, et les 5 derniers cours et exercices modifiés
  Et les raccourcis « Nouveau cours », « Nouvelle classe », « Inviter un membre », « Débloquer un compte »

Scénario: [TR-27] Navigation par rôle
  Alors chaque rôle voit les mêmes destinations dans la barre latérale et dans la barre du bas
  Et une destination d'une vague future est affichée inactive, jamais en lien mort

Scénario: [TR-04][TR-05][TR-09] Accueils couverts par un test système
  Alors un test système par rôle se connecte réellement et ouvre l'accueil sans erreur

Scénario: [TR-40] Français par clés
  Alors aucune vue de la V1 ne contient de texte d'interface en dur, et une clé manquante fait échouer les tests

Scénario: [TR-41] KaTeX dans le bundle
  Alors aucune page ne charge de script ni de feuille de style depuis un CDN tiers
```

### 4.9 Chantiers de bug absorbés

```gherkin
Scénario: [queries-constantes-orm-disparues] Accueils vivants
  Alors les tests système de TR-04, TR-05 et TR-09 sont verts

Scénario: [catalog-lecture-ecriture-incompatibles] Un seul agrégat
  Alors créer, lire, modifier et archiver un cours passent par la même entité et le même repository, dans un seul test d'intégration

Scénario: [classroom-assignment-belongs-to-casses] Repository d'assignation
  Alors le repository d'assignation est couvert à 100 %, branches comprises, avec les trois types de ressource

Scénario: [classroom-code-adhesion-trop-long] Code et colonne
  Alors un test de schéma vérifie que la longueur de la colonne du code égale la longueur du code généré

Scénario: [dette-contrats-ports-et-injection] Ports et injection
  Alors chaque port a un test de contrat qui vérifie que son repository implémente toutes ses méthodes avec la même arité
  Et aucun fichier de app/domain ne mentionne Repositories::, Orm:: ni ActiveRecord
```

## 5. Modélisation préliminaire

Le détail exécutable est dans [`plan.md`](plan.md), Lot 0.

| Couche | Éléments prévus |
|---|---|
| Domaine | `Result` ; entités et objets-valeurs de 5 contextes (identity, school, classroom, catalog, assessment) ; 23 ports (dont 2 adaptateurs techniques : TOTP, hachage) ; 14 policies ; DTO par formulaire ; use cases par lot |
| Infrastructure | 29 migrations ; 29 modèles `Orm::` ; un repository par port ; 2 adaptateurs (TOTP, hachage) ; queries de lecture par écran ; seeds du référentiel ivoirien |
| Delivery | 6 fichiers de routes, un par contexte, dessinés en entier au Lot 0 ; socle d'authentification ; un contrôleur par écran |
| UI | Shell par rôle et composants du Lot 0c ; vues ERB par lot ; contrôleurs Stimulus chargés par motif, sans manifeste partagé |

## 6. Décisions rattachées

- ADR-0026 — `Result` et nature des entités (F-01, F-03)
- ADR-0027 — Contextes bornés (F-02)
- ADR-0028 — Policies de domaine (F-04)
- ADR-0029 — `public_id` et slugs (F-05)
- ADR-0030 — Une école principale par enseignant, via `teacher_schools` (F-06)
- ADR-0031 — TOTP et codes de secours pour l'équipe (F-07)
- ADR-0032 — Récupération assistée du PIN (F-08)
- ADR-0033 — Barème des badges et seuils pédagogiques (F-10, F-11)
- ADR-0034 — Seed du référentiel ivoirien et des DRENA (F-12)
- ADR-0035 — Cycle de vie du contenu `draft/published/archived` (F-13)
- ADR-0036 — Archivage, jamais de suppression du contenu consommé (F-14)
- ADR-0037 — Nom et Prénom(s) (F-15)
- ADR-0038 — Rôle `team` unique, par seed puis invitation (F-16)
- ADR-0048 — Statuts d'assignation `active/archived` (F-26)
- ADR-0050 — Authentification, contact et session (F-28)
- ADR-0054 — Moteur d'évaluation (F-34)
- UDR-0005 — Design system (F-09)
- UDR-0006 — Shell par rôle et toasts (F-31)
- UDR-0007 — Vocabulaire d'interface, dont le nom de la fiche (F-32)
- Une UDR par écran créé, écrite par le lot qui le livre (porte de sortie `feature.md`)

## 7. Mesures

| Métrique | Avant (ancienne app) | Cible V1 |
|---|---|---|
| Parcours bout en bout équipe → enseignant → élève | impossible (questions jamais persistées) | vert en test système Chrome headless |
| Accueils par rôle qui répondent 200 | 1 sur 3 | 3 sur 3 |
| Couverture lignes et branches | non mesurée | 100 % (ADR-0024) |
| JS de l'application, gzip | 622 Ko non compressés | dans le budget de l'ADR-0051 |
