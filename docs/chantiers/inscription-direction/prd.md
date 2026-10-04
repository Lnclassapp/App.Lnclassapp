# PRD — Inscription de la direction sans invitation

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

| | |
|---|---|
| **Chantier** | `inscription-direction` — cycle feature |
| **Memo** | [`memo.md`](memo.md) (grill du porteur, 2026-10-04, Q1 à Q12) |
| **Décisions** | §6 |

## 1. Contexte

La direction d'un établissement n'entre aujourd'hui que par une invitation de l'équipe. Ce chantier lui ouvre une **page d'inscription** avec le code d'établissement, accessible depuis la page d'accueil, avec un **accès immédiat** dans un **plafond de 3 comptes par le code**. En contrepartie, un compte direction peut être **retiré** par l'équipe ou par une autre direction de plus de 7 jours : il est alors archivé, restaurable par l'équipe pendant 30 jours, puis supprimé.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| **Visiteur** (non connecté) | S'inscrire comme direction d'un établissement **actif** avec son code, si moins de 3 directions actives y sont arrivées par le code | S'inscrire sur un établissement en brouillon ou désactivé ; avec un numéro déjà lié à un compte |
| **Direction** (`school_admin` rattaché, non archivé), arrivée depuis **7 jours ou plus**, établissement actif | Voir le bloc « Direction » et le bandeau d'arrivée ; retirer une **autre** direction de son établissement | Se retirer elle-même ; retirer une direction d'un autre établissement ; restaurer |
| **Direction arrivée depuis moins de 7 jours** | Voir le bloc « Direction » et le bandeau | Retirer qui que ce soit |
| **Direction d'un établissement inactif** | Voir le bloc « Direction » | Retirer |
| **Direction archivée** | — | Se connecter ; toute requête (sessions fermées) |
| **Équipe** `admin`, `field` | Retirer toute direction ; voir les directions retirées (fiche, accueil) ; restaurer avant J+30 | Restaurer une arrivée par le code quand les 3 places sont prises |
| **Équipe** `content` | Voir le bloc « Direction » de la fiche | Retirer, voir les directions retirées, restaurer |
| **Enseignant**, **Élève**, **Parent** | — (rien ne change) | Accéder à ces pages |

**Règles d'autorisation** : `Policies::Identity::RegisterSchoolStaffPolicy`, `Policies::School::RemoveSchoolStaffPolicy`, `Policies::School::RestoreSchoolStaffPolicy`, `Policies::School::PurgeArchivedStaffPolicy`. Détail dans [ADR-0077](../../decisions/adr/0077-inscription-de-la-direction-par-le-code-et-retrait.md) §4.3.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur la page d'accueil, la direction clique « Créer votre compte » sous les boutons du haut de page, ou « Créer mon compte de direction » dans la section « Établissements ».
2. Elle saisit son nom, ses prénoms, son genre, son numéro, le **code d'établissement** et un PIN, puis « Créer mon compte ».
3. Elle est connectée et arrive sur « Travail des élèves », avec le toast « Bienvenue ! Votre compte de direction est créé. »
4. Les autres directions de l'établissement voient, pendant 7 jours, « Aya Kouassi a rejoint la direction le 4 octobre 2026 (avec le code de l'établissement). »
5. Une direction en place depuis plus de 7 jours ne la reconnaît pas. Dans Établissement → bloc « Direction » → ⋮ → « Retirer de la direction » → « Retirer ». Le compte est archivé et ses sessions sont fermées.
6. L'équipe voit « Directions retirées » sur son accueil et sur la fiche. Elle peut « Restaurer » ; sinon, le compte est supprimé à J+30.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code inconnu, établissement en brouillon ou désactivé | 422, « Code d'établissement invalide. Vérifiez-le auprès de vos enseignants. » ; aucun compte créé |
| Code de classe | 422, message « code de classe » |
| 3 directions actives par le code | 422, « Votre établissement a déjà 3 comptes direction créés avec son code. Contactez l'équipe Lnclass. » ; aucun compte créé |
| Numéro déjà lié à un compte | 422, « Ce numéro a déjà un compte Lnclass. Utilisez un autre numéro. » |
| Plus de 5 envois par minute | 429, « Trop de tentatives » |
| Direction connectée qui ouvre la page d'inscription | Redirection vers son accueil |
| Une direction tente de se retirer (requête forgée) | 403 ; rien n'est écrit |
| Une direction de moins de 7 jours retire (requête forgée) | 403 ; rien n'est écrit |
| Une direction retire une direction d'un autre établissement | 404 ; rien n'est écrit |
| Retirer un compte déjà archivé (deux onglets) | 404, toast « Introuvable. » |
| Compte archivé qui se connecte | Refus « Numéro ou PIN incorrect », comme un mauvais PIN |
| Restaurer quand les 3 places par le code sont prises | 409, toast « Les 3 places… » ; le compte reste archivé |
| Un compte archivé depuis 30 jours | Anonymisé et détaché par la tâche quotidienne ; il quitte « Directions retirées » |

## 4. Critères d'acceptation

« A » est un établissement actif de code `K7M4QZ` ; « B » est un autre établissement actif ; « C » est un établissement en brouillon. « Une direction par le code » est un compte `school_admin` rattaché avec `joined_via = code`. 22 critères.

### Inscription (ID-01 à ID-08)

```gherkin
# ID-01
Étant donné que A n'a aucune direction
Quand un visiteur s'inscrit avec le code K7M-4QZ, un numéro libre et un PIN valide
Alors un compte school_admin rattaché à A est créé avec joined_via « code »
Et une session est ouverte et il arrive sur « Travail des élèves » avec le toast « Bienvenue ! Votre compte de direction est créé. »
Et le journal porte « school_staff.registered »

# ID-02
Étant donné que A a 3 directions actives par le code et 1 direction invitée
Quand un visiteur s'inscrit avec le code de A
Alors la page répond 422 avec « Votre établissement a déjà 3 comptes direction créés avec son code. Contactez l'équipe Lnclass. »
Et aucun compte n'est créé

# ID-03
Étant donné que A a 2 directions actives par le code, 1 archivée par le code et 4 invitées
Quand un visiteur s'inscrit avec le code de A
Alors son compte est créé

# ID-04
Étant donné que A a 2 directions actives par le code
Quand deux visiteurs s'inscrivent en même temps avec le code de A
Alors un seul compte est créé et l'autre reçoit le refus du plafond

# ID-05
Étant donné le code de C, et un code inconnu
Quand un visiteur s'inscrit avec l'un ou l'autre
Alors la page répond 422 avec « Code d'établissement invalide. Vérifiez-le auprès de vos enseignants. » et aucun compte n'est créé

# ID-06
Étant donné un numéro déjà lié à un compte enseignant
Quand un visiteur s'inscrit avec ce numéro et le code de A
Alors la page répond 422 avec « Ce numéro a déjà un compte Lnclass. Utilisez un autre numéro. »

# ID-07
Quand une même IP envoie 6 inscriptions en une minute
Alors la 6ᵉ reçoit 429 « Trop de tentatives »

# ID-08
Étant donné qu'une invitation de direction est acceptée
Alors le rattachement porte joined_via « invitation »
Et les lignes de school_staffs antérieures à la migration valent « invitation »
```

### Page d'accueil (ID-09)

```gherkin
# ID-09
Quand un visiteur ouvre la page d'accueil
Alors il voit le lien « Créer votre compte » sous les deux boutons du haut de page, la section « Établissements » avec « Créer mon compte de direction », et le lien « Établissements » du pied de page vers #etablissements
Et les trois mènent à la page d'inscription de la direction
Et la page ne défile pas horizontalement à 390 px
```

### Voir et retirer (ID-10 à ID-17)

```gherkin
# ID-10
Étant donné que Kofi, direction de A depuis 10 jours, et Aya, direction de A depuis 2 jours
Quand Kofi ouvre « Travail des élèves »
Alors il voit « Aya … a rejoint la direction le … (avec le code de l'établissement). »
Et Aya ne voit pas de bandeau à son propre sujet

# ID-11
Quand Kofi ouvre Établissement
Alors le bloc « Direction » liste Kofi « (vous) » et Aya, avec « 2 / 3 comptes créés avec le code » si les deux sont arrivés par le code
Et seule la ligne d'Aya a le menu ⋮ « Retirer de la direction »

# ID-12
Quand Kofi retire Aya et confirme
Alors le compte d'Aya est archivé (archived_at, archived_by_id = Kofi), toutes ses sessions sont fermées
Et la ligne quitte le bloc, les places passent à « 1 / 3 », le toast dit « Aya … a été retiré de la direction. »
Et le journal porte « school_staff.archived »

# ID-13
Quand Aya (2 jours) ouvre Établissement
Alors aucune ligne n'a de menu ⋮ et la note « Vous pourrez retirer un compte direction 7 jours après votre arrivée. » s'affiche
Et un DELETE forgé d'Aya sur la ligne de Kofi répond 403 sans rien écrire

# ID-14
Quand Kofi envoie un DELETE sur sa propre ligne
Alors la réponse est 403 et rien n'est écrit

# ID-15
Quand Kofi envoie un DELETE sur une direction de B
Alors la réponse est 404 et rien n'est écrit

# ID-16
Étant donné que A est désactivé
Quand Kofi ouvre Établissement
Alors le bloc « Direction » s'affiche sans menu ⋮, et un DELETE forgé répond 403

# ID-17
Étant donné qu'Aya est archivée
Quand elle se connecte avec son numéro et son bon PIN
Alors la connexion est refusée avec « Numéro ou PIN incorrect »
```

### Équipe (ID-18 à ID-21)

```gherkin
# ID-18
Étant donné un membre de l'équipe field
Quand il retire Kofi depuis le bloc « Direction » de la fiche de A
Alors Kofi est archivé, et « Directions retirées » de la fiche montre « Retiré le … par … · Supprimé le … » (archived_at + 30 jours)

# ID-19
Étant donné qu'Aya, arrivée par le code, est archivée et que A a 2 directions actives par le code
Quand l'équipe admin clique « Restaurer »
Alors Aya est de nouveau active, peut se connecter, revient dans le bloc « Direction » avec le toast « … est de nouveau dans la direction. »
Et le journal porte « school_staff.restored »

# ID-20
Étant donné qu'Aya, arrivée par le code, est archivée et que A a 3 directions actives par le code
Quand l'équipe clique « Restaurer »
Alors la réponse est 409 avec « Les 3 places de direction par le code sont prises : retirez d'abord un compte. » et Aya reste archivée
Mais une direction invitée archivée se restaure dans la même situation

# ID-21
Étant donné 6 directions archivées, de deux établissements
Quand un membre admin ou field ouvre l'accueil de l'équipe
Alors la carte « Directions retirées » montre les 5 plus récentes avec le lien vers leur fiche, et « Et 1 autre, sur la fiche de son établissement. »
Et un membre content ne voit pas la carte, ni « Restaurer » sur la fiche, et un POST forgé de restauration répond 403
```

### Suppression (ID-22)

```gherkin
# ID-22
Étant donné Aya archivée il y a 30 jours et 1 minute, et Kofi archivé il y a 29 jours
Quand la tâche quotidienne de suppression tourne
Alors le compte d'Aya est anonymisé (« Compte supprimé », numéro effacé), ses sessions sont fermées, son rattachement est supprimé, et le journal porte « school_staff.deleted »
Et Kofi est intact
Et la tâche est déclarée dans config/recurring.yml (production)
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Entité `Entities::School::Staff` (`CODE_CAP`, `NEWCOMER_DAYS`, `RETENTION_DAYS`) ; port `StaffRepositoryPort` étendu ; use cases `Identity::RegisterSchoolStaff`, `School::ArchiveSchoolStaff`, `School::RestoreSchoolStaff`, `School::PurgeArchivedStaff` ; leurs quatre policies ; DTO `Dtos::Identity::SchoolStaffRegistrationInput` |
| Infrastructure | Migration `school_staffs` (`joined_via`, `archived_at`, `archived_by_id`, contraintes, index partiel) ; `StaffRepository` ; `UserRepository#authenticate` et `#actor_for` qui excluent l'archivé ; `Queries::School::SchoolStaffQuery` ; `School::PurgeArchivedStaffJob` et `config/recurring.yml` |
| Delivery | `Identity::SchoolStaffRegistrationsController` (débit 10/min) ; `SchoolAdmin::StaffMembersController#destroy` ; `Teams::SchoolStaffMembersController#destroy` ; `Teams::SchoolStaffRestorationsController#create` ; routes de l'UDR-0070 §3.0 |
| UI | `identity/school_staff_registrations/new` ; `homepage/index` (lien, section, pied de page) ; `shared/_school_staff` ; bandeau dans `school_admin/classrooms/index` ; `teams/schools/_archived_staff` ; carte de `teams/homes/show` ; locales `fr` |

## 6. Décisions rattachées

- [ADR-0077](../../decisions/adr/0077-inscription-de-la-direction-par-le-code-et-retrait.md) — inscription par le code, plafond, retrait, archivage et suppression à 30 jours ; amende ADR-0044 et ADR-0065.
- [UDR-0070](../../decisions/udr/0070-inscription-de-la-direction-et-comptes-direction.md) — page d'inscription, page d'accueil, bloc « Direction », bandeau, directions retirées ; amende UDR-0064, 0059, 0052, 0056 et 0018.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Établissements actifs avec au moins une direction | (à relever en production) | en hausse 30 jours après la livraison | |
