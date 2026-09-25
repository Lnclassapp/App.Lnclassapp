# Memo — Boucle pédagogique (V1)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-09-25 |
| **Branche** | `feature/boucle-pedagogique` |
| **Programme** | `refonte-application` — vague V1 ([feuille de route §5](../refonte-application/feuille-de-route.md#v1--boucle-pédagogique)) |

---

## Le problème

Dans l'ancienne application, la boucle qui justifie Lnclass ne tourne pas de bout en bout :

- l'équipe ne peut pas créer un exercice complet : les questions ne sont jamais enregistrées ;
- l'enseignant ne peut pas ouvrir la fiche d'une de ses classes dès qu'un exercice y est assigné ;
- l'élève n'a pas d'accueil qui fonctionne : il lève une exception, ou il boucle entre deux redirections ;
- l'élève peut soumettre à nouveau une réponse après avoir vu le corrigé ;
- les bonnes réponses peuvent lui être servies par le cache d'un enseignant.

Autour de cette boucle, les fondations sont fragiles :

- aucune limite de débit à la connexion ;
- la session n'est pas renouvelée à la connexion ;
- un PIN oublié fait perdre le compte ;
- un compte équipe n'a aucun second facteur ;
- la suppression d'un contenu détruit l'historique des élèves ;
- l'autorisation est dispersée dans les contrôleurs.

Le nouveau dépôt est vide : aucune table, aucun écran connecté.

## Pour qui

| Acteur | Moment du parcours |
|---|---|
| **Team** (équipe Lnclass) | Crée le référentiel (niveaux, séries, matières), les DRENA et les établissements, un par un ou par import JSON en masse ; chaque établissement reçoit ses classes par défaut. Publie des cours, leurs fiches essentielles et leurs exercices, saisis ou importés. Invite un collègue. Débloque un compte dont le PIN est perdu. |
| **Teacher** | S'inscrit, choisit son établissement et déclare les classes où il enseigne. Ouvre une classe, assigne un cours, une fiche ou un exercice. Débloque le PIN d'un de ses élèves. |
| **Student** | S'inscrit avec le code de sa classe. Voit sur son accueil ce qui lui est assigné. Fait l'exercice, voit la correction immédiate, puis son résultat et son badge. |
| **Visiteur** | Découvre la page d'accueil. Choisit « élève » ou « enseignant ». Se connecte ou crée son compte. |

## Pourquoi maintenant

La V1 est la première vague qui livre de la valeur. Toutes les vagues suivantes s'appuient sur ses tables, ses contrats de port, son authentification et son shell :

- V2 : organisation scolaire ;
- V3 : suivi enseignant ;
- V4 : back-office de contenu ;
- V5 : remédiation ;
- V6 : communication.

Tant qu'elle n'est pas livrée, aucun élève réel ne peut utiliser la nouvelle application.

## Hors périmètre

- **Aucun seed de référentiel, de DRENA ni d'établissement en production** (choix du porteur du 2026-09-25). La production démarre vide : l'équipe crée ou importe tout. Les seeds `catalog.rb`, `school.rb` et `development.rb` sont réservés au local.
- **Aucune écriture du référentiel hors de l'équipe.** Pas de page publique de niveau, de série ni de matière (CA-17, CA-21, CA-23 : V2 et V4).
- **Aucune inscription par listes en cascade** école + niveau → classe. Un code de classe valide est obligatoire.
- **Aucune route publique** qui crée un compte équipe. L'équipe naît par seed, puis par invitation.
- **Aucun espace direction d'établissement** (`school_admin`). Il est prévu en V2. Ses entrées de navigation restent inactives.
- **Aucun téléversement de média** : pas d'avatar, de couverture ni d'audio. Le seul fichier téléversé est le JSON d'import, réservé à l'équipe et stocké sur S3 (ADR-0047).
- **Pas de modification de profil ni de changement volontaire de PIN** (V2). Seule la récupération assistée existe.
- **Pas d'import d'élèves ni d'enseignants**, ni de DRENA (SC-02 écartée : les 41 DRENA se créent à l'écran). Pas d'export. Un import n'est **pas** tout ou rien : les éléments valides sont écrits (le contenu en brouillon), les invalides listés dans le rapport.
- Pas d'annonces (V6), ni de tableau de bord équipe à KPI (V4, TR-10).
- **Pas de suivi détaillé** des élèves par l'enseignant (V3), ni de remédiation (V5). Les lacunes sont écrites et montrées à l'élève, pas encore à l'enseignant (V3).
- **Pas de partage WhatsApp** du lien de classe (V3), ni d'examens ou de Prepa BAC.
- **Pas de mode sombre**, pas de PWA installable (V4), pas de validation collaborative.
- **Pas d'historique des badges** : un badge par élève et par exercice, remplacé seulement par un niveau strictement supérieur.

## Ce que le grill a révélé

| Question posée | Réponse (recommandation adoptée) | Conséquence sur le chantier |
|---|---|---|
| Un élève peut-il rejoindre une classe sans code, en choisissant son école puis sa classe dans des listes ? | Non. Le PRD cadre exige un code de classe valide. La cascade est écartée (écart n° 4 de la feuille de route). | L'inscription élève n'a qu'un chemin : le code, saisi ou reçu par lien. La vérification en direct du code est limitée en débit et ne renvoie que le nom de la classe et celui de l'école. |
| Qui crée les classes, si l'enseignant ne fait que les déclarer ? | L'équipe, pour le compte de l'établissement : ses classes par défaut sont générées à sa création, d'autres s'ajoutent à l'écran. L'enseignant coche parmi les classes de son école principale. | Un écran équipe de création de classe entre en V1. Sans lui, aucun code d'adhésion n'existe. |
| Un enseignant peut-il enseigner dans plusieurs établissements ? | Le modèle le permet, un seul est visible en V1 : l'école principale (ADR-0030). | La table de rattachement enseignant–établissement porte un drapeau « principale », unique par enseignant. La déclaration des classes ne remplace que celles de l'école principale. |
| Que devient un exercice « supprimé » que des élèves ont déjà fait ? | Il est archivé, jamais supprimé (ADR-0036). Ses sessions, tentatives et badges sont conservés. | Aucun bouton « Supprimer » : partout « Archiver ». Aucune suppression en cascade vers l'historique. |
| Peut-on modifier les questions d'un exercice déjà fait par des élèves ? | Non. Une tentative est immuable (ADR-0054). Changer une question fausserait les scores passés. | Tant qu'aucune session n'existe, les questions se modifient librement. Dès la première session, seuls le titre, la description et le statut restent modifiables. |
| Quand l'élève voit-il la bonne réponse ? | Seulement après avoir répondu à la question. Hors correction, seule l'équipe la voit ; l'enseignant ne la voit pas (ADR-0028). | Aucun fragment de cache ne contient les bonnes réponses sans que le rôle entre dans la clé. Un test vérifie le HTML servi à l'élève et à l'enseignant, cache actif. |
| Que se passe-t-il si un élève oublie son PIN ? | Son enseignant, ou l'équipe, génère un code à usage unique valable 15 minutes (ADR-0032). L'élève le saisit avec son numéro, puis choisit un nouveau PIN. | La récupération fait partie du socle d'authentification. Chaque génération et chaque utilisation sont journalisées. Toutes les sessions ouvertes sont fermées. |
| Un compte équipe peut-il se connecter avec son seul PIN ? | Non. Le TOTP est obligatoire, avec des codes de secours (ADR-0031). | Tant que le second facteur n'est ni enrôlé ni vérifié, un compte équipe n'accède à aucune page de son espace. |
| Faut-il que l'exercice soit assigné pour que l'élève le démarre ? | Non. Tout exercice publié est démarrable ; l'assignation oriente l'accueil (ADR-0028). | `StartSessionPolicy` ne regarde que le statut de publication de l'exercice et de ses parents. La session garde l'assignation active si elle existe. |
| Quels badges, et quand la session se termine-t-elle ? | Quatre paliers : Bronze ≥ 50, Argent ≥ 70, Or ≥ 80, Diamant = 100 (ADR-0033). La dernière réponse clôt la session (ADR-0054). | Pas de bouton « Terminer » ni de clôture prématurée. Le barème est un objet de domaine testé par bornes. |
| D'où viennent les DRENA, les établissements et les classes en production ? | De l'équipe, par écran ou par import JSON. Créer un établissement génère ses classes par défaut, sans élève de démonstration. | Le référentiel, les établissements et les imports entrent en V1. `DefaultClassroomPlan` applique la table de l'ADR-0030 (lycée public 77 classes, privé et mixte 38, collège public 28), par slug de niveau et liaison `level_series` ; un niveau absent du référentiel est sauté. |
| Comment importer 500 établissements ou 200 cours sans bloquer l'application ? | Dans un job Solid Queue (`Shared::ImportJob`), un import actif par type, avec un rapport persisté et un écran de suivi rechargé toutes les 3 s (ADR-0039). | Moteur commun au Lot 0 (0e) ; un adaptateur par type d'import dans son lot, chacun avec son propre test de performance (`test/performance/<ctx>/import_<kind>_performance_test.rb`, < 2 min, joué avec `PERF=1`). |
| Un fichier qui contient quelques éléments faux est-il rejeté en entier ? | Non : l'import est **partiel**. Les éléments valides sont écrits ; les invalides sont listés avec leur chemin JSON et leur motif ; les doublons sont ignorés et comptés. Seule une enveloppe ou une version invalide rejette le fichier en bloc. | Atomicité par élément racine : écriture par lots de 100 racines, rejeu élément par élément si un lot échoue (`TransactionPort#attempt`). Chaque lot d'import prouve qu'un fichier mixte donne un rapport exact. |
| L'enseignant et l'élève voient-ils le code de la classe ? | L'enseignant et l'équipe oui ; l'élève non : il est déjà inscrit, le code ne lui sert à rien et ne doit pas circuler par lui. | La page « Ma classe » de l'élève n'affiche aucun code ; un test le vérifie. |
| Comment les écrans d'écriture se comportent-ils ? | Tout CRUD passe par Hotwire : formulaire dans une modale (frame), erreurs en 422 dans le frame, réponse `turbo_stream` (toast, liste, formulaire), repli HTML, Stimulus seulement quand Turbo ne suffit pas. | Exigence transverse du PRD (§4.8). Chaque lot à écran d'écriture livre ses `*.turbo_stream.erb`, un critère « sans rechargement de page » et un test système. |
| Qui gère le référentiel ? | L'équipe seule, avec des slugs et des codes figés. | `ManageTaxonomyPolicy` ; suppression refusée si l'élément est référencé ; renommer ne change pas le slug, figé à la création. |
| Un visiteur sans compte peut-il passer la `JoinPolicy` ? | Oui : c'est le cas nominal. La policy accepte le visiteur anonyme, et l'élève dont la classe principale est archivée. | L'aperçu `/c/:code` et l'inscription passent par la même policy, avant toute écriture. |
| Comment l'enseignant sait-il qu'il a fini de s'installer ? | Par un état enregistré, pas par une déduction « il n'a encore aucune classe ». | Un enseignant qui n'a pas terminé sa configuration arrive sur la déclaration de ses classes. Aucun écran ne renvoie vers la page qui l'a redirigé : chaque état incomplet a un écran de sortie. |

## Cas limites identifiés

- Un code de classe saisi en majuscules, avec des espaces, ou contenant un `i` ou un `o`.
- Un numéro saisi avec l'indicatif `225` ou `00225`, avec des espaces ou des points.
- Un PIN et sa confirmation différents.
- Deux élèves qui s'inscrivent au même moment avec le même numéro : l'un réussit, l'autre reçoit une erreur de formulaire, jamais une page 500.
- Un enseignant qui soumet une déclaration vide, ou une déclaration qui contient une classe d'une autre école.
- Assigner une ressource déjà assignée, retirer une ressource non assignée, réassigner une ressource retirée.
- Un double clic sur « Valider » pour la même question, ou deux onglets ouverts sur la même session.
- Une réponse vide soumise en Turbo.
- Un exercice archivé pendant qu'un élève est en pleine session.
- Un cours en brouillon ouvert par son URL directe par un élève ou un enseignant.
- Un élève sans classe principale, ou un enseignant sans école : chacun a un écran de sortie, jamais une boucle de redirection.
- Une invitation équipe expirée, déjà acceptée, ou adressée à un numéro qui a déjà un compte.
- Deux inscriptions simultanées sur la dernière place d'une classe pleine.
- Un fichier d'import valide jusqu'au 499e élément et faux au 500e : 499 éléments écrits, le 500e listé avec son chemin JSON et son motif.
- Un fichier d'import dont l'enveloppe (`format`, `version`) est invalide : rejeté en bloc, rien n'est écrit.
- Le même fichier d'import téléversé deux fois : le second import compte tout en doublons. Deux imports du même type lancés en même temps : le second est refusé (`:conflict`).
- Un code d'adhésion ou un slug pris par un écran pendant un import : seul l'élément en collision échoue.
- Un job tué en plein import : le rapport passe en échec au bout de 30 min, et la relance compte en doublons ce qui était déjà écrit.
- Un fichier d'établissements au format de l'ancienne application (tableau nu, secteur « privée », nom en « Collège… »).
- Un établissement créé alors qu'un niveau ou une série de la table de génération manque au référentiel.
- La suppression d'un niveau, d'une série, d'une matière, d'une DRENA ou d'un établissement référencé.

## Questions encore ouvertes

- **Genre** : `users.gender` est conservé, obligatoire (`male`, `female`). À confirmer (ADR-0037).
- **Amendements à écrire avant le Lot 0a** :
  - UDR-0006 : l'entrée « Établissements » (`schools_path`) de la navigation équipe devient active en V1 ;
  - ADR-0028 : policies ajoutées (`DeclareTeachingPolicy`, `IssuePinRecoveryCodePolicy`, `ResetSecondFactorPolicy`, `RegisterTeacherPolicy`, `ReadClassroomPolicy`, `SubmitAttemptPolicy`, `Identity::SessionPolicy`, `Identity::SecondFactorPolicy`) ;
  - ADR-0039 (erratum) : la colonne `errors` s'appelle `import_errors`.

### Questions résolues le 2026-09-25

- **Séries et codes du référentiel** : repris de l'ADR-0034 (A et C liées à la 2nde). Pas de colonne `code` : le slug figé à la création en tient lieu (`6eme`, `2nde`, `tle`…). « Par série » désigne une liaison `level_series`.
- **Nombre de classes générées** : ADR-0030 — lycée public 77, privé 38, mixte 38, collège public 28, noms espacés (« Tle D 3 »).
- **Limites d'import** : ADR-0039 — 20 Mo ; 5 000 écoles, 500 cours, 2 000 fiches, 10 000 exercices par fichier.
- **Import partiel** : validé par le porteur ; la remédiation (ADR-0043, V5) est validée telle quelle.
- **Enseignant et bonnes réponses** : l'ADR-0028 accepté les lui refuse.
- **Clés Active Record Encryption** : ajoutées aux credentials par l'orchestrateur (`db:encryption:init`) ; le porteur n'a rien à fournir. Des clés de test fixes vivent dans `config/environments/test.rb`.
- **Données d'exemple** : les fichiers `.Business` de l'ancienne application servent d'exemples et de données de développement et de test, jamais de seed de production.
