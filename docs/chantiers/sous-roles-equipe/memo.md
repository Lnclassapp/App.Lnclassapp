# Memo — Sous-rôles de l'équipe appliqués (admin, contenu, terrain)

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage — en attente des réponses du porteur |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `feature/sous-roles-equipe` (cadrage sur `docs/cadrage-sous-roles-equipe`) |
| **Programme** | `refonte-application`, vague **V4** (fiche « Reste : `sous-roles-equipe` », question Q9 de la feuille de route) |

---

## Le problème

Un compte de l'équipe porte un sous-rôle depuis la V1 (`users.team_role` : `admin`, `content` ou `field`, ADR-0038), et l'écran « Inviter un membre » le fait choisir avec une promesse : « Contenu : cours, fiches essentielles, exercices et référentiel », « Terrain : DRENA, établissements, classes et codes de récupération ». Cette promesse n'est pas tenue. Sur 27 policies qui laissent passer l'équipe, **6 seulement** lisent le sous-rôle (inviter un membre, anonymiser, gérer le blog, inviter, retirer et restaurer une direction). Les 21 autres testent `actor.team?`, comme la règle de modération des annonces (`Message#moderatable_by?`) : un membre « Contenu » peut aujourd'hui supprimer un établissement, régénérer son code, valider un enseignant en attente, lire le numéro de n'importe quel élève, émettre un code de récupération de PIN, réinitialiser le second facteur d'un autre membre ou relancer un job dans Mission Control.

La navigation dit la même chose : le shell de l'équipe affiche les mêmes entrées à tous ses membres, et l'accueil ne masque que trois raccourcis (Inviter, Blog, demandes de suppression).

Enfin, rien ne permet de **changer** le sous-rôle d'un membre : l'action `team_role.changed` est déclarée dans le journal (ADR-0038) mais aucun use case ne l'émet. Un membre invité avec le mauvais sous-rôle garde celui-là pour toujours, sauf passage par la console.

## Pour qui

- **Équipe, sous-rôle `admin`** (le porteur et les responsables) : donner à chacun ce qu'il lui faut, et corriger un sous-rôle sans la console.
- **Équipe, sous-rôle `content`** (rédaction du catalogue et du blog) : ne voir que ses outils ; ne plus avoir sous la main des gestes destructeurs sur les établissements ni les numéros des élèves.
- **Équipe, sous-rôle `field`** (terrain : DRENA, établissements, directions, déblocage des comptes) : idem, sans les gestes du catalogue.
- **Élèves, enseignants, directions** (indirectement) : leurs données nominatives ne sont plus lisibles que par les membres qui en ont besoin (moindre privilège, ADR-0038 §2).

## Pourquoi maintenant

- La porte de la V4 l'exige : « chaque sous-rôle n'accède qu'à sa colonne de la matrice de l'ADR-0038 (un test de refus par case vide) ». Le porteur a demandé de lancer les vagues V2 à V6.
- Depuis l'ADR-0038 (2026-09-25), une douzaine de pages de l'équipe sont livrées sans place dans la matrice : Pilotage (ADR-0062), Croissance et validation des enseignants en attente (ADR-0063), code d'établissement (ADR-0057), barème (ADR-0058), génération et ajustement des classes (ADR-0056, ADR-0059), archivage (ADR-0088), illustrations d'annonce (ADR-0081), demandes de suppression (ADR-0036), retrait de la direction (ADR-0077). Chaque nouvelle page agrandit la dette : c'est la question Q9 de la feuille de route.
- L'écran d'invitation ment déjà : un membre invité « Contenu » croit avoir un accès restreint et en a un presque complet.

## Hors périmètre

- **Un quatrième sous-rôle** (« gestionnaire DRENA », lecture seule, support) : l'ADR-0038 l'écarte ; un ajout passe par un nouvel ADR.
- **Des permissions fines par personne** (table de permissions, cases à cocher) : option C de l'ADR-0038, écartée.
- **L'annuaire de l'équipe** (`annuaire-equipe`, V2, au backlog) : liste des membres, fiche, départ d'un membre, révocation d'une invitation en attente. Ici, on change un sous-rôle depuis la fiche d'un compte qui existe déjà (« Débloquer un compte »).
- **Retirer ou désactiver un membre de l'équipe** : `DeleteUserPolicy` refuse toute cible autre qu'un élève ; inchangé.
- **Modifier ou révoquer une invitation en attente** ; changer le sous-rôle porté par une invitation non acceptée.
- **Le second facteur** : TOTP exigé pour tout sous-rôle (ADR-0031, ADR-0038), inchangé.
- **Les rôles hors équipe** (`teacher`, `school_admin`, `student`) et leurs policies : aucune ligne qui ne concerne qu'eux ne bouge.
- **Une migration de schéma** : `users.team_role` et ses contraintes existent depuis la V1 ; aucune colonne n'est ajoutée.
- **Restreindre la lecture du catalogue** (brouillons compris) : tout membre de l'équipe continue de lire tout le catalogue.

## Ce que le grill a révélé

> Grill mené sur le code (`app/domain/policies/`, `app/controllers/teams/`, `config/routes/teams.rb`, `NavigationHelper`) et sur les ADR-0031, 0038, 0044, 0062, 0063 et 0074. Les réponses du porteur sont **en attente** : la colonne « Réponse » porte la **recommandation**, à confirmer ou corriger.

| # | Question posée au porteur | Recommandation (en attente de réponse) | Conséquence sur le chantier |
|---|---|---|---|
| 1 | Garde-t-on **trois sous-rôles** (`admin`, `content`, `field`), sans « gestionnaire DRENA » ni « lecture seule » ? | **Oui**, comme l'ADR-0038. Une équipe de quelques personnes n'a pas besoin de plus | Aucun changement de schéma ; la matrice a trois colonnes |
| 2 | **Pages livrées après l'ADR-0038** (Q9) : qui voit quoi ? | **Pilotage (indicateurs agrégés) et Croissance : les trois.** Validation des enseignants en attente, code d'établissement, barème, génération, ajout, retrait et archivage des classes : **admin et terrain.** Illustrations d'annonce : **admin et contenu.** Demandes de suppression : **admin** (déjà le cas) | Huit policies changent de règle ; la matrice de l'ADR-0100 gagne ces lignes ; les tuiles du Référentiel et les entrées du shell suivent |
| 3 | **Données nominatives** : la recherche du Pilotage (numéro, nom), « Débloquer un compte », le code de récupération du PIN, les pages de classe et les résultats d'un élève vus par l'équipe — à qui ? | **Admin et terrain.** Le contenu n'a besoin d'aucune donnée personnelle ; il garde les indicateurs agrégés | `ReadUserPolicy`, `IssuePinRecoveryCodePolicy`, les policies de classe et `ReadSessionPolicy` lisent le sous-rôle ; le bloc de recherche du Pilotage est masqué au contenu |
| 4 | **Mission Control** (`/teams/jobs`) et **réinitialiser le second facteur** d'un autre membre : admin seul ? | **Oui, admin seul** (ADR-0038 §4 et ADR-0031 §4 le prévoient « à partir de la V4 ») | Aujourd'hui, tout membre réinitialise le TOTP d'un autre : c'est le refus le plus important du chantier. Mission Control reçoit un contrôleur de base propre |
| 5 | **Changer le sous-rôle** d'un membre : où ? | **Depuis la fiche du compte** (« Débloquer un compte » → numéro du membre → « Changer le rôle »), en modale, admin seul. Pas de page « Membres de l'équipe » tant qu'`annuaire-equipe` est au backlog | Un use case `Identity::ChangeTeamRole`, une modale (UDR-0118), l'événement `team_role.changed` enfin émis |
| 6 | Un admin peut-il **changer son propre** sous-rôle ? | **Non** : un autre admin le fait, comme la réinitialisation du TOTP (personne ne s'ôte un accès par erreur). Rétrograder le **dernier** admin donne `:conflict` (invariant de l'ADR-0038) | Deux refus testés : soi-même (`:forbidden`), dernier admin (`:conflict`) |
| 7 | **Membres existants** : garde-t-on le sous-rôle choisi à leur invitation ? | **Oui, sans migration de données**, après une revue de la liste par le porteur **avant** le déploiement (rôle, sous-rôle, date d'inscription, sortie en lecture seule par la console). Un membre mal classé est corrigé le jour du déploiement par l'écran du lot C. Alternative écartée : tout passer en `admin` puis rétrograder, qui vide la matrice de son sens le temps de la correction | Une étape de déploiement dans le plan (lot E) ; un membre invité « Contenu » ou « Terrain » **perd** des accès au déploiement : le porteur prévient les personnes concernées |
| 8 | Lance-t-on ce chantier **sans attendre `annuaire-equipe`** (V2, au backlog), alors que la feuille de route le place après ? | **Oui.** L'annuaire n'est pas ouvert ; s'il l'est plus tard, ses policies s'écrivent directement avec la matrice de l'ADR-0100, sans réécriture. Si un autre chantier de la V2 cadre `annuaire-equipe` en même temps, il consomme l'ADR-0100 au lieu de tester `team?` | La dépendance de la feuille de route tombe ; collision de contrat signalée au journal |
| 9 | Un membre qui ouvre une page hors de son sous-rôle (lien reçu, favori) voit quoi ? | **Les entrées interdites sont masquées** (shell, menu « Plus », raccourcis, tuiles, boutons) ; une adresse tapée donne la page « Accès interdit » existante, avec une phrase propre à l'équipe : « Votre rôle dans l'équipe ne donne pas accès à cette page. Un administrateur peut le changer. » | UDR-0116 ; la page 403 reçoit une variante de texte pour un acteur `team`, sans nouvelle page |
| 10 | Annonces : publier (nationale ou d'un établissement) et **modérer** les annonces des enseignants et directions — qui ? | **Publier : les trois** (ADR-0038 §4). **Modérer : admin et terrain**, parce que la modération lit des annonces d'établissements nommés | `PublishPolicy` inchangée pour l'équipe ; `ModerationsController` et `WithdrawPolicy` lisent le sous-rôle |

## Cas limites identifiés

- **Changement de sous-rôle en cours de session** : l'acteur est relu en base à chaque requête (`UserRepository#actor_for`) ; le nouveau sous-rôle vaut dès la requête suivante, sans déconnexion. Une modale déjà ouverte qui soumet un geste désormais interdit reçoit un toast « Accès interdit » (flux Turbo, `RendersResult`).
- **Dernier admin** : rétrograder le seul admin, même par un autre admin qui n'existe pas, est impossible (`:conflict`) ; deux admins qui se rétrogradent l'un l'autre en même temps : le second reçoit `:conflict` (comptage sous verrou, ADR-0100 §6).
- **Sous-rôle inchangé** : soumettre le même sous-rôle n'écrit rien et ne journalise rien (succès sans effet).
- **Cible qui n'est pas de l'équipe** : changer le « sous-rôle » d'un enseignant ou d'un élève donne `:not_found` (le bouton n'est jamais rendu, l'adresse forgée est refusée).
- **Compte anonymisé** : refusé comme cible (`:not_found`), et ne compte pas parmi les admins.
- **Imports** : la liste des imports ne montre à chacun que les types qu'il peut lancer ; ouvrir le rapport d'un import d'un autre type donne 403 (`ImportKind.authorize_report`, déjà en place, devient efficace).
- **Mission Control** : un membre non admin qui ouvre `/teams/jobs` reçoit 403, pas une redirection vers la vérification du second facteur (il est déjà vérifié).
- **Accueil** : un membre « Contenu » ne voit ni la carte « Régions » ni les directions retirées ; un membre « Terrain » ne voit pas « Nouveau cours » ni le contenu récent ; l'accueil n'est jamais vide (raccourcis « Imports », « Croissance » communs).
- **Lien profond** : le shell n'affiche pas « Établissements » à un membre « Contenu », mais `/teams/schools` tapé à la main doit rendre 403, pas une page vide.
- **Barre basse du téléphone** : avec une entrée masquée, la grille passe de 5 à 4 cases (`NAV_GRIDS`) ; vérifié en capture à 390 px.

## Questions encore ouvertes

- Les dix questions du grill, ci-dessus, attendent la réponse du porteur. Le PRD, l'ADR-0100 et les UDR-0116 à 0118 sont écrits sur les recommandations ; une réponse différente se reporte dans ces fichiers **avant** le Lot 0.
- Liste des membres de l'équipe en production et de leur sous-rôle (question 7) : à sortir avant le déploiement.

## Réponses du porteur (2026-10-16)

- **Chantier reporté** par le porteur (« laisse-le d'abord »). Rien ne démarre. La faille relevée (un membre « Contenu » a presque les droits d'un admin) reste ouverte.
