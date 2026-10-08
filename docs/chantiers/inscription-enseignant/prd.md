# PRD — Amélioration du parcours d'inscription des enseignants

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Un enseignant peut s'inscrire de trois façons (code d'établissement, choix manuel DRENA → établissement, lien d'un collègue) : le code est introuvable, le parcours confus, et la page demande trop. Ce chantier ne garde que **deux entrées** : l'**inscription standard** (DRENA → établissement → matière → nom complet, genre, contact → code secret) et le **lien d'invitation** (d'un collègue, de la direction ou de l'équipe), qui arrive avec l'établissement déjà choisi. La saisie du code d'établissement disparaît de l'inscription enseignant, le nom et les prénoms se saisissent en un seul champ, et chaque enseignant garde la voie par laquelle il est arrivé. Voir le [memo](memo.md), Q1 à Q15.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur (futur enseignant) | S'inscrire par la voie standard ; s'inscrire par un lien d'invitation valable, l'établissement déjà choisi ; quitter l'établissement du lien (« Ce n'est pas votre établissement ? ») pour la voie standard | Saisir un code d'établissement ; choisir un établissement en brouillon ou désactivé ; s'inscrire avec un numéro qui a déjà un compte |
| Teacher (connecté) | Copier et partager son lien « Inviter un collègue » (fermé sans établissement actif, comme aujourd'hui) ; ouvrir WhatsApp directement depuis la bulle « Inviter » de la section « Cours » de son accueil | Ouvrir l'inscription ou un lien d'invitation : il est renvoyé vers son accueil (`GET`) ou reçoit 403 (`POST`) ; rejoindre un second établissement par un lien |
| SchoolStaff (direction) | Copier et partager le lien d'invitation de son établissement, sans code affiché | « Changer le lien » (retiré) |
| Team | Chercher un établissement par nom ou sigle dans `/teams/schools` (plus par code national, plus de colonne « Code d'établissement ») ; copier le lien d'invitation d'un établissement depuis sa fiche ; voir la voie d'arrivée des enseignants dans la liste « Enseignants » de la fiche (il n'existe pas de fiche enseignant) | — « Régénérer le code » reste, pour l'inscription de la direction, jusqu'au chantier `inscription-direction-sans-code` |
| Student, Parent | Rien ne change | — |

Règles d'autorisation : l'inscription est publique et refusée à toute personne connectée (règle existante de l'inscription). « Inviter un collègue » reste sous `InviteColleaguePolicy` ; le lien de la direction sous les règles de l'espace direction ; celui de l'équipe sous la gestion des établissements.

## 3. Parcours utilisateur

### Chemin nominal — inscription standard

1. Le visiteur ouvre `/teacher-signup` (page d'accueil « Je suis enseignant », ou application).
2. Rubrique **Établissement** : il choisit sa DRENA ; la liste de ses établissements actifs se charge ; il choisit son établissement, puis sa matière.
3. Rubrique **Vous** : il saisit son nom (« KOUASSI ») et ses prénoms (« Aya Marie ») dans deux champs (ADR-0037, memo Q24). Il choisit son genre et saisit son numéro : le champ n'accepte que des chiffres, 10 au plus, et retire en direct `+225`, `(+225)`, `00225` et les espaces.
4. Rubrique **Code secret** : code secret et confirmation. Dès que la confirmation a 4 chiffres, une icône et un message sous le champ disent « Les codes concordent. » ou « Les codes ne concordent pas. ».
5. « Créer mon compte » : le compte est créé, l'enseignant est **rattaché tout de suite** à l'établissement (école principale), sa voie d'arrivée est « standard », la session s'ouvre et il arrive sur « Quelles classes enseignez-vous ? » avec « Bienvenue ! ».

### Chemin nominal — lien d'invitation

1. Le visiteur ouvre le lien reçu (d'un collègue, de la direction ou de l'équipe).
2. La même page s'ouvre ; la rubrique Établissement montre l'établissement et sa DRENA déjà choisis (bandeau), avec « Ce n'est pas votre établissement ? ». Il choisit sa matière.
3. Rubriques Vous et Code secret comme ci-dessus (nom, prénoms, genre, numéro, code secret).
4. « Créer mon compte » : rattaché à l'établissement du lien ; voie d'arrivée « lien d'un collègue » (avec le collègue, et le parrainage compté comme aujourd'hui), « lien de la direction » ou « lien de l'équipe ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Nom ou prénoms vides | 422, message existant sous le champ (ADR-0037) |
| Nom ou prénoms avec espaces multiples | Normalisés (`squish`) ; casse saisie gardée (ADR-0037) |
| Caractère interdit dans le nom (chiffre, symbole) | 422, message existant de nom invalide |
| Numéro déjà inscrit | 422, message existant « Ce numéro est déjà utilisé. » sous le champ, sans révéler le rôle |
| DRENA non choisie, ou établissement absent de la DRENA, en brouillon ou désactivé | 422, message sous le champ ; aucun compte créé |
| Lien d'invitation inconnu, d'un établissement désactivé, ou d'un collègue retiré ou supprimé | La page standard s'ouvre avec l'alerte « Ce lien n'est plus valable. Choisissez votre établissement. » ; voie « standard » |
| « Ce n'est pas votre établissement ? » depuis un lien | La page standard s'ouvre sans établissement ; voie « standard » ; pas de parrainage |
| Personne connectée qui ouvre `/teacher-signup` ou un lien d'invitation | Renvoyée vers son accueil ; `POST` → 403 |
| Enseignant retiré, sur l'écran d'attente | Il choisit DRENA puis établissement ; rattaché tout de suite ; l'établissement qui l'a retiré est refusé par une erreur neutre (422) |
| Ancienne adresse `/e/<code>` | 404 (aucun lien partagé, memo Q11) |
| Plus de 5 envois par minute | 429 re-rendu dans le formulaire (règle existante) |

## 4. Critères d'acceptation

Formulés de manière vérifiable. Chacun devient un test. Identifiants `IE-NN`.

```gherkin
# IE-01 — inscription standard
Étant donné un établissement actif « Lycée Moderne de Cocody » de la DRENA « Abidjan 1 »
Quand un visiteur choisit cette DRENA, cet établissement, la matière « SVT »,
  saisit le nom « KOUASSI » et les prénoms « Aya Marie », choisit « Féminin », saisit un numéro libre et un code secret confirmé
Alors un compte enseignant est créé avec le nom « KOUASSI » et les prénoms « Aya Marie »
Et il est rattaché à cet établissement comme école principale, sans demande en attente
Et sa voie d'arrivée est « standard »
Et il arrive sur « Quelles classes enseignez-vous ? » avec « Bienvenue ! »

# IE-02 — plus de code d'établissement
Quand un visiteur ouvre /teacher-signup
Alors la page ne contient aucun champ « Code d'établissement »
Et les rubriques apparaissent dans l'ordre : Établissement, Vous, Code secret
Et le mot « PIN » n'apparaît nulle part dans la page
Et /e/K7M-4QZ répond 404

# IE-03 — nom et prénoms en deux champs (memo Q24)
Quand un visiteur ouvre /teacher-signup
Alors la rubrique « Vous » montre, dans l'ordre, « Nom », « Prénom(s) », « Genre », « Numéro de téléphone »
Et aucun champ « Nom complet » ni « Corriger » n'existe
Quand il saisit le nom « N'GUESSAN » et les prénoms « Konan  Jean-Baptiste »
Alors le nom enregistré est « N'GUESSAN » et les prénoms « Konan Jean-Baptiste »

# IE-04 — (fusionné dans IE-03)

# IE-05 — nom ou prénoms manquants
Quand le formulaire est envoyé sans prénoms
Alors la page est re-rendue en 422 avec le message existant sous « Prénom(s) »
Et aucun compte n'est créé

# IE-06 — lien d'un collègue
Étant donné un enseignant Awa rattaché au « Lycée Moderne de Cocody » et son lien « Inviter un collègue »
Quand un visiteur ouvre ce lien
Alors l'établissement et sa DRENA sont affichés, déjà choisis, sans code d'établissement
Et le lien ne contient pas le code de l'établissement
Quand il complète matière, nom, prénoms, genre, numéro et code secret
Alors il est rattaché à ce lycée, sa voie d'arrivée est « lien d'un collègue » avec Awa
Et l'inscription compte dans le parrainage d'Awa

# IE-07 — lien de la direction
Étant donné la direction du « Lycée Moderne de Cocody »
Quand elle ouvre la page Établissement de son espace
Alors le bloc du lien montre « Copier le lien » et « Partager sur WhatsApp », sans code ni « Changer le lien »
Quand un visiteur s'inscrit par ce lien
Alors sa voie d'arrivée est « lien de la direction », sans parrain

# IE-08 — lien de l'équipe
Quand l'équipe copie le lien d'invitation depuis la fiche d'un établissement et qu'un visiteur s'inscrit par ce lien
Alors sa voie d'arrivée est « lien de l'équipe », sans parrain

# IE-09 — lien devenu invalide
Étant donné un lien d'invitation d'un établissement désactivé, ou d'un collègue retiré de l'établissement
Quand un visiteur l'ouvre
Alors la page standard s'affiche avec « Ce lien n'est plus valable. Choisissez votre établissement. »
Et une inscription faite depuis cette page a la voie « standard »

# IE-10 — « Ce n'est pas votre établissement ? »
Quand un visiteur arrivé par le lien d'un collègue choisit « Ce n'est pas votre établissement ? » puis s'inscrit
Alors sa voie d'arrivée est « standard » et le parrainage n'est pas compté

# IE-11 — établissement hors liste
Quand le formulaire est envoyé avec un établissement en brouillon, désactivé ou d'une autre DRENA
Alors la page est re-rendue en 422 et aucun compte n'est créé

# IE-12 — numéro déjà inscrit
Étant donné un compte existant (enseignant, élève ou direction) sur le numéro 0700000001
Quand un visiteur s'inscrit avec ce numéro
Alors la page est re-rendue en 422 avec « Ce numéro est déjà utilisé. » sous le champ
Et le message ne révèle pas le rôle du compte existant

# IE-13 — personne connectée
Étant donné un enseignant connecté
Quand il ouvre /teacher-signup ou un lien d'invitation
Alors il est renvoyé vers son accueil
Et un POST /teacher-signup reçoit 403

# IE-14 — enseignants existants
Étant donné des enseignants inscrits avant le chantier par le code, par la voie sans code et par le lien d'un collègue
Après la mise à jour de la base
Alors leur rattachement est inchangé
Et leur voie d'arrivée vaut respectivement « code », « standard » et « lien d'un collègue »

# IE-15 — voie visible par l'équipe
Quand l'équipe ouvre la fiche d'un établissement
Alors chaque ligne de la liste « Enseignants » montre la voie d'arrivée (et le collègue, pour un lien d'un collègue)

# IE-17 — vérification en direct de la confirmation
Étant donné la page d'inscription ouverte avec JavaScript
Quand le visiteur saisit « 1234 » puis « 1235 » en confirmation
Alors une icône d'erreur et « Les codes ne concordent pas. » apparaissent sous le champ confirmation, dont le bord passe au rouge, s'affiche dessous, annoncé aux lecteurs d'écran
Quand il corrige la confirmation en « 1234 »
Alors une icône de succès remplace l'icône d'erreur, « Les codes concordent. » s'affiche et le bord passe au vert
Et tant que la confirmation a moins de 4 chiffres, ni icône ni message ne s'affichent
Et sans JavaScript, des codes différents sont refusés au renvoi (422, message existant)

# IE-18 — écran d'attente sans code
Étant donné un enseignant retiré du « Lycée Moderne de Cocody », connecté, sur l'écran d'attente
Alors l'écran ne contient aucun champ « Code d'établissement »
Quand il choisit la DRENA « Abidjan 1 » puis le « Lycée Classique d'Abidjan »
Alors il est rattaché à ce lycée comme école principale et arrive sur son accueil
Quand il choisit le « Lycée Moderne de Cocody »
Alors l'écran est re-rendu en 422 avec l'erreur neutre et il n'est rattaché à rien

# IE-19 — numéro nettoyé en direct
Étant donné la page d'inscription ouverte avec JavaScript
Quand le visiteur colle « +225 07 01 02 03 04 » dans le champ du numéro
Alors le champ affiche « 0701020304 »
Quand il colle « (+225) 0701020304 » ou « 002250701020304 »
Alors le champ affiche « 0701020304 »
Quand il tape une lettre ou un 11e chiffre
Alors le champ ne change pas
Et sans JavaScript, « +225 07 01 02 03 04 » envoyé est enregistré « 0701020304 » (normalisation existante du serveur)

# IE-20 — « Inviter » ouvre WhatsApp
Étant donné un enseignant rattaché à un établissement actif, sur son accueil
Quand il touche la bulle « Inviter » de la section « Cours »
Alors WhatsApp s'ouvre (lien wa.me) avec le message d'invitation contenant son lien /i/<jeton>, dans un nouvel onglet
Et le partage est compté sur le canal « whatsapp »
Et la page « Inviter un collègue » reste accessible par sa propre adresse et par la carte latérale

# IE-21 — tableau des établissements de l'équipe
Quand l'équipe ouvre /teams/schools
Alors le tableau n'a pas de colonne « Code d'établissement »
Et le champ de recherche s'intitule « Nom ou sigle »
Quand elle cherche « 012345 », le code national d'un établissement
Alors cet établissement n'est pas trouvé par son code national
Quand elle cherche « Lycée Classique » ou « LCA »
Alors l'établissement est trouvé

# IE-22 — numéros des élèves masqués dans la classe, pour tous les enseignants
Étant donné un enseignant déclaré dans la classe 3ème 1, quelle que soit sa voie d'arrivée (standard, collègue, direction, équipe, ancien code)
Quand il ouvre la liste des élèves de la 3ème 1
Alors le numéro de chaque élève s'affiche masqué, sous la forme « 07 •• •• •• 04 »
Et le numéro complet n'apparaît nulle part dans la page (ni texte, ni lien tel:, ni attribut)
Et l'équipe Lnclass garde l'accès au numéro complet dans ses écrans de support

# IE-23 — trace d'audit de chaque inscription
Quand un enseignant s'inscrit, par n'importe quelle voie
Alors une ligne d'audit « school.changed / teacher_joined » porte l'établissement et la voie d'arrivée

# IE-24 — « code secret » partout (memo Q25)
Quand on parcourt les écrans de l'application (connexion, profil, changement et réinitialisation du code, inscriptions élève, enseignant et direction, invitations, aide)
Alors le mot « PIN » n'apparaît dans aucun texte affiché ni dans aucun libellé accessible
Et le secret à 4 chiffres s'appelle « code secret » (« Confirmation du code secret », « Code secret oublié ? », « Les deux codes secrets ne sont pas identiques. »)

# IE-16 — direction inchangée
Quand une direction s'inscrit par /school-staff-signup avec le code d'établissement
Alors son inscription fonctionne comme avant ce chantier
```

## 5. Modélisation préliminaire

Établie après exploration du code existant (contexte `identity`, avec `school` pour le rattachement).

| Couche | Éléments prévus |
|---|---|
| Domaine | **Un seul use case** `UseCases::Identity::RegisterTeacher`, qui absorbe `RegisterPendingTeacher` : policy `RegisterTeacherPolicy` (inchangée) → DTO → invitation résolue (ou aucune) → établissement actif de la DRENA (ou celui de l'invitation) → `create_teacher` → `attach_teacher(primary: true)` → parrainage si lien d'un collègue → session. `UseCases::School::JoinSchoolWithCode` devient un rattachement par établissement choisi (`school_public_id` de la DRENA au lieu du code), règle des départs inchangée. **Plus de demande en attente** (`school_join_requests`) pour une nouvelle inscription. Nouveau DTO `TeacherRegistrationInput` : `last_name`, `first_name`, `gender`, `contact`, `pin`, `pin_confirmation`, `drena_public_id`, `school_public_id`, `material_slug`, `invite_token` ; plus de `school_code` ni de `national_code`. Nouvelle entité-valeur `Entities::Identity::ArrivalChannel` (`standard`, `colleague`, `direction`, `team`, `code`). Nouveau port de lecture des liens d'invitation (`resolve(token:)` → établissement, émetteur, voie). |
| Infrastructure | Migration : `teacher_profiles.joined_via` (CHECK sur les cinq voies, sur le modèle de `school_staffs.joined_via`) avec reprise de l'historique ; table des liens d'invitation d'établissement (direction, équipe) à jeton stable. Repository des liens d'invitation ; `RegistrationRepository#create_teacher` reçoit la voie. `ReferralQuery`, `OwnSchoolQuery`, `SchoolDetailQuery` exposent le jeton du lien au lieu du code ; `SchoolDetailQuery#teachers` expose la voie. `test/db/growth_migrations_test.rb` : la nouvelle migration s'ajoute à `LATER`. |
| Delivery | `GET/POST /teacher-signup` (une seule voie) ; `GET /i/:token` (lien d'invitation) ; **retirés** : `GET /e/:code`, `GET/POST /teacher-signup/without-code`, `PATCH /school-admin/school/link` (« Changer le lien »). `PendingTeacherRegistrationsController` disparaît. L'écran d'attente (`PendingSchoolJoinsController`) reçoit DRENA → établissement. `/drenas/:drena_public_id/schools` inchangé. |
| UI | Formulaire réordonné (Établissement → Vous → Code secret), vérification en direct de la confirmation du code secret et nettoyage en direct du numéro (contrôleurs Stimulus, nouveaux), bandeau de l'établissement choisi par lien, alerte « lien plus valable ». Blocs de lien : « Inviter un collègue » (page et carte latérale), espace direction (sans code ni « Changer le lien »), fiche équipe (lien d'invitation à côté du code, qui reste pour la direction). Liste « Enseignants » de la fiche équipe : voie d'arrivée. Écran d'attente : DRENA → établissement au lieu du code. |

## 6. Décisions rattachées

- [ADR-0083](../../decisions/adr/0083-inscription-enseignant-en-deux-voies.md) *(Accepté)* — inscription enseignant en deux voies : liens d'invitation à jeton sans code d'établissement, voie d'arrivée enregistrée, nom complet saisi en un champ. Amende ADR-0037 (saisie seulement, stockage inchangé), ADR-0057 et ADR-0063 (côté enseignant), ADR-0071 (« Changer le lien »), ADR-0073 (plus de demande validée automatiquement).
- [UDR-0079](../../decisions/udr/0079-inscription-enseignant-en-deux-voies.md) *(Accepté)* — page d'inscription enseignant réordonnée, nom complet avec aperçu, bandeau du lien ; blocs de lien de l'enseignant, de la direction et de l'équipe ; voie dans la liste « Enseignants ». Remplace UDR-0044, amende UDR-0024, UDR-0050, UDR-0056.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Champs à remplir, inscription standard | 9 (DRENA ou code, établissement, matière, nom, prénoms, genre, numéro, PIN, confirmation) — voie code : 8 | 9 (DRENA, établissement, matière, nom, prénoms, genre, numéro, code secret, confirmation) — l'allègement vient de l'ordre et de la disparition du code (Q24) | |
| Champs à remplir, par lien | 8 | 7 (matière, nom, prénoms, genre, numéro, code secret, confirmation) | |
| Entrées d'inscription enseignant | 3 | 2 | |
