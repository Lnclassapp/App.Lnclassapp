# ADR-0084 : Coque Android « Lnclass » (élèves) — Hotwire Native, barres natives, chemins servis par le site, aiguillage par rôle à la connexion

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-08 |
| **Chantier** | [`docs/chantiers/app-android`](../../chantiers/app-android/memo.md) |
| **Complète** | [ADR-0070](./0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md) (décision des deux apps, amendée le 2026-10-08) |
| **Amende** | ADR-0070 R3 (la mesure passe par le compte, pas par la session) · [ADR-0082](./0082-application-installable-sans-page-de-compte-sur-le-telephone.md) §4.3 et §4.4 (une ouverture « app Android » à côté de l'ouverture PWA) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0070 décide deux apps Android en Hotwire Native, qui affichent les pages du site. Son amendement du 2026-10-08 fixe l'ordre et la forme :
- l'app élèves d'abord ;
- un compte Google Play personnel ;
- des barres natives : l'app cache l'en-tête et la barre basse du site, et affiche ses propres onglets et sa propre barre du haut.

Il reste à décider, avant le code :
- comment le serveur reconnaît l'app ;
- ce qu'il change aux pages quand elles sont vues dans l'app ;
- comment l'app sait quelles adresses ouvrir en plein écran ;
- comment un enseignant est refusé à la connexion ;
- comment l'équipe compte les élèves qui utilisent l'app ;
- où vit le code Android.

Deux faits mesurés le 2026-10-08 :
- **Hotwire Native Android 1.3.x exige l'API 28 (Android 9)**, et non Android 7 comme supposé pendant le cadrage. Son `minSdk` vaut 28 dans les fichiers Gradle de `core` et de `navigation-fragments`.
- **turbo-rails 2.0.23** fournit déjà `hotwire_native_app?` : il reconnaît « Hotwire Native » dans le User-Agent.

L'ADR-0070 R3 prévoyait une colonne d'origine sur la table `sessions`. Or une session est supprimée à la déconnexion et à l'expiration. L'ADR-0082 a écarté cette voie pour la même raison (option E).

## 2. Moteurs de décision

1. **Le site reste la référence** (ADR-0070) : aucune page n'est réécrite en natif.
2. **Une seule source de vérité pour la navigation** : ce que l'app ouvre en plein écran ou en modale se décide sur le serveur, sans republier l'app.
3. **Aucune donnée de compte dans la coque** : la coque ne stocke que le cookie de session, comme un navigateur.
4. **Poids** (ADR-0051) : l'ajout au JavaScript d'entrée du site reste minimal.
5. **Le refus par rôle est un aiguillage, pas une barrière** (ADR-0070 R1).

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — **Hotwire Native, barres natives, configuration des chemins servie par le site** | Pages du site ; onglets et barre du haut natifs ; règles changées sans republier | Deux surfaces de navigation à tenir (site et app) |
| B — Coque WebView simple (pages du site avec leur en-tête) | Le plus rapide | Écarté par le porteur (« affichage natif ») |
| C — Trusted Web Activity (la PWA dans le Play Store) | Aucun code natif | Pas de barre native, aucun contrôle de la navigation |

## 4. Décision

> **Nous construisons la coque « Lnclass » avec Hotwire Native Android 1.3.x, Android 9 minimum. Le site reconnaît la coque à un jeton de son User-Agent, lui sert ses pages sans en-tête ni barre basse, et lui sert aussi la configuration de ses chemins. Le refus par rôle se fait dans le use case de connexion, après un PIN correct.**

### 4.1 Reconnaissance de la coque

- La coque ajoute à son User-Agent le jeton **`LnclassStudentAndroid/<version>`**, en plus de « Hotwire Native » (ajouté par la bibliothèque).
- `ApplicationController` expose `lnclass_app` → `:android_student`, ou `nil` hors de la coque. Il reprend `hotwire_native_app?` de turbo-rails et l'accompagne d'une aide de vue `lnclass_app?`.
- Le jeton se falsifie. Rien de ce qu'il commande n'est une permission : il ne change que l'affichage, l'aiguillage R1 et la mesure.

### 4.2 Pages vues dans la coque

- Le shell (`layouts/shell`) ne rend **ni l'en-tête ni la barre basse** quand `lnclass_app?`. La barre latérale `lg+` ne s'affiche de toute façon jamais sur un téléphone.
- Le contenu garde son espacement, sans la marge réservée à la barre basse.
- La pop-up d'installation (UDR-0078) n'est jamais rendue dans la coque.
- Le titre de la barre native est le `<title>` de la page. Il reste lisible, puisque `document_title` existe déjà (UDR-0054).
- La coque ajoute deux boutons natifs à sa barre du haut : l'avatar à gauche, « Besoin d'aide ? » à droite.
  - Ces boutons sont des **composants de pont** (`@hotwired/hotwire-native-bridge`, nouvelle dépendance JavaScript, environ 2 Ko compressés).
  - La page les déclare par un élément `data-controller="bridge--account"`. Cet élément porte les initiales, l'adresse de la photo et l'adresse du panneau du compte.
  - Le shell ne le rend que dans la coque, pour un élève.
  - Hors de la coque, le contrôleur Stimulus du pont ne fait rien.

### 4.3 Configuration des chemins

- Le site sert `GET /android/v1/path-configuration.json`. C'est un fichier statique versionné avec le code Rails, sous `public/android/v1/`.
- La coque en embarque une copie, pour démarrer hors ligne, puis charge la version du site.
- Règles :
  - toutes les adresses s'ouvrent dans l'onglet courant (contexte `default`) ;
  - `/sessions/<id>`, la séance d'exercice, s'ouvre en **modale plein écran** (contexte `modal`) : la barre d'onglets est cachée pendant l'exercice, et la croix native ferme ;
  - le résultat (`/sessions/<id>/result`) revient dans l'onglet ;
  - `/students/menu`, le panneau du compte, et `/aide` s'ouvrent en modale ;
  - les adresses hors du site s'ouvrent dans le navigateur.
- Le versionnement du chemin (`v1`) permet de changer de format sans casser les coques déjà installées.

### 4.4 Onglets natifs

Trois onglets, avec leurs adresses de départ :
- **Accueil** : `/?source=android`, qui redirige vers `/students` (voir §4.6) ;
- **Cours** : `/courses` ;
- **Ma classe** : `/students/classroom`.

Les icônes sont celles du site (Heroicons `home`, `book-open`, `academic-cap`), exportées en vecteurs Android. Chaque onglet garde sa pile de pages. Le chargement est paresseux (Hotwire Native 1.3).

### 4.5 Aiguillage par rôle (ADR-0070 R1)

- Le DTO de connexion reçoit `client` : `"web"` ou `"android_student"`, déduit de §4.1 par le contrôleur.
- `UseCases::Identity::Authenticate` vérifie le PIN, **puis** compare le rôle à `client`. Un compte qui n'est pas élève, dans la coque élèves, reçoit le refus `wrong_app` **sans qu'aucune session ne s'ouvre**. La tentative est comptée comme réussie : le PIN était juste. Les codes de `Shared::Result` forment une liste fermée (ADR-0026) : le refus est un `:conflict` dont l'erreur est `base: [:wrong_app]` (`Authenticate::WRONG_APP`), sur le modèle de `DrawingReaderPort`.
- Un PIN faux suit le chemin actuel (`:invalid`), le même pour tous les rôles : le refus ne révèle jamais le rôle d'un numéro.
- Le message nomme la situation : « Cette app est réservée aux élèves. Enseignants : continuez sur lnclass.com. » Le lien s'ouvre dans le navigateur.

### 4.6 Mesure (amende ADR-0070 R3 et ADR-0082 §4.3, §4.4)

- Colonne `users.android_opened_at` (`datetime`, nulle), sœur de `app_opened_at`.
- Le port `UserRepositoryPort#mark_app_opened(user_id:, at:)` devient `mark_app_opened(user_id:, at:, channel:)`, avec `channel` dans `:pwa` ou `:android`.
- `RecordAppOpen` reçoit le canal. `HomepageController` date l'ouverture quand `source=android` arrive d'une coque reconnue (§4.1), puis redirige vers l'accueil comme aujourd'hui.
- L'anonymisation efface aussi cette colonne.
- La tuile « Ouvert depuis l'app installée » du pilotage gagne une ligne « dont app Android : N élèves » (une requête groupée, inchangée en nombre).
- La colonne d'origine sur `sessions` de l'ADR-0070 n'est **pas** créée.

### 4.7 Liens ouverts dans l'app (ADR-0070 R2)

- Le site sert `GET /.well-known/assetlinks.json` : l'identifiant `com.lnclass.student` et les empreintes SHA-256 des certificats autorisés, lues dans `config.x.android` (une variable d'environnement par environnement).
- La coque déclare les chemins `/c/` et `/join` avec vérification automatique.
- Sans vérification (APK de test hors Play Store), ces liens s'ouvrent dans le navigateur. Le parcours reste complet.

### 4.8 Le code Android

- Projet Gradle dans **`android/`** à la racine du dépôt : un module d'app `student` aujourd'hui, `teacher` demain. Kotlin, `minSdk 28`, `targetSdk` imposé par le Play Store au moment de la publication.
- Deux variantes de compilation :
  - **`recette`** : `https://app-staging.lnclass.com`, nom affiché « Lnclass (recette) » ;
  - **`production`** : `https://lnclass.com`.
- Identifiant : `com.lnclass.student`, avec le suffixe `.recette` pour la variante de recette, pour que les deux coexistent sur un téléphone.
- Les icônes validées le 2026-10-08 (`lnclass-eleves-icones-android.zip`) vont dans `android/student/src/main/res`.
- **Aucune clé de signature dans le dépôt.**
  - L'APK de test est signé par une clé d'envoi gardée par le porteur.
  - La publication passe par Play App Signing.
- La CI Rails ignore `android/`. Une tâche `bin/android-build` compile l'APK de recette en local.

## 5. Conséquences

### 🟢 Positives

- Une page du site qui change apparaît dans l'app sans nouvelle publication. Les règles de navigation (modale, plein écran) changent aussi sans republier.
- Le refus d'un enseignant ne révèle aucun rôle et n'ouvre aucune session.
- La mesure survit aux déconnexions, comme celle de la PWA.
- Un seul dépôt : le code Rails et la coque évoluent ensemble.

### 🔴 Coûts consentis

- **Android 7 et 8 sont exclus de l'app** (Hotwire Native exige Android 9) ; ces élèves restent sur le site.
- Une dépendance JavaScript de plus (`@hotwired/hotwire-native-bridge`), chargée par toutes les pages pour un usage limité à la coque.
- Deux navigations à tenir : celle du site (UDR-0006 et UDR-0080) et celle de l'app (onglets natifs).
- Le jeton du User-Agent se falsifie : un navigateur peut se faire passer pour l'app. Il ne gagne ni permission ni donnée, seulement un affichage sans en-tête.
- Le compte Play Store personnel impose un test fermé de 14 jours avec 12 testeurs avant la publication ouverte.
- Le Play Store relève régulièrement le `targetSdk` exigé : la coque demande une mise à jour au moins une fois par an, même si rien ne change.

## 6. Notes d'implémentation

```ruby
# app/controllers/application_controller.rb — ajout
LNCLASS_APPS = { "LnclassStudentAndroid" => :android_student }.freeze

def lnclass_app
  return unless hotwire_native_app?

  LNCLASS_APPS.find { |token, _| request.user_agent.to_s.include?("#{token}/") }&.last
end
helper_method :lnclass_app

def lnclass_app? = lnclass_app.present?
helper_method :lnclass_app?
```

```json
// public/android/v1/path-configuration.json (extrait)
{
  "settings": {},
  "rules": [
    { "patterns": [".*"], "properties": { "context": "default", "uri": "hotwire://fragment/web", "pull_to_refresh_enabled": true } },
    { "patterns": ["^/sessions/[^/]+$"], "properties": { "context": "modal", "pull_to_refresh_enabled": false } },
    { "patterns": ["^/students/menu$", "^/aide$"], "properties": { "context": "modal", "pull_to_refresh_enabled": false } }
  ]
}
```

## 7. Comment vérifier que la décision est respectée

- Test d'intégration : avec le User-Agent de la coque, une page élève ne contient ni l'en-tête ni la barre basse du shell, mais contient `[data-controller="bridge--account"]`. Avec un User-Agent de navigateur, c'est l'inverse.
- Test de use case : un enseignant avec un PIN correct et `client: "android_student"` reçoit le refus `WRONG_APP`, et aucune session n'est créée. Avec un PIN faux, il reçoit exactement l'échec d'un élève avec un PIN faux.
- Test d'intégration : `GET /android/v1/path-configuration.json` et `GET /.well-known/assetlinks.json` répondent 200, en JSON, avec les règles du §4.3 et l'identifiant du §4.7.
- Test : `/?source=android` venu de la coque date `android_opened_at`. Venu d'un navigateur, il ne date rien.
- `grep -rn "keystore\|\.jks" android/` ne trouve aucun fichier de clé versionné.
- Une compilation `bin/android-build recette` produit un APK, dont le `minSdkVersion` vaut 28.
