# ADR-0086 : Coque Android « Lnclass Teacher » (enseignants) — même socle que l'app élèves, refus croisé, code Android partagé
<!-- index
titre: Coque Android « Lnclass Teacher » (enseignants) : même socle que l'app élèves, refus croisé, code Android partagé
statut: Proposé — *complète 0084 et 0070, amende 0084 §4.1, §4.3, §4.5 à §4.8*
problematique: Jeton `LnclassTeacherAndroid/` ; `/teachers/menu` ; règles de chemins des pages enseignant en modale ; refus dans les deux sens avec l'app proposée (`WRONG_APP_FOR`) ; même colonne `android_opened_at`, « dont app Android : N enseignants » ; `assetlinks.json` à deux apps ; modules `shell`, `student`, `teacher`. Chantier `app-android`.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-08 |
| **Chantier** | [`docs/chantiers/app-android`](../../chantiers/app-android/memo.md) (reprise « Lnclass Teacher » du 2026-10-08) |
| **Complète** | [ADR-0084](./0084-coque-android-eleves-hotwire-native.md) (coque élèves), [ADR-0070](./0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md) (deux apps) |
| **Amende** | ADR-0084 §4.1 (deux jetons), §4.3 (règles de plus), §4.5 (refus dans les deux sens, message selon le rôle), §4.6 (l'enseignant compté), §4.7 (deux identifiants), §4.8 (module `teacher`, code partagé) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'app élèves « Lnclass » est construite (ADR-0084, PR #205 et #206). Le porteur lance le 2026-10-08 l'app enseignants, « Lnclass Teacher », avec les mêmes principes : les pages du site dans une coque Hotwire Native, des barres natives, trois variantes (develop, recette, production). Ses réponses sont dans le [memo](../../chantiers/app-android/memo.md#reprise-du-2026-10-08--lnclass-teacher).

Il reste à dire ce qui change dans le socle posé pour les élèves :
- reconnaître une seconde coque ;
- refuser dans les deux sens, avec un message qui envoie chacun vers la bonne app ;
- servir des règles de chemins aux pages de l'enseignant ;
- compter l'enseignant ;
- déclarer deux apps dans `assetlinks.json` ;
- ne pas copier le code Kotlin de l'app élèves.

## 2. Moteurs de décision

- **Un seul site, deux coques** : aucune page n'est réécrite pour l'app (ADR-0070).
- **Pas de fuite du rôle** : le refus n'arrive qu'après un PIN correct (ADR-0084 §4.5).
- **Pas de migration de plus** : un compte n'a qu'un rôle, donc une seule colonne d'ouverture Android suffit.
- **Du code Android tenu une fois** : la barre du haut, l'avatar et le pont ne divergent pas entre les deux apps.

## 3. Options envisagées

| Option | Verdict |
|---|---|
| Copier le module `student` en `teacher` | Rejetée : deux copies de la barre du haut et du pont, qui dériveraient au premier correctif |
| **Un module de bibliothèque `shell` partagé, deux modules d'app minces** | **Retenue** |
| Une colonne `android_teacher_opened_at` | Rejetée : le rôle du compte dit déjà de quelle app vient l'ouverture |
| Deux fichiers de configuration des chemins | Rejetée : les règles ne se gênent pas (un enseignant n'ouvre jamais `/sessions/<id>` en élève) ; un seul fichier, servi et embarqué tel quel |

## 4. Décision

### 4.1 Reconnaissance

`ApplicationController::LNCLASS_APPS` gagne `"LnclassTeacherAndroid" => :android_teacher`. La coque enseignants ajoute `LnclassTeacherAndroid/<version>;` à son User-Agent, toujours après le marqueur « Hotwire Native ».

### 4.2 Pages dans la coque

Le shell (Lot B de l'ADR-0084) se comporte de même pour les deux coques : ni en-tête, ni barre latérale, ni barre basse. Il rend l'élément du pont `bridge--account` pour l'élève **et pour l'enseignant**, avec l'adresse de son panneau : `/students/menu` ou `/teachers/menu`.

### 4.3 Configuration des chemins (un fichier pour les deux apps)

`public/android/v1/path-configuration.json` gagne une règle :

```json
{"patterns": ["^/teachers/menu$", "^/classrooms/[^/]+/assignments/new$", "^/classrooms/[^/]+/session_days/edit$"],
 "properties": {"context": "modal", "pull_to_refresh_enabled": false}}
```

Onglets de l'app enseignants :
- **Accueil** : `/?source=android`, qui redirige vers `/teachers` ;
- **Classes** : `/teachers/classrooms` ;
- **Cours** : `/courses` ;
- **Annonces** : `/announcements`.

### 4.4 Panneau du compte de l'enseignant

`GET /teachers/menu` (route `teacher_menu`, `Classroom::TeacherMenusController#show`, enseignant seulement) rend le panneau du compte de l'enseignant, comme `/students/menu` pour l'élève (UDR-0082).

### 4.5 Refus dans les deux sens

- Le DTO de connexion accepte `client` dans `web`, `android_student`, `android_teacher`.
- Chaque coque n'admet qu'un rôle : `android_student` → `student`, `android_teacher` → `teacher`.
- Un autre rôle, PIN correct, reçoit `:conflict` avec `base: [:wrong_app]` et l'app à proposer, `app: [:android_teacher]`, `[:android_student]` ou `[:web]` (`Authenticate::WRONG_APP_FOR`). Aucune session ne s'ouvre ; la tentative compte comme réussie.
- Un PIN faux reste `:invalid`, identique pour tous.
- Le message (UDR-0082 §3.4) nomme l'app proposée. Son lien mène à la fiche Play Store de cette app si `ANDROID_STUDENT_STORE_URL` ou `ANDROID_TEACHER_STORE_URL` est posée, sinon au site.

### 4.6 Mesure

- `HomepageController` date `android_opened_at` quand `source=android` arrive de **l'une ou l'autre** coque reconnue.
- `TeamDashboardQuery#app_openers` gagne `android_teachers`, dans la même lecture groupée.
- La tuile affiche « dont app Android : N enseignants » sous la ligne des enseignants.
- L'espace direction ne montre rien pour l'instant : reporté à un chantier séparé (porteur, 2026-10-08).

### 4.7 Liens ouverts dans l'app

- `config.x.android` déclare deux apps :
  - `student` : `ANDROID_PACKAGE_NAME`, `com.lnclass.student` par défaut ;
  - `teacher` : `ANDROID_TEACHER_PACKAGE_NAME`, `com.lnclass.teacher` par défaut.
  
  Les empreintes `ANDROID_CERT_FINGERPRINTS` sont communes : une clé de test pour develop et recette, Play App Signing en production.
- `/.well-known/assetlinks.json` rend une déclaration par app.
- La coque enseignants déclare `/teacher-signup` et `/i/` avec vérification automatique. `/invitations/` reste au navigateur (ADR-0070 R2).

### 4.8 Le code Android

- `android/shell` : module de bibliothèque. Il contient :
  - le fragment web ;
  - la barre du haut avec titre, avatar et « Besoin d'aide ? » ;
  - le dessin de l'avatar ;
  - le composant de pont `account` ;
  - la configuration commune de Hotwire.
- `android/student` et `android/teacher` : modules d'app minces. Chacun porte :
  - son identifiant et son jeton User-Agent ;
  - ses onglets ;
  - ses icônes et ses couleurs : élèves `#00A0FF` ; enseignants `#FF8A00` pour l'écran de démarrage et `#C2410C` pour l'onglet actif, lisible sur fond blanc ;
  - ses liens profonds.
- Variantes : `develop`, `recette` et `production`, identifiant `com.lnclass.teacher` avec le suffixe `.develop` ou `.recette`.
- `bin/android-build [student|teacher] <variante> [dossier]` : `student` par défaut, donc `bin/android-build recette` garde son sens. Les fichiers produits s'appellent `lnclass-<variante>.apk` et `lnclass-teacher-<variante>.apk`.
- Aucune clé dans le dépôt.

## 5. Conséquences

- Les deux apps partagent un socle : un correctif de la barre du haut vaut pour les deux.
- Le message de refus de l'app élèves change pour l'enseignant (« Utilisez Lnclass Teacher »).
- Deux variables Railway de plus par environnement (`ANDROID_TEACHER_PACKAGE_NAME`, et plus tard les adresses du Play Store).
- Le garde `test/guards/android_project_test.rb` couvre les deux modules.

## 6. Comment vérifier que la décision est respectée

- Un élève au PIN correct, dans la coque enseignants : aucune session, message qui nomme « Lnclass ». Un enseignant dans la coque élèves : message qui nomme « Lnclass Teacher ». La direction dans l'une ou l'autre : renvoyée vers le site.
- `/.well-known/assetlinks.json` liste deux identifiants.
- `bin/android-build teacher recette` produit `com.lnclass.teacher.recette`, `minSdkVersion` 28, et son User-Agent porte `LnclassTeacherAndroid/`.
