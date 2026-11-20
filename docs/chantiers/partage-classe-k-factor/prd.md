# PRD — Partage de la classe et mesure du k-factor élève

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le playbook de lancement d'une ville (décision D4 du programme `retours-terrain-tiassale`) fait inscrire une classe entière par le QR de son lien au tableau, puis les absents par l'invitation d'un camarade, et laisse une affiche en classe. Ce chantier livre ces trois gestes et la mesure qui dit s'ils marchent : chaque inscription élève garde sa source et son invitant, et l'équipe lit le k-factor par classe et par établissement. Aucune donnée d'élève n'est exposée à l'invitant, et le QR ne porte que le lien de classe existant.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Teacher (enseigne la classe, établissement courant) | Afficher le QR de la classe ; imprimer son affiche A4 | Voir qui a invité qui ; imprimer le kit d'un établissement ; le QR d'une classe qu'il n'enseigne pas (404) |
| SchoolStaff (direction de l'établissement de la classe) | Le QR et l'affiche de chaque classe de son établissement ; le **kit** de son établissement | Le kit d'un autre établissement (404) ; voir l'attribution |
| Team | Tout ce qui précède, pour tout établissement ; la section « Partage entre élèves » de la page Croissance | — |
| Student (classe active) | « Invite tes camarades » : un message WhatsApp avec le lien de sa classe, porteur de son code d'invitation | Voir ses invités, leur nombre, une récompense ; l'affiche ou le QR (403) ; la page Croissance (403) |
| Student sans classe active | — | Le bouton n'est pas affiché ; l'envoi direct est refusé (redirigé vers l'accueil, sans code créé) |
| Visiteur | S'inscrire par le QR ou un lien d'invitation, la classe déjà choisie | Rien d'autre que l'existant |
| Parent | — (hors périmètre, pas de compte) | — |

Règles d'autorisation : QR et affiche d'une classe = `Policies::Classroom::ManageClassroomMembersPolicy` (celle qui accorde déjà « Changer le lien ») ; kit d'établissement = nouvelle `Policies::Classroom::PrintSchoolPostersPolicy` (team, ou direction de cet établissement) ; invitation élève = nouvelle `Policies::Classroom::InviteClassmatesPolicy` (élève avec une classe principale active) ; section Croissance = `Policies::Identity::ReadGrowthPolicy` (existante).

## 3. Parcours utilisateur

### Chemin nominal

1. **QR (enseignant)** : sur la page de sa classe, carte « Inscrire vos élèves », bouton « QR code ». Une fenêtre montre le QR (grand), le nom de la classe et « Imprimer l'affiche ». Le QR encode `https://<hôte>/c/<jeton>?s=qr`.
2. **Affiche** : « Imprimer l'affiche » ouvre une page A4 imprimable : nom de la classe et de l'établissement, QR, lien court lisible, trois étapes (1. Scanne le QR · 2. Touche « Je suis élève » · 3. Ton numéro et ton code secret). Le dialogue d'impression du navigateur s'ouvre par un bouton « Imprimer » (masqué à l'impression).
3. **Kit (direction, équipe)** : depuis la page de l'établissement, « Imprimer les affiches des classes » ouvre une page d'une A4 par classe ouverte de l'année en cours, triées par niveau puis nom.
4. **Élève invité par QR** : il scanne, arrive sur l'inscription, la classe déjà choisie, s'inscrit. Son inscription est attribuée « QR ».
5. **Invitation élève** : sur son accueil, l'élève touche « Invite tes camarades ». WhatsApp s'ouvre avec le message prêt : « Rejoins la classe <classe> de <établissement> sur Lnclass : <lien> ». Le lien = `/c/<jeton>?i=<code>`, `<code>` étant le code d'invitation de l'élève (créé au premier envoi, puis réutilisé).
6. **Élève invité par un camarade** : il ouvre le lien, s'inscrit ; son inscription est attribuée « invitation d'un élève », avec l'invitant.
7. **Mesure (équipe)** : page Croissance, section « Partage entre élèves », pour la période choisie (7, 30, 90 jours) : deux tableaux, par établissement et par classe, colonnes Inscrits · QR · Invitation · Lien · Code · À froid · k, plus une ligne de total et « Mesuré depuis le <date de la première attribution> ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| `i` inconnu, mal formé, ou code d'un élève anonymisé | Ignoré sans message ; l'inscription réussit, attribuée « lien de l'enseignant » (ou « QR » si `s=qr`) |
| `s` autre que `qr` | Ignoré |
| Lien changé, classe archivée, établissement inactif | L'existant : voie standard avec l'alerte ; l'inscription par la cascade est « à froid » |
| Inscription par le code de classe tapé | Source « code » |
| Inscription par la cascade, sans lien | Source « à froid » |
| L'inscription échoue (numéro pris, classe complète) | Aucune attribution écrite (même transaction) ; les champs cachés `s` et `i` sont conservés au nouvel affichage du formulaire |
| Élève déjà inscrit qui ouvre un lien d'invitation | L'existant (accueil, ou « Changer de classe ? ») ; aucune attribution |
| Élève sans classe active envoie « Invite tes camarades » | Redirigé vers l'accueil, aucun code créé |
| Enseignant d'une autre classe ouvre l'affiche | 404 (comme la page de la classe) |
| Élève ouvre l'URL de l'affiche ou du kit | 403 |
| Direction ouvre le kit d'un autre établissement | 404 |
| Classe archivée | Ni bouton QR ni affiche (page 404) |
| Kit d'un établissement sans classe ouverte | Page « Aucune classe ouverte cette année. » sans A4 |
| Aucune inscription attribuée sur la période | Section « Partage entre élèves » : « Aucune inscription attribuée sur la période. » ; k « — » |
| Classe ou établissement avec 0 inscrit sur la période | Absent des tableaux (on ne liste que ce qui a des inscrits) |
| L'enseignant change le lien | La confirmation dit que les QR et affiches imprimés ne marcheront plus |

## 4. Critères d'acceptation

```gherkin
# Lot 0 — socle
Scénario: une attribution est unique par élève et jamais réécrite
  Étant donné un élève avec une attribution « qr »
  Quand on enregistre une seconde attribution pour lui
  Alors la première reste, inchangée

Scénario: un code d'invitation est stable et opaque
  Étant donné un élève sans code d'invitation
  Quand on demande son code deux fois
  Alors on obtient deux fois le même code de 8 caractères de l'alphabet sans ambiguïté
  Et le code ne contient ni son identifiant ni son identifiant public

Scénario: le code d'un élève anonymisé ne désigne plus personne
  Étant donné un élève anonymisé qui avait un code d'invitation
  Quand on cherche l'invitant de ce code
  Alors on ne trouve personne

# Lot A — QR de classe
Scénario: l'enseignant de la classe voit le QR de son lien
  Étant donné un enseignant qui enseigne la 3e B
  Quand il ouvre la page de la 3e B
  Alors la carte « Inscrire vos élèves » propose « QR code »
  Et le QR encode le lien /c/<jeton de la 3e B>?s=qr, et rien d'autre

Scénario: changer le lien prévient que les affiches imprimées ne marcheront plus
  Quand l'enseignant ouvre « Changer le lien »
  Alors la confirmation dit que les QR et affiches déjà imprimés ne marcheront plus

# Lot B — invitation élève
Scénario: l'élève invite ses camarades
  Étant donné un élève inscrit dans la 3e B
  Quand il touche « Invite tes camarades »
  Alors il est envoyé vers WhatsApp avec un message qui contient /c/<jeton de la 3e B>?i=<son code>
  Et le message nomme la classe et l'établissement
  Et aucun nom d'élève n'apparaît dans le message

Scénario: le code est réutilisé d'un envoi à l'autre
  Quand l'élève touche deux fois « Invite tes camarades »
  Alors les deux messages portent le même code

Scénario: un élève sans classe n'invite personne
  Étant donné un élève sans classe active
  Alors son accueil n'affiche pas « Invite tes camarades »
  Et l'envoi direct le ramène à l'accueil sans créer de code

Scénario: une seule bannière d'invitation sur l'accueil
  Étant donné un élève dont la classe a un enseignant
  Alors l'accueil montre « Invite tes camarades » et pas « Ton enseignant n'est pas sur Lnclass ? »
  Étant donné un élève dont la classe n'a aucun enseignant
  Alors l'accueil montre aussi l'invitation de l'enseignant

# Lot C — attribution à l'inscription
Scénario: inscription par le QR
  Quand un visiteur s'inscrit depuis /c/<jeton>?s=qr
  Alors son attribution a la source « qr », la classe du lien et aucun invitant

Scénario: inscription par l'invitation d'un élève
  Étant donné un élève de la 3e B dont le code est k7m4q2ab
  Quand un visiteur s'inscrit depuis /c/<jeton de la 3e B>?i=k7m4q2ab
  Alors son attribution a la source « student_invite » et cet élève pour invitant

Scénario: un code inconnu ne fait jamais échouer l'inscription
  Quand un visiteur s'inscrit depuis /c/<jeton>?i=zzzzzzzz
  Alors l'inscription réussit
  Et son attribution a la source « teacher_link » sans invitant

Scénario: inscription par le lien de l'enseignant, le code, la cascade
  Quand un visiteur s'inscrit depuis /c/<jeton> sans paramètre
  Alors la source est « teacher_link »
  Quand un visiteur s'inscrit avec le code de classe
  Alors la source est « code »
  Quand un visiteur s'inscrit en choisissant sa classe
  Alors la source est « cold »

Scénario: une inscription refusée n'écrit rien
  Quand l'inscription échoue (numéro déjà pris)
  Alors aucune attribution n'est écrite
  Et le formulaire ré-affiché garde s et i

# Lot D — affiche et kit
Scénario: l'enseignant imprime l'affiche de sa classe
  Quand l'enseignant de la 3e B ouvre l'affiche de la 3e B
  Alors la page A4 montre le nom de la classe, l'établissement, le QR du lien ?s=qr et les trois étapes
  Et un enseignant d'une autre classe reçoit 404, un élève 403

Scénario: la direction imprime le kit de son établissement
  Quand la direction ouvre le kit de son établissement
  Alors il y a une page A4 par classe ouverte de l'année
  Et le kit d'un autre établissement répond 404

# Lot E — mesure
Scénario: l'équipe lit le k-factor par classe et par établissement
  Étant donné, sur la période, en 3e B : 10 inscrits dont 4 par QR, 2 par invitation, 3 par lien, 1 à froid
  Quand l'équipe ouvre la page Croissance
  Alors la ligne 3e B montre 10 · 4 · 2 · 3 · 0 · 1 et k = 0,6
  Et la ligne de l'établissement agrège ses classes
  Et aucune ligne ne nomme un élève

Scénario: période vide
  Étant donné aucune attribution sur la période
  Alors la section dit « Aucune inscription attribuée sur la période. »

Scénario: les autres rôles ne voient pas la mesure
  Quand un enseignant ou un élève ouvre la page Croissance
  Alors il est refusé (l'existant)
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Entities::Classroom::SignupSource` (liste fermée + résolution pure) ; `Entities::Classroom::InviteCode` (format, normalisation, génération) ; ports `Ports::Classroom::SignupAttributionRepositoryPort`, `Ports::Classroom::InviteCodeRepositoryPort` ; use case `UseCases::Classroom::InviteClassmates` ; `RegisterStudent` écrit l'attribution ; DTO `StudentRegistrationInput` + `arrival_source`, `invite_code` ; policies `InviteClassmatesPolicy`, `PrintSchoolPostersPolicy` |
| Infrastructure | migration : tables `signup_attributions`, `student_invite_codes` ; `Orm::Classroom::SignupAttribution`, `Orm::Classroom::StudentInviteCode` ; repositories des deux ports ; query `Queries::Classroom::SignupKFactorQuery` ; query de l'affiche `Queries::Classroom::PosterQuery` |
| Delivery | `GET /classrooms/:public_id/poster`, `GET /schools/:school_public_id/posters`, `POST /students/class-invite` ; `Classroom::PostersController`, `Classroom::SchoolPostersController`, `Classroom::ClassInvitesController` ; `JoinsController` et `StudentRegistrationsController` transmettent `s` et `i` |
| UI | QR dans `_link` (fenêtre) ; vues d'affiche (gabarit `print`) ; bannière « Invite tes camarades » de l'accueil ; section « Partage entre élèves » de la page Croissance ; bouton du kit sur les pages d'établissement (direction, équipe) |

## 6. Décisions rattachées

- ADR-XXXX-attribution-des-inscriptions-eleves — table d'attribution, code d'invitation opaque, étiquette `s=qr`.
- UDR-XXXX-partage-de-classe-qr-affiche-invitation — QR, affiche A4, kit, bannière d'invitation élève, section k de la page Croissance.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Inscriptions élèves avec une source | 0 % (n'existe pas) | 100 % des nouvelles inscriptions | |
| k élève par classe à J+14 (playbook) | non mesurable | ≥ 0,5 | à lire après le premier lancement |
