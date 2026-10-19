# PRD — Annuaire de l'équipe (« Comptes »)

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> **Écrit avec les recommandations du memo (Q1 à Q8).** Une réponse différente du porteur se reporte ici avant le Lot 0 ; les critères concernés portent le numéro de la question.

## 1. Contexte

L'équipe trouve un compte par deux recherches sans lien (« Débloquer un compte », Pilotage) et ne peut ni le corriger, ni l'empêcher de se connecter, ni anonymiser un adulte. La page « Comptes » remplace « Débloquer un compte » : une recherche, une fiche par compte, et les gestes modifier, désactiver, réactiver, anonymiser. Le déblocage (code PIN, second facteur) et les demandes de suppression existent déjà et passent sur la fiche sans changer.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe `admin` | tout : chercher, lire, modifier, désactiver, réactiver tout compte ; anonymiser un élève, un enseignant, un membre de l'équipe | agir sur son propre compte ; désactiver ou anonymiser le dernier `admin` actif ; changer un rôle |
| Équipe `field` | chercher, lire ; modifier, désactiver, réactiver un élève, un enseignant ; retirer et restaurer une direction (ADR-0077, déjà) (Q5) | toucher un compte de l'équipe ; anonymiser |
| Équipe `content` | chercher, lire (Q5) | tout geste |
| Enseignant, direction, élève | — | ouvrir `/teams/accounts` ni une fiche (espace équipe, second facteur exigé) |
| Le système (tâche planifiée) | anonymiser un adulte désactivé depuis plus de 30 jours (Q1) | toucher un élève, un compte réactivé |

Règles : `Policies::Identity::ReadUserPolicy` (lecture, inchangée), `Policies::Identity::ManageAccountPolicy` (nouvelle : modifier, désactiver, réactiver), `Policies::Identity::DeleteUserPolicy` (amendée : enseignant et équipe en plus de l'élève), `Policies::School::RemoveSchoolStaffPolicy` (direction, inchangée), `Policies::Identity::AnonymizeDeactivatedUsersPolicy` (système). Garde « dernier admin » dans les use cases, sous verrou (ADR-0093).

## 3. Parcours utilisateur

### Chemin nominal

1. Sur l'accueil de l'équipe, le bouton « Comptes » (ex-« Débloquer un compte ») ouvre `/teams/accounts`.
2. Elle tape un nom (2 caractères au moins) ou un numéro (4 chiffres au moins), filtre au besoin par rôle et par état ; la liste se met à jour dans son frame, 20 par page.
3. Elle ouvre une ligne : la fiche `/teams/accounts/<public_id>` montre l'identité, le rôle, l'état, le numéro complet, le rattachement et les dates.
4. Depuis le menu « Actions » de la fiche : émettre un code PIN, réinitialiser le second facteur (équipe), modifier, désactiver ou réactiver, anonymiser ; la demande de suppression d'un élève reste dans son bloc.
5. Chaque geste s'ouvre dans la modale, se confirme, puis met la fiche à jour et affiche un toast.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Terme trop court | « Tapez au moins 2 caractères, ou 4 chiffres pour un numéro. » |
| Aucun résultat | état vide « Aucun compte trouvé » et une piste (nom plus court, numéro complet) |
| Fiche de son propre compte | aucune action ; bandeau « C'est votre compte : vos réglages sont dans Mon profil. » |
| `public_id` inconnu ou compte anonymisé | 404 |
| Numéro déjà utilisé à la modification | 422 dans la modale : « Ce numéro est déjà utilisé. » |
| Numéro hors format | 422 : message du format (comme l'inscription) |
| Dernier `admin` actif | 409 dans la modale : « C'est le dernier administrateur : invitez-en un autre avant. » |
| Sous-rôle sans le droit | le geste n'apparaît pas ; une requête forgée reçoit 403 |
| Nom tapé différent à l'anonymisation | 422 : « Le nom ne correspond pas. » |
| Compte désactivé qui se connecte | message d'un PIN faux, tentative comptée comme un échec |

## 4. Critères d'acceptation

```gherkin
# Lot A — trouver un compte
Étant donné un membre de l'équipe connecté avec son second facteur
Quand il ouvre l'accueil de l'équipe
Alors il voit le bouton « Comptes » et plus « Débloquer un compte »
Et ce bouton mène à /teams/accounts

Étant donné les comptes « Aïcha Koné » (élève), « Koné Ibrahim » (enseignant), « Marc Koné » (direction) et « Awa Koné » (équipe)
Quand l'équipe cherche « kone »
Alors les quatre comptes sont listés, avec leur rôle, leur rattachement et leur numéro masqué
Et un compte anonymisé n'est jamais listé

Étant donné la recherche « kone »
Quand l'équipe filtre le rôle « Enseignant »
Alors seul « Koné Ibrahim » reste
Et l'URL garde le terme et le filtre

Étant donné un enseignant désactivé
Quand l'équipe filtre l'état « Désactivé »
Alors il est listé avec le badge « Désactivé »
Et les comptes actifs ne le sont pas

Étant donné un numéro de 3 chiffres
Quand l'équipe le cherche
Alors aucune requête de comptes n'est faite et la consigne de longueur s'affiche   # Q3

Étant donné la page Pilotage
Quand l'équipe l'ouvre
Alors la carte de recherche est remplacée par le lien « Chercher un compte » vers /teams/accounts   # Q4

# Lot A — lire une fiche
Étant donné un élève de la 3ème A du Lycée moderne de Bouaké
Quand l'équipe ouvre sa fiche
Alors elle voit son nom, son genre, son rôle, son numéro complet, sa classe, son établissement, son état et sa date d'inscription
Et jamais son PIN ni le secret d'un second facteur
Et l'URL porte son identifiant public, pas son identifiant numérique

Étant donné un enseignant, un élève ou une direction connecté
Quand il demande /teams/accounts ou une fiche
Alors il est refusé comme pour toute page de l'équipe

Étant donné la fiche d'un élève
Quand l'équipe choisit « Émettre un code de récupération »
Alors le code s'affiche dans la modale, comme sur l'ancienne page « Débloquer un compte »

# Lot B — modifier
Étant donné un élève nommé « Aicha Kone », genre féminin, numéro 0701020304
Quand l'équipe `admin` corrige le nom en « Aïcha Koné »
Alors la fiche affiche « Aïcha Koné »
Et le journal porte « user.updated_by_team », l'acteur et les champs « first_name, last_name », sans leurs valeurs
Et ses sessions restent ouvertes

Étant donné un enseignant connecté sur deux appareils
Quand l'équipe `field` change son numéro en 0505060708
Alors ses deux sessions sont fermées
Et il se connecte avec 0505060708 et son PIN

Étant donné le numéro 0505060708 déjà porté par un autre compte
Quand l'équipe le saisit sur une fiche
Alors la modale répond « Ce numéro est déjà utilisé » et rien n'est enregistré

Étant donné l'équipe `content`
Quand elle ouvre une fiche
Alors elle ne voit pas « Modifier » et une requête directe reçoit 403   # Q5

Étant donné l'équipe `field`
Quand elle ouvre la fiche d'un membre de l'équipe
Alors elle ne voit pas « Modifier »   # Q5

# Lot C — désactiver, réactiver
Étant donné un enseignant connecté
Quand l'équipe `admin` le désactive
Alors ses sessions sont fermées
Et la fiche affiche « Désactivé le 16/10/2026 » et « Anonymisé le 15/11/2026 si non réactivé »   # Q1
Et le journal porte « user.deactivated »

Étant donné un élève désactivé
Quand il saisit son numéro et son bon PIN
Alors il reçoit le message d'un PIN faux
Et aucune session n'est ouverte

Étant donné un élève désactivé
Quand l'équipe ouvre sa fiche
Alors aucune date d'anonymisation n'est annoncée   # Q1

Étant donné un enseignant désactivé
Quand l'équipe le réactive
Alors il se connecte de nouveau avec son PIN
Et l'échéance d'anonymisation disparaît de la fiche
Et le journal porte « user.reactivated »

Étant donné deux membres `admin`, A et B, seuls actifs
Quand A désactive B, puis tente de se désactiver
Alors la seconde action est refusée (« soi-même »)
Et quand un troisième geste vise le dernier admin actif, il reçoit « dernier administrateur »

Étant donné deux requêtes simultanées qui désactivent chacune l'un des deux derniers `admin`
Quand elles s'exécutent
Alors une seule réussit

Étant donné une direction rattachée au Lycée moderne de Bouaké
Quand l'équipe la désactive depuis sa fiche
Alors elle est retirée comme par la fiche de l'établissement (ADR-0077) : archivée, restaurable 30 jours   # Q2

# Lot D — anonymiser
Étant donné un enseignant de la 3ème A et de la 4ème B, auteur d'un devoir actif
Quand l'équipe `admin` l'anonymise en tapant son nom
Alors son nom devient « Compte supprimé », son numéro, sa photo, ses sessions et son second facteur sont effacés
Et il n'enseigne plus la 3ème A ni la 4ème B, et son devoir actif est archivé   # Q7
Et ses annonces restent, signées « Compte supprimé »
Et le journal porte « user.anonymized » avec la raison « team »

Étant donné un membre de l'équipe `content`
Quand l'équipe `admin` l'anonymise
Alors il ne peut plus se connecter et n'apparaît plus dans la recherche

Étant donné le dernier `admin` actif
Quand un autre geste tente de l'anonymiser
Alors il reçoit « dernier administrateur »

Étant donné la modale d'anonymisation
Quand l'équipe tape un nom différent de celui du compte
Alors rien n'est effacé et la modale le dit

Étant donné l'équipe `field`
Quand elle ouvre une fiche
Alors elle ne voit pas « Anonymiser »

# Lot E — anonymisation automatique (Q1)
Étant donné un enseignant désactivé il y a 31 jours et un autre il y a 29 jours
Quand la tâche du jour passe
Alors le premier est anonymisé et pas le second
Et un second passage ne change rien

Étant donné un élève désactivé il y a 60 jours
Quand la tâche du jour passe
Alors il n'est pas anonymisé

Étant donné un enseignant désactivé il y a 31 jours puis réactivé hier
Quand la tâche du jour passe
Alors il n'est pas anonymisé

Étant donné deux comptes échus dont le premier échoue
Quand la tâche passe
Alors le second est anonymisé et le premier repasse le lendemain
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Identity::User` : `deactivated_at`, `#deactivated?`, `#anonymization_due_on` ; ports : `UserRepositoryPort` (`update_identity`, `deactivate`, `reactivate`, `lock_active_admins`, `deactivated_before`) ; use cases `UpdateAccount`, `DeactivateAccount`, `ReactivateAccount`, `AnonymizeDeactivatedUsers` ; `AnonymizeUser` étendu ; policies `ManageAccountPolicy`, `AnonymizeDeactivatedUsersPolicy`, `DeleteUserPolicy` amendée ; DTO `AccountInput` |
| Infrastructure | migration `users.deactivated_at`, `users.deactivated_by_id` ; `UserRepository` ; `AccountSearchQuery` étendue ; `AccountDetailQuery` (remplace `AccountLookupQuery`) ; job `Identity::AnonymizeDeactivatedUsersJob` |
| Delivery | `Teams::AccountsController` (index, show), `Teams::AccountEditsController`, `Teams::AccountDeactivationsController`, `Teams::AccountReactivationsController`, `Teams::AccountDeletionsController` (étendu) ; routes sous `/teams/accounts` |
| UI | `teams/accounts/*` (UDR-0095, UDR-0096), modales (UDR-0097), bouton de l'accueil, carte de Pilotage (Q4) |

## 6. Décisions rattachées

- ADR-0093 — désactivation d'un compte, anonymisation des adultes, garde du dernier admin, tâche à 30 jours (Proposé)
- UDR-0095 — page « Comptes » : recherche, filtres, liste (Proposé)
- UDR-0096 — fiche d'un compte et son menu d'actions (Proposé)
- UDR-0097 — modales modifier, désactiver, réactiver, anonymiser (Proposé)
- Amendées à l'acceptation : UDR-0020 (remplacée par UDR-0095 et UDR-0096), UDR-0049 (recherche, Q4), ADR-0036 (anonymisation des adultes), ADR-0038 (invariant codé)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Requêtes SQL pour une page de recherche | 4 au plus (`AccountSearchQuery`) | 5 au plus, indépendant du nombre de résultats | |
| Requêtes SQL pour une fiche | — | nombre fixe, quel que soit le nombre de classes | |
| Corrections de compte faites en console | toutes | 0 | |
