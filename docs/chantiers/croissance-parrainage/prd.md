# PRD — Croissance par parrainage entre enseignants, démarrage à froid et mesure du k-factor

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Le porteur vise un k-factor enseignant de 2 (memo, modèle k = i × c). On livre trois boucles : un **lien de parrainage** personnel bâti sur le code secret d'établissement (ADR-0057), un **démarrage à froid** par le code national qui crée un compte en attente validé par l'équipe ou par un garant, et le **partage WhatsApp du lien de classe** pour l'amplification élèves. Une page équipe « Croissance » mesure le k, sa décomposition, le cycle viral et l'amplification, sans traceur (ADR-0049).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur | s'inscrire par un lien parrainé ; s'inscrire en attente par code national ou recherche d'établissement | voir qui l'a parrainé ; connaître l'existence d'un jeton |
| Enseignant d'un établissement **actif** | voir et partager son lien personnel ; voir son compteur de filleuls et son badge ; se porter garant d'un collègue en attente de **son** établissement ; partager le lien de ses classes | se porter garant pour un autre établissement ; se valider lui-même ; voir le numéro d'un collègue en attente ; voir la page Croissance (403) |
| Enseignant **en attente** (sans établissement) | voir l'écran d'attente, se déconnecter | toute autre page (renvoyé vers l'écran d'attente) ; inviter (403) |
| Enseignant d'un établissement inactif ou en brouillon | ses pages habituelles | inviter (bloc absent, 403) ; se porter garant |
| Équipe | valider / refuser une demande depuis la fiche ; saisir le code national ; lire la page Croissance et le classement | — |
| Élève, direction | — | enregistrer un partage, se porter garant, valider, lire la page Croissance : 403 |

Policies : `Identity::InviteColleaguePolicy` (enseignant d'un établissement actif), `School::VouchPolicy` (garant), `School::ManageSchoolPolicy` (équipe : validation, code national), `Identity::ReadGrowthPolicy` (équipe), `Identity::RegisterTeacherPolicy` (visiteur, inchangée).

## 3. Parcours utilisateur

### Chemin nominal — parrainage

1. Aya, enseignante active, ouvre son accueil : bloc « Inviter un collègue », avec son lien, « WhatsApp », « SMS », « Copier le lien » et, si le navigateur l'offre, « Partager… ».
2. Elle touche « WhatsApp » : le partage est compté par le serveur, WhatsApp s'ouvre avec le message prêt.
3. Koffi ouvre le lien : la page d'inscription montre son établissement ; il s'inscrit ; Aya devient sa marraine.
4. Le compteur d'Aya passe à « 1 collègue inscrit grâce à vous » ; au troisième, le badge « Ambassadeur » apparaît sur son profil.

### Chemin nominal — démarrage à froid

1. Awa n'a pas de code : sur l'inscription, elle suit « Mon établissement n'a pas encore de code Lnclass ».
2. Elle saisit le code national de son lycée (ou choisit sa DRENA puis son établissement), ses informations, sa matière, son PIN.
3. Son compte est créé **en attente** : elle ne voit que l'écran « Votre demande est en cours de validation ».
4. L'équipe valide depuis la fiche de l'établissement (« Enseignants en attente », Valider) ; ou un enseignant actif du même établissement touche « Je confirme » sur son accueil et devient son parrain.
5. À sa connexion suivante, Awa arrive sur la déclaration de ses classes.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Jeton absent, mal formé, inconnu, ou d'un enseignant d'un autre établissement | Inscription normale, sans parrain, sans message |
| Code national inconnu, ou établissement inactif / en brouillon | « Établissement introuvable. Vérifiez le code national. » sur le champ |
| Ni code national ni établissement choisi | « Saisissez le code national ou choisissez votre établissement. » |
| 5 demandes déjà en attente pour cet établissement | « Trop de demandes sont en attente pour cet établissement. Réessayez plus tard ou contactez l'équipe Lnclass. » |
| Plus de 5 envois par minute depuis une adresse | 429, « Trop de tentatives » |
| Demande déjà traitée (validée, refusée) | toast « Cette demande a déjà été traitée. » |
| Demande refusée | écran « Votre demande n'a pas été acceptée » |
| Enseignant en attente qui ouvre le catalogue | renvoyé vers l'écran d'attente |
| Élève ou enseignant sur `/teams/growth` | 403 |

## 4. Critères d'acceptation

```gherkin
# CP-01 — lien personnel
Étant donné une enseignante active d'un établissement actif
Quand elle ouvre son accueil
Alors elle voit son lien « /e/<code d'établissement>?ref=<jeton> »
Et le jeton n'est ni son identifiant public ni son numéro

# CP-02 — attribution
Étant donné le lien parrainé d'Aya
Quand Koffi s'inscrit par ce lien
Alors Aya est enregistrée comme sa marraine, de source « lien »

# CP-03 — jeton refusé sans bruit
Étant donné un jeton inconnu, mal formé, ou celui d'un enseignant d'un autre établissement
Quand un visiteur s'inscrit par le lien
Alors son compte est créé
Et aucun parrain n'est enregistré

# CP-04 — partage compté côté serveur
Quand Aya touche « WhatsApp », « SMS », « Copier le lien » ou « Partager… »
Alors un partage de ce canal est enregistré par le serveur
Et aucun cookie n'est posé en plus de la session

# CP-05 — bloc « Inviter un collègue »
Alors le lien WhatsApp est « https://wa.me/?text= » suivi d'un message en français
Et le message contient le nom de l'établissement et le lien parrainé
Et le lien SMS commence par « sms: » avec le même message
Et « Partager… » n'apparaît que si le navigateur offre le partage natif

# CP-06 — compteur
Étant donné deux filleuls d'Aya
Alors son accueil affiche « 2 collègues inscrits grâce à vous »

# CP-07 — seul un enseignant d'un établissement actif invite
Étant donné un enseignant d'un établissement en brouillon, un élève, un membre de l'équipe
Alors le bloc n'apparaît pas pour l'enseignant
Et l'enregistrement d'un partage leur répond 403

# CP-08 — partage de la classe
Étant donné la page d'une classe qui a un code
Alors « Partager sur WhatsApp » ouvre « https://wa.me/?text= » avec le nom de la classe, l'établissement, le lien /c/<code> et le code
Et le message ne contient aucun nom d'élève

# CP-09 — code national en base et à l'import
Alors un établissement accepte un code national de 6 chiffres, unique, ou aucun
Et l'import accepte la clé facultative « national_code »
Et un code mal formé ou déjà pris est signalé à sa ligne, les autres établissements sont importés
Et les établissements existants gardent leurs données

# CP-10 — code national sur la fiche et dans la recherche
Alors l'équipe lit et modifie le code national sur la fiche
Et la recherche des établissements trouve un établissement par son code national

# CP-11 — démarrage à froid
Quand Awa s'inscrit par le code national (ou par sa DRENA et son établissement)
Alors son compte enseignant est créé sans établissement, avec une demande en attente
Et elle ne voit que l'écran « en attente de validation »
Et toute autre page la renvoie vers cet écran

# CP-12 — validation par l'équipe
Étant donné la fiche d'un établissement qui a une demande en attente
Quand l'équipe touche « Valider »
Alors l'enseignante est rattachée à l'établissement et arrive sur ses classes à la connexion suivante
Et la décision est tracée au journal d'audit
Quand l'équipe touche « Refuser » et confirme
Alors la demande est refusée, tracée, et l'enseignante voit « Votre demande n'a pas été acceptée »

# CP-13 — garant
Étant donné un enseignant actif du même établissement
Quand il touche « Je confirme » sur la demande de sa collègue
Alors elle est rattachée automatiquement
Et il devient son parrain, de source « garant »
Et un enseignant d'un autre établissement reçoit 403

# CP-14 — anti-abus
Étant donné 5 demandes en attente pour un établissement
Alors une sixième est refusée avec un message nommé
Et l'envoi est limité à 5 par minute et par adresse

# CP-15 — badge Ambassadeur
Étant donné une enseignante qui a 3 filleuls
Alors son profil affiche le badge « Ambassadeur »
Et à 2 filleuls, il n'apparaît pas

# CP-16 — classement des établissements
Alors la page Croissance classe les établissements par nombre d'enseignants actifs
Et aucune page enseignant ne l'affiche

# CP-17 — métriques
Étant donné une période
Alors la query renvoie partages, inscriptions enseignants, inscriptions parrainées, conversion, k enseignant (i × c), cycle viral médian, meilleurs parrains, amplification élèves
Et elle s'exécute en un nombre de requêtes borné, indépendant du volume

# CP-18 — page Croissance
Alors « /teams/growth » est réservée à l'équipe (403 sinon)
Et elle est liée depuis l'accueil équipe, sans entrée de navigation
Et « /teams/dashboard » n'est pas modifié
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | entités `Identity::ReferralToken`, `Identity::ShareChannel`, `Identity::Ambassador`, `Identity::ViralCoefficient`, `School::NationalCode`, `School::JoinRequest` ; ports `Identity::ReferralRepositoryPort`, `School::JoinRequestRepositoryPort` (+ `SchoolRepositoryPort` étendu) ; use cases `Identity::RegisterTeacher` (parrain), `Identity::RegisterPendingTeacher`, `Identity::RecordReferralShare`, `School::ReviewJoinRequest`, `School::VouchForTeacher` ; policies `Identity::InviteColleaguePolicy`, `Identity::ReadGrowthPolicy`, `School::VouchPolicy` |
| Infrastructure | migrations `referrals`, `referral_shares`, `teacher_profiles.referral_token`, `schools.national_code`, `school_join_requests` ; `Orm::Referral`, `Orm::ReferralShare`, `Orm::SchoolJoinRequest` ; repositories ; queries `Identity::ReferralQuery`, `Identity::GrowthMetricsQuery`, `School::JoinRequestsQuery` |
| Delivery | routes `/teachers/invite`, `/teachers/invite/shares`, `/teacher-signup/without-code`, `/teachers/join-requests/:id/vouch`, `/teams/schools/:id/join-requests/:id`, `/teams/growth` |
| UI | bloc d'invitation, collègues en attente, partage de classe, inscription sans code, écran d'attente, liste de la fiche, page Croissance ; contrôleur Stimulus `identity--share` |

## 6. Décisions rattachées

- [ADR-0063](../../decisions/adr/0063-parrainage-demarrage-a-froid-et-mesure-du-k-factor.md) — tables, jeton, attribution, compte en attente, garant, métriques.
- [UDR-0050](../../decisions/udr/0050-inviter-un-collegue-et-croissance.md) — bloc d'invitation, partage de classe, inscription sans code, écran d'attente, validation, page Croissance.
- Amende ADR-0057 (le code circule par les liens de parrainage), ADR-0030 (enseignant sans établissement = compte en attente), UDR-0006 (aucune entrée), UDR-0018 (raccourci « Croissance »), UDR-0026, UDR-0027, UDR-0036, UDR-0044.

## 7. Mesures

| Métrique | Avant | Cible (30 j) | Après |
|---|---|---|---|
| k enseignant (cohorte) | non mesuré | 0,75 (ambition 2) | lu sur `/teams/growth` |
| Conversion par partage | non mesuré | 25 % | idem |
| Cycle viral médian | non mesuré | ≤ 7 j | idem |
| Élèves par enseignant actif | non mesuré | 40 | idem |
| Requêtes de la query de métriques | — | bornées (≤ 12) | test de comptage |
