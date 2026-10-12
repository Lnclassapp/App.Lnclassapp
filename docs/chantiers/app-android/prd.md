# PRD — App Android « Lnclass » pour les élèves

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
> Périmètre de cette PRD : **l'app élèves seule** (reprise du 2026-10-08). L'app enseignants « Lnclass Teacher » aura la sienne.

## 1. Contexte

Un élève ne trouve pas Lnclass sur le Play Store. Ce chantier livre « Lnclass », une coque Android en Hotwire Native qui affiche les pages du site avec des barres natives : onglets en bas, avatar et aide en haut. Il change aussi l'en-tête de l'élève sur le site : avatar à gauche ouvrant un panneau du compte, aide et thème à droite. Les décisions sont dans le [memo](memo.md), l'ADR-0070 (amendé), l'ADR-0084 et l'UDR-0080.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Installer l'app (APK de test, puis Play Store) ; se connecter, s'inscrire par code de classe ; tout ce qu'il fait sur le site ; ouvrir le panneau du compte (site et app) | Rien de plus que sur le site : aucune fonction réservée à l'app |
| Teacher, SchoolStaff, Team | Rien dans l'app : refusés après un PIN correct, renvoyés vers le site | Ouvrir une session dans l'app élèves |
| Team (pilotage) | Lire le nombre d'élèves qui ont ouvert l'app Android sur la période | — |
| Visiteur | Ouvrir l'app, voir la page de connexion ou d'inscription | — |

Règles d'autorisation : celles du site (policies, ADR-0028), inchangées. Le refus par rôle (`:wrong_app`) est un aiguillage du use case de connexion, pas une policy. `/students/menu` exige un élève connecté (contrôleur élève existant).

## 3. Parcours utilisateur

### Chemin nominal — app

1. Awa installe « Lnclass » (APK de test) ; l'icône baobab sur bleu apparaît.
2. Elle ouvre l'app : écran de démarrage, puis la page de connexion du site, sans en-tête.
3. Elle se connecte : son accueil s'affiche, avec la barre du haut native (son avatar à gauche, « Besoin d'aide ? » à droite) et trois onglets en bas.
4. Elle touche « Cours », ouvre une fiche, revient ; elle touche « Ma classe ».
5. Elle commence un exercice : la séance s'ouvre en plein écran, sans onglets ; elle répond ; le résultat revient dans l'onglet.
6. Elle touche son avatar : le panneau s'ouvre (nom, classe, thème, Profil, Cours, déconnexion).

### Chemin nominal — site (élève)

1. Sur son téléphone, dans le navigateur, l'en-tête montre son avatar à gauche, « Besoin d'aide ? » et l'interrupteur à droite, sans logo.
2. Toucher l'avatar ouvre le panneau depuis la gauche.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Un enseignant se connecte dans l'app, PIN correct | Aucune session ; message « Cette app est réservée aux élèves », lien vers le site |
| Un enseignant se trompe de PIN dans l'app | Même message d'échec qu'un élève qui se trompe |
| Pas de réseau à l'ouverture | Écran d'erreur natif avec « Réessayer » ; hors navigation, page « Pas de connexion » (ADR-0082) |
| Lien de classe reçu sur WhatsApp, app installée par le Play Store | Il s'ouvre dans l'app ; avec l'APK de test (non vérifié), dans le navigateur |
| Téléphone sous Android 9 | L'app ne s'installe pas ; l'élève reste sur le site, complet |
| Session expirée | La page de connexion du site s'affiche dans l'app |
| Pop-up « Installer Lnclass » | Jamais dans l'app |
| Enseignant, direction, équipe sur le site | En-tête inchangé |

## 4. Critères d'acceptation

```gherkin
# CA-1 — Le site reconnaît l'app
Étant donné une requête dont le User-Agent contient « Hotwire Native » et « LnclassStudentAndroid/1.0 »
Quand un élève connecté ouvre son accueil
Alors la page ne contient ni l'en-tête du shell ni sa barre basse
Et elle contient l'élément du pont `[data-controller="bridge--account"]` avec ses initiales et l'adresse « /students/menu »
Et elle ne contient pas la pop-up d'installation
Et la même page vue dans un navigateur contient l'en-tête et la barre basse, sans élément du pont

# CA-2 — Configuration des chemins
Quand on demande « /android/v1/path-configuration.json »
Alors la réponse est un JSON dont une règle ouvre « /sessions/<id> » en contexte « modal »
Et une règle ouvre « /students/menu » et « /aide » en contexte « modal »

# CA-3 — Enseignant refusé dans l'app
Étant donné un enseignant et son PIN correct
Quand il se connecte avec le User-Agent de l'app
Alors aucune session n'est ouverte
Et la page affiche « Cette app est réservée aux élèves » avec un lien vers le site
Et avec un PIN faux, le message est exactement celui d'un élève au PIN faux

# CA-4 — Élève accepté dans l'app
Étant donné un élève et son PIN correct
Quand il se connecte avec le User-Agent de l'app
Alors une session est ouverte et il arrive sur son accueil

# CA-5 — Ouverture de l'app comptée
Étant donné un élève connecté dans l'app
Quand l'app ouvre « /?source=android »
Alors son compte porte `android_opened_at` à l'heure du serveur et il arrive sur son accueil
Et « /?source=android » ouvert depuis un navigateur ne date rien

# CA-6 — Pilotage
Étant donné 2 élèves qui ont ouvert l'app Android sur la période et 1 avant
Quand l'équipe ouvre son pilotage
Alors la tuile « Ouvert depuis l'app installée » indique « dont app Android : 2 élèves »

# CA-7 — En-tête de l'élève sur le site
Étant donné un élève connecté dans un navigateur, à 390 px
Quand il ouvre son accueil
Alors l'en-tête montre son avatar à gauche, « Besoin d'aide ? » et l'interrupteur clair/sombre à droite
Et aucun logo dans l'en-tête
Et la page ne défile pas en largeur
Et un enseignant voit l'en-tête actuel, logo compris

# CA-8 — Panneau du compte
Étant donné un élève connecté dans un navigateur
Quand il touche son avatar
Alors un panneau s'ouvre depuis la gauche avec son nom, sa classe, l'interrupteur, « Profil », « Cours » et « Se déconnecter »
Et Échap le ferme
Et « /students/menu » rend le même contenu comme une page
Et un enseignant qui demande « /students/menu » est refusé

# CA-9 — Liens ouverts dans l'app
Quand on demande « /.well-known/assetlinks.json »
Alors la réponse est un JSON qui déclare « com.lnclass.student » et les empreintes configurées

# CA-10 — La coque
Étant donné le projet `android/`
Quand on compile la variante « recette »
Alors on obtient un APK `com.lnclass.student.recette`, `minSdkVersion` 28, qui charge « https://app-staging.lnclass.com »
Et son User-Agent contient « LnclassStudentAndroid/ »
Et ses trois onglets démarrent sur « /?source=android », « /courses » et « /students/classroom »
Et aucun fichier de clé de signature n'est versionné
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Authenticate` : `client` dans le DTO, échec `:wrong_app` après PIN correct ; `RecordAppOpen` : canal `:pwa` / `:android` ; port `UserRepositoryPort#mark_app_opened(user_id:, at:, channel:)` |
| Infrastructure | Migration `users.android_opened_at` ; repository (`mark_app_opened` par canal, anonymisation) ; `TeamDashboardQuery#app_openers` gagne `android_students` |
| Delivery | `ApplicationController#lnclass_app` ; `Identity::SessionsController` passe `client` ; `HomepageController` (`source=android`) ; `Classroom::StudentMenusController#show` ; route `/.well-known/assetlinks.json` ; fichier `public/android/v1/path-configuration.json` |
| UI | En-tête élève et `_account_panel` ; placement `:drawer` de `ui_modal` ; shell sans en-tête ni barre basse dans l'app ; contrôleur Stimulus `bridge--account` et dépendance `@hotwired/hotwire-native-bridge` ; message `:wrong_app` sur la page de connexion ; ligne « dont app Android » du pilotage |
| Android | Projet `android/`, module `student` : `MainActivity` (onglets), barre native et composant de pont `account`, configuration des chemins embarquée, variantes `recette` et `production`, icônes, liens `/c/` et `/join`, script `bin/android-build` |

## 6. Décisions rattachées

- [ADR-0070](../../decisions/adr/0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md), accepté et amendé le 2026-10-08 : app élèves d'abord, compte personnel, barres natives, Android 9.
- [ADR-0084](../../decisions/adr/0084-coque-android-eleves-hotwire-native.md), proposé : reconnaissance, pages dans la coque, configuration des chemins, aiguillage, mesure, code Android.
- [UDR-0080](../../decisions/udr/0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md), proposé : en-tête élève, panneau du compte, barres natives, message de refus.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Poids ajouté au JavaScript d'entrée (compressé) | — | ≤ 3 Ko (pont + contrôleur) | |
| Taille de l'APK de recette | — | ≤ 10 Mo | |
| Requêtes du pilotage | 17 / 20 | inchangé (même requête groupée) | |
