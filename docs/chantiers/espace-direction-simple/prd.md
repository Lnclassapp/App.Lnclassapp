# PRD — Espace direction, version simple

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La direction d'un établissement n'a aujourd'hui aucun accès à Lnclass. Le porteur veut une version simple (2026-09-28) : l'équipe l'invite, elle se connecte par téléphone et PIN, et **lit** deux pages sur son seul établissement, « Enseignants » et « Travail des élèves ». Tout le reste de la V2 est au backlog ([memo](memo.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team (`admin`, `field`) | Inviter la direction d'un établissement actif | Inviter sur un numéro qui a déjà un compte |
| Direction (`school_admin`) | Lire les enseignants et le travail des élèves de **son** établissement ; son profil | Voir un autre établissement ; écrire quoi que ce soit hors son profil ; valider un enseignant ; lire ou régénérer le code d'établissement ; ajouter une classe |
| Teacher, Student | Rien de nouveau | Ouvrir une page de la direction |

Règles : `Policies::Identity::InviteSchoolStaffPolicy` pour l'invitation ; `Policies::School::ReadOwnSchoolPolicy` pour les lectures, l'établissement étant toujours celui du compte (ADR-0065).

## 3. Parcours utilisateur

### Chemin nominal

1. Sur la fiche d'un établissement, l'équipe choisit « Inviter la direction », saisit un numéro et copie le lien affiché.
2. Elle transmet le lien hors de Lnclass. La personne l'ouvre, saisit nom, prénoms, genre et PIN.
3. Elle se connecte avec son numéro et son PIN, sans second facteur, et arrive sur « Travail des élèves ».
4. Elle ouvre une classe et voit chaque élève, ses devoirs rendus et son score moyen.
5. Elle ouvre « Enseignants » et voit qui enseigne quelle matière dans quelles classes.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Numéro déjà lié à un compte, ou invitation en cours | Refus nommé dans la modale (UDR-0019) |
| Établissement non actif | Pas d'entrée « Inviter la direction » ; en requête directe, refus « Cet établissement n'est pas actif. » |
| Lien périmé, déjà servi ou révoqué | Message seul, sans formulaire (UDR-0019) |
| Classe d'un autre établissement ou inconnue | 404 |
| Enseignant, élève ou équipe sur une page de la direction | 403 |
| Visiteur non connecté | Renvoyé vers « Se connecter » |

## 4. Critères d'acceptation

```gherkin
# DS-01 — Lot A
Étant donné un membre de l'équipe sur la fiche du lycée actif « Lycée Moderne de Bouaké »
Quand il invite la direction au numéro 0700000009
Alors une invitation de type direction, pour cet établissement et sans fonction, est créée
Et le lien d'invitation s'affiche une seule fois dans la modale

# DS-02 — Lot A
Étant donné un membre de l'équipe
Quand il invite la direction d'un établissement inactif, ou sur un numéro qui a déjà un compte
Alors aucune invitation n'est créée
Et la modale affiche « Cet établissement n'est pas actif. » ou « Ce numéro a déjà un compte Lnclass. »

# DS-03 — Lot A
Étant donné une invitation de direction pour le « Lycée Moderne de Bouaké »
Quand la personne invitée crée son compte depuis le lien, puis se connecte avec son numéro et son PIN
Alors son compte a le rôle direction et est rattaché à ce seul établissement
Et aucun second facteur ne lui est demandé
Et son profil affiche « Lycée Moderne de Bouaké »

# DS-04 — Lot A
Étant donné un enseignant, puis une direction, connectés
Quand chacun demande le formulaire ou l'envoi d'une invitation de direction
Alors la réponse est 403 et aucune invitation n'est créée

# DS-05 — Lot C
Étant donné une direction qui se connecte avec son numéro et son PIN
Alors elle arrive sur « Travail des élèves »
Et sa navigation montre exactement « Travail des élèves » et « Enseignants », toutes deux actives

# DS-06 — Lot B
Étant donné le « Lycée Moderne de Bouaké » avec l'enseignante Awa Koné (Mathématiques, classes « 2nde C 1 » et « Tle D 2 »),
  un enseignant sans classe, un enseignant anonymisé et un enseignant en attente de validation
Et un enseignant d'un autre établissement
Quand sa direction ouvre « Enseignants »
Alors elle voit Awa Koné, « Mathématiques », « 2nde C 1, Tle D 2 », et l'enseignant sans classe avec « Aucune classe »
Et elle ne voit ni l'anonymisé, ni l'enseignant en attente, ni celui de l'autre établissement
Et aucun numéro de téléphone n'apparaît dans la page

# DS-07 — Lot C
Étant donné la classe active « 2nde C 1 » de l'année, avec 4 élèves et 2 devoirs donnés
Et l'élève A a rendu les 2 devoirs (80 % et 60 %), l'élève B un devoir (70 %), les élèves C et D aucun
Et une session de remédiation de B à 100 %
Quand la direction ouvre « Travail des élèves »
Alors la ligne « 2nde C 1 » montre 4 élèves, 2 devoirs donnés, un taux de rendu de 38 % et la moyenne « — »
Et une classe archivée ou d'une autre année n'apparaît pas

# DS-08 — Lot C
Étant donné une classe où 5 élèves ont rendu un devoir, à 50, 60, 70, 80 et 90 %
Quand la direction ouvre « Travail des élèves »
Alors la moyenne de la classe est 70 %
Et avec 4 élèves ayant rendu, elle serait « — »

# DS-09 — Lot C
Étant donné la classe « 2nde C 1 » de DS-07, plus un élève parti et un élève anonymisé
Quand la direction ouvre la classe
Alors elle voit A « 2 / 2 » et « 70 % », B « 1 / 2 » et « 70 % », C et D « 0 / 2 » et « — »
Et ni l'élève parti ni l'élève anonymisé

# DS-10 — Lots B et C
Étant donné la direction du « Lycée Moderne de Bouaké » et une classe d'un autre établissement
Quand elle demande la page de cette classe
Alors la réponse est 404
Et ses pages « Travail des élèves » et « Enseignants » ne contiennent aucune classe, aucun élève ni aucun enseignant de l'autre établissement

# DS-11 — Lots 0 (routes), B et C (refus)
Étant donné un élève, un enseignant et un membre de l'équipe connectés, puis un visiteur
Quand chacun demande une page sous /school-admin
Alors les trois premiers reçoivent 403 et le visiteur est renvoyé vers « Se connecter »
Et aucune route sous /school-admin n'accepte autre chose que GET
```

Chaque critère a son test ; les définitions de l'ADR-0065 §4 ont en plus chacune un test de query.

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Identity::Invitation` (fonction facultative), `HomeDestination` (direction), `Ports::School::StaffRepositoryPort`, `UseCases::Identity::InviteSchoolStaff`, `AcceptInvitation` étendu, `Policies::Identity::InviteSchoolStaffPolicy`, `Policies::School::ReadOwnSchoolPolicy` |
| Infrastructure | table `school_staffs`, contrainte `invitations_staff_has_school` assouplie, `Orm::SchoolStaff`, `Repositories::School::StaffRepository`, `Queries::School::SchoolTeachersQuery`, `Queries::School::StudentWorkQuery` |
| Delivery | `SchoolAdmin::BaseController`, `SchoolAdmin::ClassroomsController`, `SchoolAdmin::TeachersController`, `Teams::StaffInvitationsController` |
| UI | pages de l'UDR-0052, modale d'invitation, variante de la page d'acceptation, ligne du profil |

## 6. Décisions rattachées

- [ADR-0065](../../decisions/adr/0065-espace-direction-simple-en-lecture-seule.md) — direction invitée, PIN seul, lecture de son établissement ; amende l'ADR-0044.
- [UDR-0052](../../decisions/udr/0052-espace-direction-simple.md) — les deux pages, la modale et les variantes ; amende les UDR-0006, 0019, 0036 et 0041.
