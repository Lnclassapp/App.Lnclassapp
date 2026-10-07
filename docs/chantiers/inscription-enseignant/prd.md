# PRD — Amélioration du parcours d'inscription des enseignants

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Un enseignant peut s'inscrire de trois façons (code d'établissement, choix manuel DRENA → établissement, lien d'un collègue) : le code est introuvable, le parcours confus, et la page demande trop. Ce chantier ne garde que **deux entrées** : l'**inscription standard** (DRENA → établissement → matière → nom complet, genre, contact → code secret) et le **lien d'invitation** (d'un collègue, de la direction ou de l'équipe), qui arrive avec l'établissement déjà choisi. La saisie du code d'établissement disparaît de l'inscription enseignant, le nom et les prénoms se saisissent en un seul champ, et chaque enseignant garde la voie par laquelle il est arrivé. Voir le [memo](memo.md), Q1 à Q15.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur (futur enseignant) | S'inscrire par la voie standard ; s'inscrire par un lien d'invitation valable, l'établissement déjà choisi ; quitter l'établissement du lien (« Ce n'est pas votre établissement ? ») pour la voie standard | Saisir un code d'établissement ; choisir un établissement en brouillon ou désactivé ; s'inscrire avec un numéro qui a déjà un compte |
| Teacher (connecté) | Copier et partager son lien « Inviter un collègue » (fermé sans établissement actif, comme aujourd'hui) | Ouvrir l'inscription ou un lien d'invitation : il est renvoyé vers son accueil (`GET`) ou reçoit 403 (`POST`) ; rejoindre un second établissement par un lien |
| SchoolStaff (direction) | Copier et partager le lien d'invitation de son établissement, sans code affiché | « Changer le lien » (retiré) |
| Team | Copier le lien d'invitation d'un établissement depuis sa fiche ; voir la voie d'arrivée d'un enseignant | — « Régénérer le code » reste, pour l'inscription de la direction, jusqu'au chantier `inscription-direction-sans-code` |
| Student, Parent | Rien ne change | — |

Règles d'autorisation : l'inscription est publique et refusée à toute personne connectée (règle existante de l'inscription). « Inviter un collègue » reste sous `InviteColleaguePolicy` ; le lien de la direction sous les règles de l'espace direction ; celui de l'équipe sous la gestion des établissements.

## 3. Parcours utilisateur

### Chemin nominal — inscription standard

1. Le visiteur ouvre `/teacher-signup` (page d'accueil « Je suis enseignant », ou application).
2. Rubrique **Établissement** : il choisit sa DRENA ; la liste de ses établissements actifs se charge ; il choisit son établissement, puis sa matière.
3. Rubrique **Vous** : il tape son nom complet (« KOUASSI Aya Marie ») ; l'aperçu affiche « Nom : KOUASSI · Prénom(s) : Aya Marie » ; il peut ouvrir « Corriger » pour éditer nom et prénoms séparément. Il choisit son genre et saisit son numéro.
4. Rubrique **Code secret** : PIN et confirmation.
5. « Créer mon compte » : le compte est créé, l'enseignant est **rattaché tout de suite** à l'établissement (école principale), sa voie d'arrivée est « standard », la session s'ouvre et il arrive sur « Quelles classes enseignez-vous ? » avec « Bienvenue ! ».

### Chemin nominal — lien d'invitation

1. Le visiteur ouvre le lien reçu (d'un collègue, de la direction ou de l'équipe).
2. La même page s'ouvre ; la rubrique Établissement montre l'établissement et sa DRENA déjà choisis (bandeau), avec « Ce n'est pas votre établissement ? ». Il choisit sa matière.
3. Rubriques Vous et Code secret comme ci-dessus.
4. « Créer mon compte » : rattaché à l'établissement du lien ; voie d'arrivée « lien d'un collègue » (avec le collègue, et le parrainage compté comme aujourd'hui), « lien de la direction » ou « lien de l'équipe ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Nom complet d'un seul mot | 422, sous le champ : « Saisissez votre nom et vos prénoms. » |
| Nom ou prénoms corrigés à la main | Les champs corrigés font foi ; le découpage automatique n'est pas réappliqué |
| Nom complet avec espaces multiples | Normalisé (`squish`) ; casse saisie gardée (ADR-0037) |
| Caractère interdit dans le nom (chiffre, symbole) | 422, message existant de nom invalide |
| Sans JavaScript | Pas d'aperçu en direct ; « Corriger » reste accessible ; le serveur découpe le nom complet |
| Numéro déjà inscrit | 422 « Ce numéro a déjà un compte Lnclass. » avec « Se connecter », sans révéler le rôle |
| DRENA non choisie, ou établissement absent de la DRENA, en brouillon ou désactivé | 422, message sous le champ ; aucun compte créé |
| Lien d'invitation inconnu, d'un établissement désactivé, ou d'un collègue retiré ou supprimé | La page standard s'ouvre avec l'alerte « Ce lien n'est plus valable. Choisissez votre établissement. » ; voie « standard » |
| « Ce n'est pas votre établissement ? » depuis un lien | La page standard s'ouvre sans établissement ; voie « standard » ; pas de parrainage |
| Personne connectée qui ouvre `/teacher-signup` ou un lien d'invitation | Renvoyée vers son accueil ; `POST` → 403 |
| Ancienne adresse `/e/<code>` | 404 (aucun lien partagé, memo Q11) |
| Plus de 5 envois par minute | 429 re-rendu dans le formulaire (règle existante) |

## 4. Critères d'acceptation

Formulés de manière vérifiable. Chacun devient un test. Identifiants `IE-NN`.

```gherkin
# IE-01 — inscription standard
Étant donné un établissement actif « Lycée Moderne de Cocody » de la DRENA « Abidjan 1 »
Quand un visiteur choisit cette DRENA, cet établissement, la matière « SVT »,
  tape « KOUASSI Aya Marie », choisit « Féminin », saisit un numéro libre et un code secret confirmé
Alors un compte enseignant est créé avec le nom « KOUASSI » et les prénoms « Aya Marie »
Et il est rattaché à cet établissement comme école principale, sans demande en attente
Et sa voie d'arrivée est « standard »
Et il arrive sur « Quelles classes enseignez-vous ? » avec « Bienvenue ! »

# IE-02 — plus de code d'établissement
Quand un visiteur ouvre /teacher-signup
Alors la page ne contient aucun champ « Code d'établissement »
Et les rubriques apparaissent dans l'ordre : Établissement, Vous, Code secret
Et /e/K7M-4QZ répond 404

# IE-03 — découpage du nom complet
Quand le nom complet « N'GUESSAN  Konan Jean-Baptiste » est envoyé sans correction
Alors le nom enregistré est « N'GUESSAN » et les prénoms « Konan Jean-Baptiste »

# IE-04 — correction du découpage
Quand le visiteur tape « KONÉ OUATTARA Awa » puis corrige : nom « KONÉ OUATTARA », prénoms « Awa »
Alors le nom enregistré est « KONÉ OUATTARA » et les prénoms « Awa »

# IE-05 — nom d'un seul mot
Quand le nom complet envoyé est « Kouassi »
Alors la page est re-rendue en 422 avec « Saisissez votre nom et vos prénoms. » sous le champ
Et aucun compte n'est créé

# IE-06 — lien d'un collègue
Étant donné un enseignant Awa rattaché au « Lycée Moderne de Cocody » et son lien « Inviter un collègue »
Quand un visiteur ouvre ce lien
Alors l'établissement et sa DRENA sont affichés, déjà choisis, sans code d'établissement
Et le lien ne contient pas le code de l'établissement
Quand il complète matière, nom complet, genre, numéro et code secret
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
Alors la page est re-rendue en 422 avec « Ce numéro a déjà un compte Lnclass. » et « Se connecter »
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
Quand l'équipe ouvre la fiche d'un enseignant
Alors elle lit sa voie d'arrivée (et le collègue, pour un lien d'un collègue)

# IE-16 — direction inchangée
Quand une direction s'inscrit par /school-staff-signup avec le code d'établissement
Alors son inscription fonctionne comme avant ce chantier
```

## 5. Modélisation préliminaire

*À compléter après l'exploration du code existant.*

## 6. Décisions rattachées

*À compléter.*

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Champs à remplir, inscription standard | 9 (DRENA ou code, établissement, matière, nom, prénoms, genre, numéro, PIN, confirmation) — voie code : 8 | 8 (DRENA, établissement, matière, nom complet, genre, numéro, PIN, confirmation) | |
| Champs à remplir, par lien | 8 | 6 (matière, nom complet, genre, numéro, PIN, confirmation) | |
| Entrées d'inscription enseignant | 3 | 2 | |
