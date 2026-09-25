# PRD — Boucle pédagogique (V1)

> Les specs sont figées ici. Toute évolution après la phase 3 modifie explicitement ce fichier.
> Ce PRD **hérite** du [PRD cadre](../refonte-application/prd.md) : matrice des permissions, exigences transverses, critères §5. En cas de contradiction, le PRD cadre gagne, sauf décision contraire consignée dans un ADR ou une UDR.
> Chaque critère porte l'ID d'inventaire de la feature ([feuille de route §6](../refonte-application/feuille-de-route.md#6-traçabilité--chaque-feature-de-lexistant-a-une-vague)). Le lot qui l'implémente est donné dans la traçabilité de [`plan.md`](plan.md).
> Révision du 2026-09-25 : ADR-0026 à ADR-0054 et UDR-0007 acceptés ; V1 élargie par le porteur (DRENA, établissements et génération des classes, référentiel pédagogique, imports JSON en masse) ; imports **partiels** (ADR-0039) ; tout CRUD par Hotwire (UDR-0006). Voir [`journal.md`](journal.md).

## 1. Contexte

La production démarre **vide** : aucun référentiel ni établissement n'y est seedé (ADR-0034). L'équipe y crée le référentiel (niveaux, séries, matières) et les DRENA à l'écran, puis les établissements, un par un ou par import JSON ; chaque établissement reçoit ses classes par défaut (ADR-0030). Elle publie des cours, leurs fiches essentielles et leurs exercices, saisis à l'écran ou importés. Un enseignant s'inscrit, déclare ses classes et leur assigne du contenu. Un élève rejoint sa classe par code, fait un exercice, voit la correction, son résultat et son badge.

La V1 pose aussi le socle des vagues suivantes :

- toutes les tables de la boucle ;
- les contrats de port ;
- l'authentification avec limite de débit, verrouillage progressif, rotation de session, TOTP pour l'équipe et récupération assistée du PIN ;
- le moteur d'import en arrière-plan, partiel et tolérant (TR-28, ADR-0039) ;
- le shell par rôle ;
- les briques Hotwire de tout CRUD : modale, flux Turbo, rafraîchissement par morphing (§4.8).

## 2. Acteurs et permissions

Les policies sont des objets de domaine, de forme `call(actor:, **faits) → Shared::Result`, sans lecture en base (ADR-0028). Le use case valide le DTO, charge les faits, appelle la policy, puis écrit. Un refus renvoie `:forbidden`, que le contrôleur traduit en 403 ou en redirection accompagnée d'un toast. Un compte équipe dont le second facteur n'est pas vérifié n'obtient aucun acteur : le socle d'authentification le bloque avant toute policy.

| Capacité (V1) | Visiteur | Student | Teacher | Team | Policy |
|---|---|---|---|---|---|
| Rejoindre une classe par son code (et créer son compte) | ✅ | ✅ *si sa classe est archivée* | — | — | `Classroom::JoinPolicy` |
| S'inscrire comme enseignant | ✅ | — | — | — | `Identity::RegisterTeacherPolicy` |
| Accepter une invitation équipe | ✅ *avec le lien* | — | — | — | — (exempté, ADR-0028) |
| Inviter un membre de l'équipe | — | — | — | ✅ *admin* | `Identity::InviteTeamPolicy` |
| Générer un code de récupération de PIN | — | — | ✅ *élève d'une classe active qu'il enseigne* | ✅ *tout compte sauf le sien* | `Identity::IssuePinRecoveryCodePolicy` |
| Réinitialiser le second facteur d'un membre | — | — | — | ✅ *sauf le sien* | `Identity::ResetSecondFactorPolicy` |
| Rechercher un compte par numéro | — | — | — | ✅ | `Identity::ReadUserPolicy` |
| Gérer les DRENA ; gérer et importer les établissements | — | — | — | ✅ | `School::ManageSchoolPolicy` |
| Gérer le référentiel (niveaux, séries, liaisons, matières) | — | — | — | ✅ | `Catalog::ManageTaxonomyPolicy` |
| Voir le catalogue publié (cours, fiches essentielles, exercices) | — | ✅ | ✅ | ✅ *brouillons et archives compris* | `Catalog::ReadPublishedPolicy` |
| Créer, modifier, publier, archiver et importer du contenu | — | — | — | ✅ | `Catalog::ManageContentPolicy` |
| Suivre un import | — | — | — | ✅ | la policy de son type (`School::ManageSchoolPolicy` ou `Catalog::ManageContentPolicy`) |
| Voir les propositions correctes hors de sa session | — | — | — | ✅ | `Assessment::RevealAnswersPolicy` |
| Voir la correction d'une question | — | ✅ *question déjà tentée* | — | ✅ | `Assessment::RevealAnswersPolicy` |
| Démarrer ou reprendre une session | — | ✅ *exercice publié, parents publiés* | — | — | `Assessment::StartSessionPolicy` |
| Répondre à une question | — | ✅ *sa session en cours* | — | — | `Assessment::SubmitAttemptPolicy` |
| Voir le résultat d'une session | — | ✅ *la sienne* | ✅ *élève d'une classe active qu'il enseigne* | ✅ | `Assessment::ReadSessionPolicy` |
| Ouvrir une classe | — | ✅ *la sienne* | ✅ *s'il y enseigne* | ✅ | `Classroom::ReadClassroomPolicy` |
| Voir la liste nominative et le code d'une classe | — | — | ✅ *s'il y enseigne* | ✅ | `Classroom::ReadClassroomPolicy` (fait `show_roster`) |
| Déclarer ou retirer une classe enseignée | — | — | ✅ *classe active de son école* | — | `Classroom::DeclareTeachingPolicy` |
| Assigner / retirer une ressource | — | — | ✅ *s'il y enseigne* | ✅ | `Classroom::AssignPolicy` |
| Créer une classe | — | — | — | ✅ | `Classroom::ManageClassroomPolicy` |

Écarts assumés avec le PRD cadre :
- l'élève ne voit **pas** le code de sa classe dans la V1 : il l'a déjà utilisé, et le partage revient à l'enseignant (CL-05, V3) ;
- **l'enseignant ne voit pas les propositions correctes** d'un exercice, ni dans l'aperçu ni dans le résultat d'un élève : il voit le score et la note (ADR-0028) ;
- **tout exercice publié est démarrable** par un élève, assigné ou non ; l'assignation oriente l'accueil de l'élève, elle ne conditionne pas l'accès (ADR-0028).

## 3. Parcours utilisateur

### Chemin nominal

1. Le porteur déploie la production avec `TEAM_BOOTSTRAP_CONTACT`. Le seed affiche une invitation d'amorçage. Le premier membre de l'équipe l'accepte (Nom, Prénom(s), PIN), enrôle son TOTP et note ses 10 codes de secours.
2. L'équipe crée le référentiel : niveaux (6ème à Tle ; leur slug, figé, sert de code), séries (A, A1, A2, C, D), liaisons niveau–série, matières avec leur catégorie. Chaque création se fait dans une modale, sans rechargement de page. Elle crée la DRENA « Abidjan 1 » (slug `abidjan-1`), puis importe le fichier JSON de ses établissements ; l'écran de suivi passe de « Vérification » à « Import en cours » puis à « Terminé » : 23 établissements importés, 1 ignoré (déjà présent), 1 en erreur avec son chemin JSON ; chaque établissement importé a reçu ses classes par défaut.
3. L'équipe importe un fichier `course_tree` : le cours « Génétique et évolution » (Tle D, SVT), ses fiches essentielles et leurs exercices arrivent en brouillon. Elle les relit, puis publie le cours, une fiche essentielle et un exercice de 2 questions.
4. Un enseignant s'inscrit : DRENA Abidjan 1, Lycée Classique d'Abidjan, SVT. Il arrive sur « Quelles classes enseignez-vous ? », déclare « Tle D 1 » et termine sa configuration.
5. Il ouvre « Tle D 1 », relève le code `KFM37`, ouvre le cours puis la fiche essentielle, et assigne l'exercice. Le bouton passe à « Assigné ».
6. Un élève ouvre `/c/kfm37`, voit « Tle D 1 — Lycée Classique d'Abidjan », remplit Nom, Prénom(s), genre, numéro, PIN et confirmation, puis arrive sur son accueil : « Bienvenue dans ta classe ! ».
7. Sur son accueil, il voit l'exercice assigné et le démarre. Il répond aux 2 questions, avec une correction immédiate après chacune. La dernière réponse clôt la session.
8. Il voit sa note (20/20), son score (100 %), la maîtrise « Acquis » et le badge « Diamant ». Les confettis s'affichent.
9. L'enseignant ouvre le résultat de l'élève : score, note et maîtrise, sans les propositions correctes.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code de classe inconnu sur `/c/<code>` | 404, « Code de classe invalide. », lien « Saisir un autre code » |
| Classe archivée, code révoqué, classe pleine | Refus avec le message de la raison, aucun compte créé |
| Numéro déjà utilisé à l'inscription | Formulaire réaffiché en 422 avec « Ce numéro est déjà utilisé. » |
| 5 échecs de connexion consécutifs pour un numéro | Refus pendant 15 min sans vérifier le PIN ; 10 échecs : 1 h ; 20 échecs : verrou jusqu'à la récupération du PIN ; événement `login.locked` |
| Enseignant sans configuration terminée | Toute page enseignant ramène à la déclaration des classes, qui s'affiche sans jamais rediriger |
| Enseignant sans école principale, élève sans classe active | Écran de sortie, bouton « Se déconnecter », aucune redirection |
| Réponse vide | 422 dans le cadre de la question, « Sélectionne au moins une proposition. » |
| Question déjà tentée soumise à nouveau | Rien n'est écrit ; retour à la session, toast « Question déjà répondue » |
| Brouillon ouvert par URL par un non-équipe | 404 : le brouillon n'existe pas pour lui |
| Ressource d'une autre classe | 403 et toast « Accès interdit. », aucune donnée de la classe dans la réponse |
| Fichier d'import avec des éléments invalides | Rapport « Terminé » : les éléments valides sont importés, chaque élément invalide est listé avec son chemin JSON et son motif, et n'a laissé aucune ligne |
| Enveloppe, version ou cible invalide, fichier illisible ou au-delà des limites | Rapport « Rejeté », motif affiché ; **aucune ligne écrite** |
| Fichier déjà importé, réimporté | Accepté ; ses éléments déjà en base sont ignorés et comptés comme doublons ; rien n'est mis à jour |
| Second import du même type pendant qu'un premier tourne | Refus dans la modale : « Un import de ce type est déjà en cours » |
| Fichier de plus de 20 Mo | Refus dans la modale, rien n'est créé |
| Formulaire en modale invalide | La modale se rouvre avec ses erreurs (422), sans rechargement de page |
| Suppression d'un élément référencé (niveau, série, matière, DRENA, établissement) | Refus avec la raison ; un établissement peut être désactivé à la place |

## 4. Critères d'acceptation

Chaque bloc devient au moins un test, écrit avant le code et rouge d'abord. Les messages entre guillemets sont des valeurs de la locale `fr`. Le test les compare par la clé `t()`, jamais par une chaîne en dur dans le test.

### 4.1 Critères transverses de la porte V1 (PRD cadre §5)

```gherkin
Scénario: [TR-cadre-1] Aucun rôle privilégié par l'inscription
  Étant donné un visiteur sur /c/kfm37 ou sur l'inscription enseignant
  Quand il soumet le formulaire avec un paramètre role=team ou role=school_admin ajouté à la main
  Alors le compte créé a le rôle student, respectivement teacher
  Et aucun compte team ni school_admin n'existe

Scénario: [TR-cadre-2] Verrouillage progressif
  Étant donné un compte au numéro 0700000001
  Quand 5 connexions consécutives échouent pour ce numéro
  Alors la tentative suivante est refusée pendant 15 minutes, même avec le bon PIN, sans que le PIN soit vérifié
  Et un événement "login.locked" est écrit dans le journal d'audit
  Quand le compteur atteint 10, puis 20 échecs consécutifs
  Alors le refus dure 1 heure, puis jusqu'à la réinitialisation du PIN par un code de récupération

Scénario: [TR-cadre-3] Aucune proposition correcte servie hors de la correction de l'élève
  Étant donné le cache de fragments actif
  Et un membre de l'équipe qui a affiché l'exercice « Méiose » avec ses propositions correctes
  Quand un enseignant, puis un élève affichent le même exercice
  Alors aucun des deux HTML ne contient de marqueur de proposition correcte ni l'identifiant d'une proposition correcte

Scénario: [TR-cadre-4] Un enseignant hors de la classe est refusé
  Étant donné un enseignant qui n'enseigne pas en 3ème B
  Quand il ouvre la page de la 3ème B
  Alors il reçoit un refus
  Et la réponse ne contient ni le code d'adhésion ni un nom d'élève de la 3ème B

Scénario: [TR-cadre-5] L'équipe ne passe pas sans second facteur
  Étant donné un compte team qui a saisi le bon numéro et le bon PIN
  Et qui n'a pas encore validé son code TOTP
  Quand il ouvre /teams, /teams/schools ou /teams/jobs
  Alors il est redirigé vers la saisie du code TOTP

Scénario: [TR-cadre-6] Archiver ne détruit pas l'historique
  Étant donné un exercice qui a 3 sessions terminées, leurs tentatives et 2 badges
  Quand l'équipe l'archive
  Alors les 3 sessions, leurs tentatives et les 2 badges existent toujours
  Et l'exercice n'apparaît plus dans les listes des élèves
```

### 4.2 Identity

```gherkin
Scénario: [ID-01][ID-02][CL-06][CL-07] Rejoindre une classe et créer son compte
  Étant donné la classe « 6ème 1 » de code kfm37, active, avec 12 élèves sur 80
  Quand un visiteur ouvre /c/KFM37
  Alors il voit « 6ème 1 », son niveau et le nom de l'établissement
  Quand il soumet Nom « Kouassi », Prénom(s) « Aya Marie », genre féminin, numéro « 07 01 02 03 04 », PIN « 4821 » et sa confirmation
  Alors un compte student existe avec le numéro 0701020304
  Et il est membre principal de « 6ème 1 », avec une date d'adhésion
  Et il est connecté et arrive sur son accueil avec « Bienvenue dans ta classe ! »

Scénario: [ID-01] Non-régression : PIN obligatoire, création atomique
  Quand un visiteur soumet le formulaire avec un PIN vide, puis avec une confirmation différente
  Alors le formulaire est réaffiché en 422 les deux fois et aucun compte n'est créé
  Étant donné l'adhésion qui échoue en base après la création du compte
  Quand un visiteur s'inscrit
  Alors ni l'utilisateur ni l'adhésion n'existent

Scénario: [ID-02][CL-07] Code inconnu, code saisi n'importe comment
  Quand un visiteur ouvre /c/ZZZ99
  Alors il reçoit 404 avec « Code de classe invalide. »
  Quand il saisit « Kfm 37 » sur l'écran « Rejoindre une classe »
  Alors il arrive sur /c/kfm37

Scénario: [ID-07][CL-08] L'aperçu ne révèle rien de plus
  Quand un visiteur ouvre /c/kfm37
  Alors la page ne contient que le nom de la classe, du niveau et de l'établissement, jamais l'effectif ni un nom de personne
  Quand il ouvre 11 pages /c/<code> en une minute depuis la même adresse
  Alors la 11e reçoit 429

Scénario: [ID-03][SC-27] S'inscrire comme enseignant
  Quand un visiteur soumet Nom, Prénom(s), genre, numéro, PIN et confirmation, la DRENA « Abidjan 1 », l'établissement « Lycée Classique d'Abidjan » et la matière « SVT »
  Alors un compte teacher existe, avec un profil enseignant SVT, rattaché à cet établissement comme école principale
  Et il arrive sur la déclaration de ses classes avec « Bienvenue ! Sélectionnez vos classes pour commencer. »

Scénario: [ID-03] Établissement hors de la DRENA choisie, ou inactif
  Quand le formulaire associe une DRENA et un établissement d'une autre DRENA, ou un établissement désactivé
  Alors il est réaffiché en 422 et aucun compte n'est créé

Scénario: [ID-08] Établissements d'une DRENA
  Quand un visiteur choisit la DRENA « Abidjan 1 »
  Alors la liste ne contient que les établissements actifs d'Abidjan 1, triés par nom
  Et aucun sélecteur « école + niveau → classe » n'existe dans l'application

Scénario: [ID-12] Se connecter
  Étant donné un élève au numéro 0701020304 et au PIN 4821
  Quand il se connecte avec « 225 07 01 02 03 04 » et « 4821 »
  Alors il arrive sur son accueil avec « Connexion réussie »
  Et l'identifiant de session Rails a changé

Scénario: [ID-12] Échec sans indice
  Quand il se connecte avec un mauvais PIN, puis avec un numéro inconnu
  Alors il voit les deux fois le même message d'échec
  Et le champ PIN est de type password et vide

Scénario: [ID-12] Limite de débit par adresse
  Quand 6 requêtes de connexion partent de la même adresse en une minute
  Alors la 6e reçoit 429

Scénario: [ID-12] Expiration de session
  Étant donné une session élève inactive depuis 31 jours
  Quand il ouvre son accueil
  Alors il est redirigé vers la connexion
  Étant donné une session team ouverte il y a 13 heures, active depuis
  Alors elle est expirée elle aussi

Scénario: [ID-13][TR-02] Être dirigé vers son espace
  Alors après connexion un student arrive sur /students
  Et un teacher dont la configuration est terminée arrive sur /teachers
  Et un teacher dont la configuration n'est pas terminée arrive sur /teachers/classrooms
  Et un team dont le second facteur est vérifié arrive sur /teams
  Et un connecté qui ouvre / est redirigé vers son accueil

Scénario: [ID-13] Non-régression : aucune boucle de redirection
  Étant donné un enseignant sans école principale, puis un élève sans classe active
  Quand chacun ouvre / puis son accueil
  Alors chacun obtient une page 200 d'écran de sortie en au plus une redirection

Scénario: [ID-14] Se déconnecter
  Quand un connecté clique « Se déconnecter »
  Alors sa ligne de session est supprimée, la session Rails est réinitialisée
  Et il arrive sur / avec « Vous êtes déconnecté »

Scénario: [ID-15] Réinitialiser son PIN avec un code
  Étant donné un code de récupération à 8 chiffres émis il y a 10 minutes pour l'élève 0701020304
  Quand l'élève saisit son numéro, ce code, le nouveau PIN « 7351 » et sa confirmation
  Alors il peut se connecter avec « 7351 » et plus avec l'ancien PIN
  Et toutes ses sessions sont fermées et son verrouillage est remis à zéro
  Et les événements "pin.recovery_code_issued" et "pin.reset" sont journalisés

Scénario: [ID-15] Code expiré, déjà utilisé, révoqué ou faux
  Quand le code est faux, déjà utilisé ou révoqué
  Alors le PIN n'est pas changé et le message est le même dans les trois cas
  Quand le code a plus de 15 minutes
  Alors le message dit que le code a expiré
  Et après 5 codes faux le code en cours est révoqué

Scénario: [ID-15] Qui peut émettre un code
  Alors un enseignant peut émettre un code pour un élève d'une classe active où il enseigne
  Et il est refusé pour un élève d'une autre classe
  Et un membre de l'équipe peut émettre un code pour tout compte sauf le sien
  Et un élève n'a aucun moyen d'émettre un code
  Et le code n'apparaît qu'une fois à l'écran, ni dans le flash ni dans les journaux

Scénario: [ID-16] Chaque espace est restreint par une policy testée
  Alors chaque policy de la V1 a un test unitaire par rôle, sans base de données
  Et chaque use case appelle une policy, sauf les exemptions listées au plan
  Et un élève qui ouvre /teachers reçoit un refus
  Et aucun contrôleur ne contient de condition sur le rôle hors du socle d'authentification

Scénario: [ID-28] Normaliser et valider le numéro
  Alors « 00225 05 11 22 33 44 », « +225 0511223344 » et « 05.11.22.33.44 » sont enregistrés 0511223344
  Et « 0811223344 » et « 051122334 » sont refusés avec « doit être 10 chiffres commençant par 01, 05 ou 07 »

Scénario: [ID-29] Identifiant public
  Alors chaque compte, classe, session, exercice, établissement, DRENA, assignation, lacune et rapport d'import a un public_id de 14 caractères base58
  Et aucune URL ne contient d'identifiant numérique
  Et une URL avec un identifiant numérique à la place du public_id renvoie 404

Scénario: [F-16][ID-04 remplacée] Inviter un membre de l'équipe
  Étant donné un membre de l'équipe admin, authentifié avec son second facteur
  Quand il invite le numéro 0100000009 avec le rôle « contenu »
  Alors un lien /invitations/<jeton> valable 72 heures s'affiche une seule fois
  Quand la personne ouvre ce lien et saisit Nom, Prénom(s), genre, PIN et confirmation
  Alors un compte team existe et sa première connexion exige l'enrôlement TOTP
  Et le lien ne fonctionne plus une seconde fois
  Et aucune route /team-signup n'existe

Scénario: [F-16] Invitation d'amorçage
  Étant donné une base de production vierge et TEAM_BOOTSTRAP_CONTACT posé
  Quand le seed est joué
  Alors une seule invitation team admin existe, et son lien est affiché une fois
  Et le seed rejoué ne crée pas de seconde invitation

Scénario: [F-07] Enrôler puis vérifier le second facteur
  Étant donné un compte team sans second facteur, qui vient de saisir numéro et PIN
  Alors il voit un QR code et un champ de code
  Quand il saisit un code TOTP valide
  Alors 10 codes de secours de 10 caractères base58 s'affichent une seule fois
  Et un code TOTP déjà utilisé est refusé à la connexion suivante
  Et un code de secours ne sert qu'une fois, et son usage est journalisé "backup_code.used"

Scénario: [F-07] Réinitialiser le second facteur d'un membre
  Quand un membre de l'équipe réinitialise le second facteur d'un autre membre
  Alors ce membre est déconnecté partout et doit enrôler de nouveau son TOTP
  Et l'événement "totp.reset" est journalisé
  Et nul ne peut réinitialiser son propre second facteur
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
Scénario: [SC-01] Gérer les DRENA
  Étant donné une production vierge
  Alors aucune DRENA n'existe
  Quand l'équipe crée « Abidjan 1 » dans une modale
  Alors la DRENA apparaît dans la liste avec le slug « abidjan-1 », sans rechargement de page
  Quand elle la renomme « Abidjan 1 Plateau »
  Alors son slug reste « abidjan-1 »
  Quand elle crée une seconde « Abidjan 1 Plateau »
  Alors la modale se rouvre en 422 avec l'erreur sur le nom
  Quand l'équipe supprime une DRENA qui a des établissements
  Alors la suppression est refusée avec la raison, et rien n'est supprimé

# SC-02 (import de DRENA) est écartée par le porteur : les 41 DRENA se créent à l'écran.

Scénario: [SC-03][SC-09][CL-01] Créer un établissement génère ses classes
  Étant donné le référentiel du seed de développement (6ème à 3ème en cycle first ; 2nde liée à A et C ; 1ère et Tle liées à A1, A2, C, D)
  Quand l'équipe crée le lycée public « Lycée Moderne de Cocody », sigle « LMC », dans la DRENA Abidjan 1
  Alors l'établissement existe avec le type « Public », le statut « active » et le cycle « both »
  Et 77 classes de l'année scolaire en cours existent, dont « 6ème 1 » à « 6ème 4 », « 2nde A 1 » à « 2nde A 6 », « 1ère A1 1 » à « 1ère A1 6 » et « Tle D 1 » à « Tle D 6 »
  Et chaque classe a un code d'adhésion unique et un plafond de 80 élèves
  Et aucun élève n'existe
  Et un toast annonce « Établissement créé : 77 classes générées », sans rechargement de page
  Quand l'équipe crée le « Collège moderne de Cocody » (public)
  Alors son cycle proposé est « first » et seules les classes de 6ème à 3ème sont créées, soit 28
  Quand elle crée un lycée privé, puis un lycée mixte
  Alors chacun reçoit 38 classes (le barème privé s'applique aussi au mixte)

Scénario: [SC-09] Niveau sans série liée
  Étant donné une 1ère qui n'est liée à aucune série
  Quand l'équipe crée un lycée public
  Alors aucune classe de 1ère n'est créée
  Et le niveau sauté est signalé dans le toast et compté dans le détail

Scénario: [SC-03] Création atomique
  Étant donné une génération de classes qui échoue en base
  Quand l'équipe crée un établissement
  Alors ni l'établissement ni aucune classe n'existent

Scénario: [SC-04] Liste nationale des établissements
  Étant donné 600 établissements dans 3 DRENA
  Quand l'équipe ouvre « Établissements » depuis la navigation
  Alors elle voit 50 établissements par page, avec le total
  Et elle filtre par DRENA, type, cycle, statut et nom, sans rechargement de page, et l'URL garde les filtres

Scénario: [SC-05] Consulter un établissement
  Quand l'équipe ouvre un établissement
  Alors elle voit sa DRENA, son sigle, son type, son cycle, son statut, ses classes de l'année groupées par niveau avec leur code et leur effectif, et ses enseignants

Scénario: [SC-06] Modifier un établissement
  Quand l'équipe modifie le nom, le sigle, la DRENA, le type, le statut ou le cycle dans une modale
  Alors la ligne et l'en-tête sont mis à jour sans rechargement de page
  Et les classes existantes ne changent pas : aucune n'est créée ni supprimée

Scénario: [SC-07] Supprimer ou désactiver un établissement
  Étant donné un établissement dont aucune classe n'a d'élève, d'enseignant ni d'assignation
  Quand l'équipe le supprime
  Alors l'établissement et ses classes sont supprimés, et sa ligne disparaît sans rechargement de page
  Étant donné un établissement dont une classe a un élève
  Quand l'équipe le supprime
  Alors la suppression est refusée avec « Désactivez plutôt cet établissement »
  Quand elle le désactive
  Alors il n'apparaît plus à l'inscription enseignant, et ses classes et élèves existent toujours

Scénario: [SC-08][SC-09][TR-28] Importer des établissements avec leurs classes
  Étant donné la DRENA « Abidjan 1 » et un fichier de l'ancienne application enveloppé : { "format": "lnclass.schools", "version": 1, "drena": "abidjan-1", "schools": [...] }, avec les clés nom, schoolsigle, schooltype et schoolstatus
  Quand l'équipe l'importe depuis la modale d'import
  Alors l'écran de suivi passe de « En file d'attente » à « Vérification », « Import en cours » puis « Terminé », sans recharger la page
  Et chaque établissement est créé avec son type (« privée » → private, « mixte » → mixed), son cycle (un nom contenant « collège » → first) et ses classes par défaut
  Et le rapport compte les établissements importés, ignorés et en erreur, et détaille les classes générées

Scénario: [SC-08][TR-28] Import partiel : un fichier mixte donne un rapport exact
  Étant donné un fichier de 300 établissements dont le 212e a le type « semi-public », le 250e la DRENA « inconnue », le 12e existe déjà en base et le 40e répète le 3e
  Quand l'équipe l'importe
  Alors le rapport est « Terminé » avec 296 importés, 2 ignorés, 2 en erreur et un total de 300
  Et les erreurs sont listées aux chemins schools[211].type et schools[249].drena, avec leur motif
  Et les 296 établissements valides ont leurs classes, les 2 invalides n'ont laissé aucune ligne
  Et l'établissement déjà présent n'a pas été modifié

Scénario: [SC-08] Rejet en bloc
  Quand l'équipe importe un fichier dont le format n'est pas « lnclass.schools », ou dont la version n'est pas 1, ou dont la DRENA d'enveloppe est inconnue, ou qui n'est pas du JSON
  Alors le rapport est « Rejeté » avec le motif
  Et aucun établissement ni aucune classe n'a été créé

Scénario: [SC-08] Import en masse dans le budget
  Quand l'équipe importe 500 établissements, soit environ 35 000 classes
  Alors l'import est terminé en moins de 2 minutes
  Et tous les codes d'adhésion sont distincts

Scénario: [SC-26] API des établissements d'une DRENA
  Quand on demande les établissements de la DRENA « Abidjan 1 » par son public_id
  Alors la réponse JSON est une liste de { public_id, name }, établissements actifs seulement, triée par nom
  Quand la DRENA est inconnue
  Alors la réponse est 404
  Quand 31 requêtes partent de la même adresse en une minute
  Alors la 31e reçoit 429
```

### 4.5 Classroom

```gherkin
Scénario: [CL-01][CL-04] L'équipe ajoute une classe à un établissement
  Quand l'équipe crée « Tle D 7 » au Lycée Classique d'Abidjan, niveau Tle, série D, dans la modale ouverte depuis la fiche de l'établissement
  Alors la classe existe pour l'année scolaire en cours, avec un code de 3 lettres sans i ni o suivies de 2 chiffres de 2 à 9, stocké en minuscules
  Et un toast affiche ce code en majuscules, sans rechargement de page
  Et la page de la classe affiche ce code en majuscules
  Quand elle crée une seconde « Tle D 7 » dans le même établissement et la même année
  Alors la modale se rouvre en 422 avec l'erreur sur le nom

Scénario: [CL-01] Non-régression : série incompatible et code trop long
  Quand l'équipe choisit la série D pour la 6ème
  Alors la modale se rouvre en 422
  Et la longueur de la colonne du code est égale à la longueur du code généré (test de schéma)

Scénario: [CL-01] Année scolaire
  Étant donné la date du 25 septembre 2026
  Alors l'année scolaire courante est « 2026-2027 »
  Étant donné la date du 15 août 2027
  Alors elle est encore « 2026-2027 »

Scénario: [CL-04] Le code s'affiche toujours en majuscules
  Alors toute page qui affiche un code d'adhésion l'affiche en majuscules
  Et le bouton « Copier » copie la version en majuscules

Scénario: [CL-06] JoinPolicy : classe archivée, code révoqué, classe pleine
  Quand un visiteur utilise le code d'une classe archivée
  Alors il voit « Cette classe est archivée » et aucun compte n'est créé
  Quand il utilise un ancien code, remplacé depuis
  Alors il reçoit 404
  Quand la classe a atteint son plafond d'élèves
  Alors il voit « Cette classe est complète » et aucun compte n'est créé
  Et deux inscriptions simultanées sur la dernière place n'en acceptent qu'une

Scénario: [CL-06] Élève déjà inscrit
  Étant donné un élève connecté dont la classe principale est active
  Quand il ouvre le code d'une autre classe
  Alors il voit « Tu es déjà inscrit dans une classe » et rien ne change
  Étant donné un élève connecté dont la classe principale est archivée
  Quand il rejoint une nouvelle classe
  Alors l'ancienne adhésion est close et la nouvelle devient principale

Scénario: [CL-09][TR-08 remplacée] Déclarer ses classes
  Étant donné un enseignant dont l'école principale a 6ème 1, 6ème 2 et 3ème B
  Quand il déclare 6ème 1 et 3ème B, puis clique « Terminer la configuration »
  Alors chaque bascule et le compteur se mettent à jour sans rechargement de page
  Et il enseigne exactement ces deux classes
  Et sa configuration est enregistrée comme terminée
  Et il arrive sur /teachers

Scénario: [CL-09] Aucune classe, classe d'une autre école, retrait
  Quand il clique « Terminer la configuration » sans aucune classe déclarée
  Alors il voit « Sélectionnez au moins une classe. » et la configuration n'est pas terminée
  Quand la requête vise une classe d'une autre école ou une classe archivée
  Alors il reçoit 403 et rien ne change
  Quand il retire une classe
  Alors il ne l'enseigne plus, et ses assignations et les sessions des élèves existent toujours

Scénario: [CL-10] Fiche d'une classe
  Étant donné un enseignant qui enseigne « 6ème 1 », qui a un cours et un exercice assignés
  Quand il ouvre la classe
  Alors il voit le nom, l'année, le niveau, l'établissement, le code en majuscules, l'effectif et le plafond, les cours assignés et la liste des élèves
  Et la page répond 200 avec au moins un exercice assigné (non-régression)

Scénario: [CL-10] Accès d'un élève à sa classe
  Quand un élève ouvre sa classe ou son accueil
  Alors il ne voit ni la liste nominative ni le code d'adhésion de sa classe
  Quand il ouvre l'URL de la page enseignant de sa classe
  Alors il reçoit 403

Scénario: [CL-11] Cours dans la classe
  Quand l'enseignant ouvre un cours depuis sa classe
  Alors il voit les fiches essentielles du cours et, pour chacune, « Assigné » ou « Assigner »

Scénario: [CL-12][AS-20] Fiche essentielle dans la classe
  Quand l'enseignant ouvre une fiche essentielle depuis sa classe
  Alors il voit les exercices publiés de la fiche et, pour chacun, « Assigné » ou « Assigner »

Scénario: [CL-16][CL-17][CL-20][AS-18][AS-19] Assigner, retirer, réassigner
  Quand l'enseignant clique « Assigner » sur l'exercice « Méiose » dans « 6ème 1 »
  Alors le bouton devient « Assigné » sans rechargement et le toast dit « Méiose ajouté à 6ème 1. »
  Et la ligne d'assignation est active et son auteur est l'utilisateur connecté
  Quand il poste de nouveau la même assignation
  Alors il voit « Déjà assigné à cette classe » et rien n'est écrit
  Quand il clique « Retirer »
  Alors la ligne est archivée, pas supprimée, et le toast dit « Méiose retiré de 6ème 1. »
  Quand il clique de nouveau « Assigner »
  Alors une nouvelle ligne active est créée, l'ancienne reste archivée, sans erreur d'unicité
  Et chaque réponse est un Turbo Stream qui remplace le bouton, jamais une réponse 204

Scénario: [CL-16] Assigner dans une classe qu'on n'enseigne pas
  Quand un enseignant poste une assignation pour une autre classe
  Alors il reçoit 403 et rien n'est écrit

Scénario: [CL-22] Ma classe (élève)
  Quand un élève ouvre « Ma classe »
  Alors il voit sa classe principale, son établissement, l'année et les cours assignés actifs et publiés, avec leur nombre de fiches essentielles publiées
  Et un cours retiré de la classe ou archivé n'apparaît pas (non-régression)

Scénario: [CL-23][TR-04][AS-36] Accueil élève
  Quand un élève ouvre son accueil
  Alors il voit son établissement, son niveau, sa classe, l'effectif, et les exercices assignés actifs et publiés, directement ou par leur fiche essentielle ou leur cours
  Et pour chaque exercice : la matière, le badge, le meilleur score, le nombre de sessions terminées, et « Reprendre » si une session est en cours
  Et ses 10 dernières sessions terminées, et les fiches essentielles à revoir
```

### 4.6 Catalog

```gherkin
Scénario: [CA-16][CA-18] Gérer les niveaux
  Étant donné une production vierge
  Alors aucun niveau n'existe
  Quand l'équipe crée « 6ème » (position 1, cycle first) dans une modale
  Alors il apparaît dans la liste, triée par position, avec le slug « 6eme », sans rechargement de page
  Quand elle le renomme « Sixième »
  Alors son slug reste « 6eme » : la génération des classes et les imports continuent de le reconnaître
  Quand elle supprime un niveau utilisé par une classe ou un cours
  Alors la suppression est refusée avec la raison

Scénario: [CA-19][CA-24] Gérer les séries et leurs niveaux
  Quand l'équipe crée la série « D » (slug « d ») et coche le couple Tle × D dans la matrice, sans rechargement de page
  Alors la série D est proposée pour la Tle dans les formulaires de classe et de cours
  Quand elle décoche un couple utilisé par une classe ou un cours
  Alors le retrait est refusé avec la raison

Scénario: [CA-20][CA-22][CA-26] Gérer les matières et leur catégorie
  Quand l'équipe crée « SVT » (abrégé SVT) sans catégorie
  Alors la modale se rouvre en 422
  Quand elle choisit la catégorie « Sciences »
  Alors la matière s'affiche partout avec la couleur et l'icône de la catégorie sciences
  Quand elle renomme la matière
  Alors sa couleur et son icône ne changent pas
  Quand elle change sa catégorie en « Autre »
  Alors sa couleur et son icône changent partout

Scénario: [CA-25] Le référentiel depuis l'accueil équipe
  Quand l'équipe ouvre /teams
  Alors la section « Référentiel » affiche les compteurs de DRENA, niveaux, séries et matières
  Et chacun mène à son écran de gestion

Scénario: [CA-01] Parcourir le catalogue publié
  Étant donné un cours publié, un brouillon et un archivé
  Quand un élève ouvre /courses
  Alors il ne voit que le cours publié, sur une carte avec la matière, le niveau, la série, le titre et le sous-titre
  Quand l'équipe ouvre /courses
  Alors elle voit les trois, avec leur statut, et les boutons « Nouveau cours » et « Importer des cours »

Scénario: [CA-04] Consulter un cours
  Quand un élève ouvre un cours publié
  Alors il voit le fil d'Ariane, les badges, le contenu et la liste des fiches essentielles publiées
  Et les formules $…$ sont rendues par KaTeX servi par le bundle de l'application

Scénario: [CA-04] Non-régression : brouillon par URL directe
  Quand un élève ou un enseignant ouvre l'URL d'un brouillon, ou d'une fiche publiée dans un cours brouillon
  Alors il reçoit 404

Scénario: [CA-05] Créer un cours
  Quand l'équipe clique « Nouveau cours » et soumet, dans la modale, Nom, sous-titre, niveau, série, matière et contenu
  Alors le cours existe en brouillon, son auteur est l'utilisateur connecté et son nom est enregistré sans changement de casse
  Et le catalogue le montre, sans rechargement de page, avec le libellé « Brouillon — visible uniquement par l'équipe »

Scénario: [CA-06] Modifier et publier un cours
  Quand l'équipe modifie le nom puis clique « Publier »
  Alors le panneau de statut passe à « Publié » sans rechargement de page
  Et le cours relu par le même agrégat porte le nouveau nom et une date de publication

Scénario: [CA-07] Archiver et republier un cours
  Étant donné un cours assigné à une classe
  Quand l'équipe l'archive
  Alors il n'apparaît plus aux élèves ni aux enseignants
  Et ses fiches essentielles, ses exercices et ses assignations existent toujours en base
  Quand elle le republie
  Alors il réapparaît ; aucun retour au brouillon n'est possible

Scénario: [CA-08][TR-28] Importer des cours complets
  Étant donné le référentiel complet
  Quand l'équipe importe un fichier lnclass.course-tree v1 de 3 cours, avec leurs fiches essentielles, exercices, questions et propositions
  Alors tout est créé en brouillon, quelle que soit la clé status du fichier, et l'auteur est l'utilisateur connecté
  Et un cours déjà présent (même nom normalisé, niveau, matière et série) est ignoré et compté comme doublon
  Et la matière « Physique Chimie » est reconnue par son slug « physique-chimie »

Scénario: [CA-08] Import partiel : un fichier mixte donne un rapport exact
  Étant donné un fichier de 10 cours dont le 2e contient une question à choix unique avec 2 propositions correctes au chemin courses[1].essentials[0].exercises[2].questions[3], le 5e une matière inconnue, et le 8e un cours déjà en base
  Quand l'équipe l'importe
  Alors le rapport est « Terminé » avec 7 importés, 1 ignoré, 2 en erreur et un total de 10
  Et chaque erreur est listée à son chemin avec son motif
  Et les 7 cours valides existent avec toute leur descendance
  Et les 2 cours invalides n'ont laissé ni cours, ni fiche essentielle, ni exercice, ni question, ni proposition

Scénario: [CA-08] Import en masse dans le budget
  Quand l'équipe importe 200 cours complets (8 fiches essentielles, 2 exercices par fiche, 10 questions, 4 propositions)
  Alors l'import est terminé en moins de 2 minutes

Scénario: [CA-10][CA-11] Fiches essentielles d'un cours, fiche et progression
  Quand un élève ouvre une fiche essentielle publiée
  Alors il voit son contenu et ses exercices publiés
  Et pour chaque exercice son badge et son meilleur score, et « Commencer » ou « Reprendre »
  Et l'étiquette « Assigné par ton enseignant » sur les exercices assignés à sa classe

Scénario: [CA-12][CA-13][CA-14] Créer, modifier, publier, archiver une fiche essentielle
  Alors seule l'équipe atteint ces actions ; un enseignant ou un élève reçoit 403
  Et deux fiches essentielles du même cours ne peuvent pas porter le même nom
  Et publier une fiche essentielle d'un cours brouillon est refusé
  Et archiver une fiche essentielle conserve ses exercices et leurs sessions

Scénario: [CA-15][TR-28] Importer des fiches essentielles dans un cours
  Quand l'équipe clique « Importer des fiches essentielles » sur la page d'un cours et importe un fichier lnclass.essentials v1 dont l'enveloppe désigne ce cours par son slug
  Alors les fiches essentielles et leurs exercices sont créés en brouillon dans ce cours, à la suite des fiches existantes
  Et une fiche essentielle déjà présente dans le cours est ignorée et comptée
  Et une fiche invalide est listée avec son chemin, sans empêcher les autres
  Quand le slug du cours de l'enveloppe est inconnu
  Alors le rapport est « Rejeté » et rien n'est écrit

Scénario: [CA-27] Assigner un cours depuis sa page
  Quand un enseignant ouvre un cours publié puis « Assigner à mes classes »
  Alors il voit chacune de ses classes actives avec « Assigné » ou « Assigner »
  Et le bouton fonctionne (non-régression : il était inatteignable)

Scénario: [UDR-0007] Vocabulaire d'interface
  Alors aucune vue ni locale de la V1 ne contient « Habileté », « Notion clé », « Leçon », « Quiz », « Essai », « Platine », « Médaille » ni « Trophée »
  Et « Fiche » n'apparaît jamais seul dans un titre
```

### 4.7 Assessment

```gherkin
Scénario: [AS-02] Détail d'un exercice
  Quand un élève ouvre un exercice publié
  Alors il voit le titre, la description, le nombre de questions, son meilleur score, sa maîtrise, son badge et « Commencer » ou « Reprendre »

Scénario: [AS-39] Aperçu des questions, sans fuite
  Quand l'équipe ouvre un exercice
  Alors elle voit les questions avec les propositions correctes marquées
  Quand un enseignant ouvre un exercice, assigné ou non à ses classes
  Alors il voit les questions sans marque de proposition correcte
  Et le critère TR-cadre-3 est vert

Scénario: [AS-03] Créer un exercice complet
  Quand l'équipe crée l'exercice « Méiose » dans une fiche essentielle, avec une question Vrai/Faux et une question à choix unique de 3 propositions, dans une grande modale
  Alors l'exercice, ses 2 questions et leurs 5 propositions sont enregistrés en une transaction, en brouillon
  Et « + Ajouter une question » et « + Ajouter une proposition » fonctionnent sans rechargement
  Et la modale se ferme, un toast confirme, et la fiche essentielle montre l'exercice, sans rechargement de page
  Et le titre est enregistré sans changement de casse

Scénario: [AS-03] Règles structurelles
  Alors Vrai/Faux exige exactement 2 propositions dont 1 correcte
  Et choix unique exige au moins 2 propositions dont exactement 1 correcte
  Et 2 propositions correctes exige au moins 3 propositions dont exactement 2 correctes
  Et 3 propositions correctes exige au moins 4 propositions dont exactement 3 correctes
  Et un exercice sans question, ou dont la fiche essentielle n'est pas publiée, ne peut pas être publié
  Et une question invalide rouvre la modale en 422 sans rien enregistrer

Scénario: [AS-04] Modifier un exercice
  Étant donné un exercice sans session
  Quand l'équipe remplace une question
  Alors l'exercice relu contient la nouvelle question et plus l'ancienne
  Étant donné un exercice qui a une session
  Alors les questions sont verrouillées : le formulaire n'offre plus que le titre et la description

Scénario: [AS-05] Archiver un exercice
  Alors le critère TR-cadre-6 est vert
  Et aucune route ne supprime un exercice

Scénario: [AS-06 remplacée][TR-28] Importer des exercices dans une fiche essentielle
  Quand l'équipe clique « Importer des exercices » sur une fiche essentielle et importe un fichier lnclass.exercises v1 dont l'enveloppe désigne cette fiche par son slug
  Alors les exercices, leurs questions et leurs propositions sont créés en brouillon dans cette fiche
  Et un exercice dont une question est mal formée est listé en erreur avec le chemin de la question, et n'a laissé aucune ligne
  Et les autres exercices du fichier sont importés, et le rapport est exact

Scénario: [AS-07] Démarrer une session
  Quand un élève démarre un exercice publié, assigné ou non à sa classe
  Alors une session « started » existe, avec le nombre de questions figé
  Et elle est rattachée à l'assignation active de sa classe s'il en existe une
  Et il voit la question de position la plus basse, avec une progression à 0 %

Scénario: [AS-07] Refus
  Quand un élève démarre un exercice en brouillon, ou publié dans une fiche essentielle en brouillon
  Alors il reçoit 404 et aucune session n'est créée
  Quand un enseignant tente de démarrer une session
  Alors il reçoit 403

Scénario: [AS-08] Reprendre
  Étant donné une session en cours avec 1 question répondue sur 2
  Quand l'élève clique « Reprendre »
  Alors il voit la 2e question
  Quand il clique « Recommencer »
  Alors l'ancienne session passe à « abandoned » et une nouvelle commence

Scénario: [AS-09] Répondre une fois
  Quand l'élève valide une réponse à la question 1
  Alors une tentative est enregistrée avec les identifiants choisis et son heure
  Quand il soumet à nouveau la question 1, par double clic ou depuis un autre onglet
  Alors la tentative n'est pas modifiée, aucun doublon n'existe et le score n'en tient pas compte
  Et l'unicité (session, question) est garantie par un index en base

Scénario: [AS-09] Réponse vide
  Quand il valide sans rien cocher
  Alors il reçoit 422 dans le cadre Turbo avec « Sélectionne au moins une proposition. », sans rechargement de page

Scénario: [AS-09] Widgets
  Alors Vrai/Faux et choix unique s'affichent en boutons radio
  Et 2 ou 3 propositions correctes s'affichent en cases à cocher avec « Plusieurs propositions correctes »
  Et l'ordre des propositions est mélangé, mais stable pour une même session

Scénario: [AS-10] Correction immédiate
  Quand l'élève valide une réponse
  Alors il voit, sans rechargement de page, « Bonne réponse » ou « Mauvaise réponse », les propositions correctes de cette question et l'explication
  Et la correction exige l'égalité exacte des ensembles d'identifiants, sans crédit partiel
  Et les propositions correctes d'une question non encore tentée ne figurent jamais dans le HTML

Scénario: [AS-11][AS-12] Clôture automatique, résultat et badge
  Étant donné 2 questions dont 1 déjà répondue correctement
  Quand l'élève répond correctement à la dernière
  Alors la session est terminée dans la même requête, avec un score de 100 % et une note de 20/20
  Et la correction propose « Voir mon résultat »
  Et le résultat affiche « Félicitations ! », la maîtrise « Acquis », le badge « Diamant » et les confettis pendant 3 secondes
  Et le détail question par question
  Et aucune session « completed » n'existe sans score

Scénario: [AS-11] Barème et remplacement
  Alors un score de 100 donne Diamant, de 80 à 99 Or, de 70 à 79 Argent, de 50 à 69 Bronze, en dessous « Non acquis »
  Et 9 bonnes réponses sur 10 donnent 90 % et Or, jamais Diamant
  Et un badge existant n'est remplacé que par un niveau strictement supérieur
  Et le badge gagné s'affiche sur le résultat, l'accueil élève et la fiche essentielle (non-régression : badge jamais affiché)

Scénario: [AS-11] Lacune de connaissance
  Étant donné un élève qui termine une session avec 40 %
  Alors une lacune « à revoir » est ouverte sur la fiche essentielle de l'exercice
  Et elle apparaît sur son accueil dans « Fiches essentielles à revoir »
  Quand il obtient ensuite au moins 70 % sur un exercice de cette fiche
  Alors la lacune est résolue

Scénario: [AS-12] Échec
  Étant donné un score de 40 %
  Alors il voit « Courage ! », « En difficulté », « Non acquis », aucun confetti, et « Recommencer »

Scénario: [AS-13] Recommencer
  Étant donné un score inférieur à 100
  Quand l'élève clique « Recommencer »
  Alors une nouvelle session commence, et l'ancienne reste terminée avec son score

Scénario: [AS-12][AS-39] Lecture d'une session
  Alors l'élève propriétaire, l'enseignant d'une classe active de l'élève et l'équipe peuvent voir le résultat
  Et l'enseignant voit le score, la note et la maîtrise, sans les propositions correctes
  Et un autre élève reçoit « Accès interdit. » avec un statut 403

Scénario: [AS-37] Exercices non publiés
  Alors aucun exercice en brouillon ou archivé n'est listé à un élève, sur la fiche essentielle comme sur l'accueil
```

### 4.8 Transverse

**Exigence transverse — tout CRUD passe par Hotwire** (règle du porteur, UDR-0006, brief standard §5). Elle s'applique à chaque écran de la V1 qui crée, modifie, supprime ou fait changer d'état une donnée :

- création et édition dans la modale du layout (`turbo_frame_tag "modal"`), jamais sur une page `new` ou `edit` autonome ;
- erreurs re-rendues en 422 dans la modale, avec les valeurs saisies ;
- succès en Turbo Stream : un toast, la liste ou le panneau mis à jour, le formulaire refermé ou réinitialisé ; jamais de redirection depuis la modale ;
- filtres, recherche et pagination dans un cadre Turbo, l'URL gardant l'état ;
- une réponse HTML de repli pour chaque action ;
- Stimulus seulement pour ce que Turbo ne couvre pas (champs imbriqués, copie, rechargement périodique) ;
- **preuve** : un test système par écran concerné montre que le parcours se fait sans rechargement de page.

```gherkin
Scénario: [TR-01] Landing
  Quand un visiteur ouvre /
  Alors il voit les deux entrées « Je suis élève » et « Je suis enseignant »
  Et la modale élève propose « Se connecter » et « Rejoindre ma classe », la modale enseignant « Se connecter » et « Créer un compte »
  Et aucun lien de la page ne pointe vers une route inexistante

Scénario: [TR-05] Accueil enseignant
  Quand un enseignant configuré ouvre /teachers
  Alors il voit ses classes, avec pour chacune l'effectif, le nombre d'assignations actives et le score moyen
  Et un lien vers « Modifier mes classes »

Scénario: [TR-09] Accueil équipe
  Quand l'équipe ouvre /teams
  Alors elle voit les compteurs de DRENA, d'établissements et de classes, la section « Référentiel », et les 5 derniers cours, exercices et imports
  Et les raccourcis « Nouveau cours », « Établissements », « Importer », « Inviter un membre », « Débloquer un compte »

Scénario: [TR-27] Navigation par rôle
  Alors chaque rôle voit les mêmes destinations dans la barre latérale et dans la barre du bas
  Et l'entrée « Établissements » de l'équipe est active et mène à la liste nationale
  Et une destination d'une vague future est affichée inactive, jamais en lien mort

Scénario: [TR-28] Imports en arrière-plan, partiels
  Quand l'équipe téléverse un fichier d'import dans la modale d'import
  Alors la modale affiche le suivi du rapport, sans rechargement de page, qui se recharge seul toutes les 3 secondes tant que l'import n'est pas fini
  Et les statuts sont « En file d'attente », « Vérification », « Import en cours », puis « Terminé », « Rejeté » ou « Échoué »
  Et le fichier est traité par le worker, jamais dans la requête web
  Et le rapport persiste le type, le fichier, son empreinte, l'auteur, les dates, la version du format, les compteurs (total, importés, ignorés, en erreur, traités), le détail et au plus 1 000 erreurs
  Et le total est toujours la somme des importés, des ignorés et des erreurs
  Et un fichier de plus de 20 Mo est refusé au téléversement
  Et un fichier au-delà du nombre d'éléments permis pour son type est « Rejeté »
  Et un second import du même type pendant qu'un premier tourne est refusé : « Un import de ce type est déjà en cours »
  Et un import interrompu depuis plus de 30 minutes passe « Échoué » au lancement du suivant

Scénario: [TR-28] Atomicité par élément racine
  Étant donné un lot de 100 établissements dont l'un voit son code d'adhésion pris par une création concurrente
  Quand l'écriture du lot échoue en base
  Alors le lot est rejoué élément par élément
  Et seul l'établissement en collision est en erreur, avec le motif « écriture refusée »
  Et aucun élément racine n'est jamais écrit à moitié

Scénario: [Hotwire] Aucun CRUD ne recharge la page
  Étant donné un écran de création, de modification, de suppression ou de transition de la V1
  Quand l'utilisateur ouvre le formulaire
  Alors il s'affiche dans la modale du layout, chargée dans son cadre
  Quand il le soumet avec une erreur
  Alors la modale se rouvre en 422 avec les erreurs et les valeurs saisies
  Quand il le soumet correctement
  Alors la réponse est un Turbo Stream : un toast, la liste ou le panneau mis à jour, la modale fermée
  Et la fenêtre n'a pas été rechargée
  Et la même action, sans Turbo, répond en HTML par une redirection
  Et chaque écran concerné a un test système qui le prouve

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
  Alors créer, lire, modifier, publier et archiver un cours passent par la même entité et le même repository, dans un seul test d'intégration

Scénario: [classroom-assignment-belongs-to-casses] Repository d'assignation
  Alors le repository d'assignation est couvert à 100 %, branches comprises, avec les trois types de ressource

Scénario: [classroom-code-adhesion-trop-long] Code et colonne
  Alors un test de schéma vérifie que la longueur de la colonne du code égale la longueur du code généré

Scénario: [dette-contrats-ports-et-injection] Ports et injection
  Alors chaque port a un test de contrat qui vérifie que son repository implémente toutes ses méthodes avec les mêmes paramètres
  Et aucun fichier de app/domain ne mentionne Repositories::, Queries::, Orm:: ni ActiveRecord
```

## 5. Modélisation préliminaire

Le détail exécutable est dans [`plan.md`](plan.md), sous-lots 0a, 0b, 0d et 0e.

| Couche | Éléments prévus |
|---|---|
| Domaine | `Shared::Result` ; entités et objets-valeurs de 5 contextes (identity, school, classroom, catalog, assessment), dont `DefaultClassroomPlan`, `ImportKind`, `ImportItem`, `ContentNode`, `NaturalKey` ; 27 ports, plus `TransactionPort` ; 23 policies `call(actor:, **faits)` ; DTO `…Input` par formulaire ; use cases par lot ; moteur d'import (`StartImport`, `RunImport`) et 4 adaptateurs derrière un contrat commun |
| Infrastructure | 31 migrations ; modèles `Orm::` ; un repository par port (TOTP, fichier, schéma et file d'attente compris, sans dossier `adapters/`) ; écritures en masse par `insert_all`, par lots de 100 éléments racines ; queries de lecture par écran ; seeds d'amorçage (production) et de développement (local seulement) |
| Delivery | 7 fichiers de routes dessinés en entier au socle, dont `teams.rb` ; socle d'authentification ; `Teams::BaseController` ; job de base `Shared::ImportJob` et un job par type ; un contrôleur par écran |
| UI | Shell par rôle et composants du Lot 0c ; vues ERB par lot, CRUD en modales avec réponses `*.turbo_stream.erb` ; rafraîchissement par morphing ; écran de suivi des imports ; contrôleurs Stimulus chargés par motif |

## 6. Décisions rattachées

Toutes acceptées le 2026-09-25, sauf mention contraire.

- ADR-0026 — `Shared::Result`, queries de lecture, DTO `…Input`, transactions (F-01, F-03)
- ADR-0027 — Contextes bornés et arborescence (F-02) — **erratum** du 2026-09-25 : `TransactionPort` dans `app/domain/ports/shared/`
- ADR-0028 — Policies de domaine `call(actor:, **faits)` (F-04) — **amendé** le 2026-09-25 : huit policies ajoutées (voir [`plan.md`](plan.md), « Décisions que ce plan suppose »)
- ADR-0029 — `public_id` de 14 caractères et slugs figés (F-05)
- ADR-0030 — Une école principale par enseignant, déclaration des classes, établissements et génération des classes (F-06)
- ADR-0031 — TOTP et codes de secours pour l'équipe (F-07)
- ADR-0032 — Récupération assistée du PIN (F-08)
- ADR-0033 — Barème à 4 paliers et seuils pédagogiques (F-10, F-11)
- ADR-0034 — Référentiel et seeds (F-12) : aucun seed de référentiel ni d'établissement en production ; les DRENA se créent à l'écran
- ADR-0035 — Cycle de vie du contenu `draft/published/archived` (F-13)
- ADR-0036 — Suppression restreinte et archivage (F-14)
- ADR-0037 — Nom et Prénom(s) (F-15)
- ADR-0038 — Rôles et invitations (F-16)
- ADR-0039 — Import de contenu (TR-28) : quatre types, import partiel atomique par élément racine, rapport exact — **erratum** du 2026-09-25 : la colonne `errors` s'appelle `import_errors` ; un test de performance par type
- ADR-0040 — Adhésion par code
- ADR-0041 — Classes, année scolaire, plafond, code d'adhésion
- ADR-0043 — Lacunes de connaissance
- ADR-0047 — Stockage des fichiers (S3 Railway)
- ADR-0048 — Assignations `active/archived`, nouvelle ligne à la réassignation (F-26)
- ADR-0050 — Authentification, contact, session et verrouillage (F-28)
- ADR-0051 — Navigateurs et budget des assets
- ADR-0052 — Chaîne de livraison et worker toujours actif
- ADR-0054 — Moteur d'évaluation et clôture automatique (F-34)
- UDR-0005 — Design system (F-09)
- UDR-0006 — Shell par rôle, toasts et CRUD par Hotwire (F-31) — **amendé** le 2026-09-25 : l'entrée « Établissements » est active en V1
- UDR-0007 — Vocabulaire d'interface (F-32)
- UDR-0008 à UDR-0040 — une UDR par écran, écrite par le lot qui le livre (numéros réservés dans [`plan.md`](plan.md))

## 7. Mesures

| Métrique | Avant (ancienne app) | Cible V1 |
|---|---|---|
| Parcours bout en bout équipe → enseignant → élève, sur base vierge | impossible (questions jamais persistées) | vert en test système Chrome headless |
| Accueils par rôle qui répondent 200 | 1 sur 3 | 3 sur 3 |
| Import de 500 établissements (≈ 35 000 classes) | import synchrone, élèves de démonstration créés, sans rapport | < 2 min, partiel, rapport exact persisté |
| Import de 200 cours complets | import synchrone ligne à ligne | < 2 min, partiel, rapport exact persisté |
| Écritures (CRUD) qui rechargent la page | la plupart | aucune (test système par écran) |
| Couverture lignes et branches | non mesurée | 100 % (ADR-0024) |
| JS de l'application, gzip | 622 Ko non compressés | dans le budget de l'ADR-0051 |
