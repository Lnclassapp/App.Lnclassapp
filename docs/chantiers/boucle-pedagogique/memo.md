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
| **Team** (équipe Lnclass) | Publie un cours, ses fiches et leurs exercices. Crée les classes des établissements. Invite un collègue. Débloque un compte dont le PIN est perdu. |
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

- **Aucune écriture sur le référentiel.** Niveaux, séries, matières, DRENA et établissements sont seedés et lus seulement. Leurs écrans de gestion sont en V2.
- **Aucune inscription par listes en cascade** école + niveau → classe. Un code de classe valide est obligatoire.
- **Aucune route publique** qui crée un compte équipe. L'équipe naît par seed, puis par invitation.
- **Aucun espace direction d'établissement** (`school_admin`). Il est prévu en V2. Ses entrées de navigation restent inactives.
- **Aucun téléversement de fichier** : pas d'avatar, de couverture ni d'audio. F-25 ne s'applique donc pas.
- **Pas de modification de profil ni de changement volontaire de PIN** (V2). Seule la récupération assistée existe.
- **Pas d'import JSON en masse** (V2 et V4), ni d'annonces (V6), ni de tableau de bord équipe à KPI (V4).
- **Pas de suivi détaillé** des élèves par l'enseignant (V3), ni de lacunes ou de remédiation (V5).
- **Pas de partage WhatsApp** du lien de classe (V3), ni d'examens ou de Prepa BAC.
- **Pas de mode sombre**, pas de PWA installable (V4), pas de validation collaborative.
- **Pas d'historique des badges** : un badge par élève et par exercice, remplacé seulement par un niveau strictement supérieur.

## Ce que le grill a révélé

| Question posée | Réponse (recommandation adoptée) | Conséquence sur le chantier |
|---|---|---|
| Un élève peut-il rejoindre une classe sans code, en choisissant son école puis sa classe dans des listes ? | Non. Le PRD cadre exige un code de classe valide. La cascade est écartée (écart n° 4 de la feuille de route). | L'inscription élève n'a qu'un chemin : le code, saisi ou reçu par lien. La vérification en direct du code est limitée en débit et ne renvoie que le nom de la classe et celui de l'école. |
| Qui crée les classes, si l'enseignant ne fait que les déclarer ? | L'équipe, pour le compte de l'établissement. L'enseignant coche parmi les classes de son école principale. | Un écran équipe de création de classe entre en V1. Sans lui, aucun code d'adhésion n'existe. |
| Un enseignant peut-il enseigner dans plusieurs établissements ? | Le modèle le permet, un seul est visible en V1 : l'école principale (ADR-0030). | La table de rattachement enseignant–établissement porte un drapeau « principale », unique par enseignant. La déclaration des classes ne remplace que celles de l'école principale. |
| Que devient un exercice « supprimé » que des élèves ont déjà fait ? | Il est archivé, jamais supprimé (ADR-0036). Ses sessions, tentatives et badges sont conservés. | Aucun bouton « Supprimer » : partout « Archiver ». Aucune suppression en cascade vers l'historique. |
| Peut-on modifier les questions d'un exercice déjà fait par des élèves ? | Non. Une tentative est immuable (ADR-0054). Changer une question fausserait les scores passés. | Tant qu'aucune session n'existe, les questions se modifient librement. Dès la première session, seuls le titre, la description et le statut restent modifiables. |
| Quand l'élève voit-il la bonne réponse ? | Seulement après avoir répondu à la question. Hors correction, seuls l'équipe et l'enseignant d'une classe où l'exercice est assigné la voient. | Aucun fragment de cache ne contient les bonnes réponses sans que le rôle entre dans la clé. Un test vérifie le HTML servi à l'élève, cache actif. |
| Que se passe-t-il si un élève oublie son PIN ? | Son enseignant, ou l'équipe, génère un code à usage unique valable 15 minutes (ADR-0032). L'élève le saisit avec son numéro, puis choisit un nouveau PIN. | La récupération fait partie du socle d'authentification. Chaque génération et chaque utilisation sont journalisées. Toutes les sessions ouvertes sont fermées. |
| Un compte équipe peut-il se connecter avec son seul PIN ? | Non. Le TOTP est obligatoire, avec des codes de secours (ADR-0031). | Tant que le second facteur n'est ni enrôlé ni vérifié, un compte équipe n'accède à aucune page de son espace. |
| Comment l'enseignant sait-il qu'il a fini de s'installer ? | Par un état enregistré, pas par une déduction « il n'a encore aucune classe ». | Un enseignant qui n'a pas terminé sa configuration arrive sur la déclaration de ses classes. Aucun écran ne renvoie vers la page qui l'a redirigé : chaque état incomplet a un écran de sortie. |

## Cas limites identifiés

- Un code de classe saisi en majuscules, avec des espaces, ou contenant un `i` ou un `o`.
- Un numéro saisi avec l'indicatif `225` ou `00225`, avec des espaces ou des points.
- Un PIN égal aux 4 derniers chiffres du numéro : il est refusé.
- Deux élèves qui s'inscrivent au même moment avec le même numéro : l'un réussit, l'autre reçoit une erreur de formulaire, jamais une page 500.
- Un enseignant qui soumet une déclaration vide, ou une déclaration qui contient une classe d'une autre école.
- Assigner une ressource déjà assignée, retirer une ressource non assignée, réassigner une ressource retirée.
- Un double clic sur « Valider » pour la même question, ou deux onglets ouverts sur la même session.
- Une réponse vide soumise en Turbo.
- Un exercice archivé pendant qu'un élève est en pleine session.
- Un cours en brouillon ouvert par son URL directe par un élève ou un enseignant.
- Un élève sans classe principale, ou un enseignant sans école : chacun a un écran de sortie, jamais une boucle de redirection.
- Une invitation équipe expirée, déjà acceptée, ou adressée à un numéro qui a déjà un compte.

## Questions encore ouvertes

- La liste des 41 DRENA et celle des établissements, reprises des fichiers métier de l'ancien dépôt, doivent être validées par le porteur avant le seed de production.
- La classe de 2nde A : les séries seedées sont A1, A2, C et D. Faut-il une série « A » pour la 2nde ?
- La liste des matières seedées et leur catégorie (littéraire, scientifique, autre) doivent être validées.
- Les durées de session (absolue et d'inactivité, par rôle) sont proposées par le plan. L'ADR-0050 les fixe.
