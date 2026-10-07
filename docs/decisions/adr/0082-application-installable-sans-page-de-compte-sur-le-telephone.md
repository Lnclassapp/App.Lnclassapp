# ADR-0082 : Application installable — les pages passent toujours par le réseau, seule la page « Pas de connexion » est gardée sur le téléphone, l'ouverture depuis l'icône est notée sur le compte

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-07 |
| **Chantier** | [`docs/chantiers/installation-pwa`](../../chantiers/installation-pwa/memo.md) |
| **Amende** | [ADR-0070](./0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md) (la PWA ne reste plus au backlog) · [ADR-0062](./0062-indicateurs-de-pilotage-lus-en-direct.md) (un indicateur de plus) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le site n'est pas installable. La fiche d'application (manifeste) est celle du générateur Rails : nom « AppLnclassapp », couleur `red`, une seule icône. Elle n'est déclarée dans aucune page, ses routes ne sont pas montées, et le programme d'arrière-plan (*service worker*) est entièrement commenté (TR-24). L'ancienne application avait un bandeau d'installation qui enregistrait « installée » sur iPhone sans rien installer et acceptait n'importe quelle valeur du client (ID-26, TR-25). La feuille de route prévoyait deux colonnes sur `users` pour ce bandeau.

Le porteur a avancé le chantier le 2026-10-07, avant les apps Android de l'ADR-0070. Il a aussi voulu des exercices hors ligne. Le grill les a sortis vers un chantier distinct, `eleve-hors-ligne`, car ils touchent la correction de l'ADR-0054. Il reste à décider ce que le programme d'arrière-plan garde sur le téléphone, ce qu'il ne garde jamais, et comment l'équipe sait si l'installation prend, sans traceur (ADR-0049).

## 2. Moteurs de décision

1. **Téléphone partagé** : le frère d'Awa ne doit rien retrouver d'elle dans le stockage du navigateur.
2. **Aucun HTML en cache** (ADR-0076 §4.1) : une page de compte n'est jamais resservie.
3. **CSP stricte, aucun tiers** (ADR-0049) : ni bibliothèque de *service worker*, ni script en ligne, ni traceur.
4. **Budget de poids** (ADR-0051) : le public paie ses données, sur des Android d'entrée de gamme.
5. **Le site reste la référence** (ADR-0070) : aucune fonction propre à l'app installée.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Pas de programme d'arrière-plan, manifeste seul | Le plus simple | Chrome Android exige un programme qui répond aux navigations pour proposer l'installation ; sans réseau, erreur du navigateur |
| B — **Réseau seul pour les pages, page « Pas de connexion » gardée** | Installable ; rien de personnel sur le téléphone ; quelques dizaines de lignes, sans dépendance | Aucune lecture hors ligne |
| C — Garder les pages vues (réseau d'abord, cache ensuite) | Relire hors ligne | Garde le HTML des comptes sur un téléphone partagé ; contredit l'ADR-0076 ; renvoyé à `eleve-hors-ligne`, qui aura son propre ADR |
| D — Bibliothèque Workbox | Stratégies prêtes | Dépendance de plus, poids ; inutile pour une seule page gardée |

Pour l'indicateur :

| Option | Pour | Contre |
|---|---|---|
| E — Marque sur la session de connexion (`sessions`) | Lien direct avec la connexion | Les sessions sont supprimées à la déconnexion et à l'expiration : la mesure de la période se perd |
| F — **Heure de la dernière ouverture depuis l'icône sur le compte** (`users.app_opened_at`) | Une colonne, une écriture, comptable sur toute période qui finit aujourd'hui | Ne dit pas combien de fois ni sur quel appareil |
| G — Mesure dans le navigateur (`display-mode`) envoyée au serveur | Plus précise | Requête de mesure côté client : interdite sans nouvel ADR (ADR-0049) |

## 4. Décision

> **Nous rendons le site installable avec un manifeste réécrit et un programme d'arrière-plan sans dépendance qui laisse toutes les requêtes au réseau et ne garde sur le téléphone que la page « Pas de connexion », sa feuille de style et le logo. Nous notons l'ouverture depuis l'icône sur le compte, par l'adresse de départ propre à l'app.**

### 4.1 Manifeste

Servi par `Rails::PwaController` (`GET /manifest.json`, route `pwa_manifest`), déclaré par `<link rel="manifest">` dans `layouts/application` :

| Clé | Valeur |
|---|---|
| `name`, `short_name` | `Lnclass` |
| `lang` | `fr` |
| `description` | « Cours, exercices et suivi des classes. » |
| `start_url` | `/?source=app` |
| `scope`, `id` | `/` |
| `display` | `standalone` |
| `theme_color` | `#00a0ff` (bleu de marque, une seule couleur, quel que soit le rôle) |
| `background_color` | `#ffffff` |
| `icons` | `/icon-192.png` (192), `/icon.png` (512), `/icon-maskable.png` (512, `purpose: maskable`, logo dans la zone sûre de 80 %) |

Les icônes sont des fichiers de `public/`, générés depuis le logo officiel (`app/assets/images/logo/lnclass.jpeg`).

### 4.2 Programme d'arrière-plan

Servi par `Rails::PwaController` (`GET /service-worker.js`, route `pwa_service_worker`) avec l'en-tête par défaut de Rails pour une réponse dynamique (`max-age=0, private, must-revalidate`), qui vaut `no-cache` ici : une nouvelle version est prise à la visite suivante. Le navigateur revalide de toute façon le script principal d'un programme d'arrière-plan sans passer par son cache HTTP. Enregistré à la portée `/` par le JavaScript d'entrée, seulement si `navigator.serviceWorker` existe.

- **`install`** : ouvre le cache `lnclass-offline-v<N>` et y met **exactement** `/offline.html`, `/offline.css` et `/icon-192.png`. Puis `skipWaiting()`.
- **`activate`** : supprime tout cache dont le nom n'est pas le cache courant. Puis `clients.claim()`.
- **`fetch`** : ne traite que les requêtes de **navigation** (`request.mode === "navigate"`) en `GET`. Il les passe au réseau ; si le réseau échoue (exception de `fetch`), il répond `/offline.html` depuis le cache. **Une réponse du réseau n'est jamais mise en cache.** Toute autre requête (formulaires, Turbo, ressources, Action Cable) n'est pas interceptée.
- Aucun `push`, aucune synchronisation en arrière-plan (chantiers `notifications-push` et `eleve-hors-ligne`).
- `<N>` est un entier écrit dans le fichier. On l'augmente à chaque modification de la page « Pas de connexion » ou de sa feuille.

La page « Pas de connexion » est un fichier **statique** de `public/` : elle ne contient aucune donnée de compte, ne charge aucun script et lie sa propre feuille `/offline.css`. Elle ne dépend donc ni de la feuille de l'application, dont le nom porte une empreinte, ni de la CSP par nonce.

### 4.3 Ouverture depuis l'icône

- Colonne `users.app_opened_at` (`datetime`, nulle, sans index : on ne la lit qu'agrégée, dans la requête du pilotage).
- Port `Ports::Identity::UserRepositoryPort#mark_app_opened(user_id:, at:)` → `true`.
- Use case `UseCases::Identity::RecordAppOpen(actor:)` : pose `app_opened_at` à l'heure du serveur (horloge injectée). Policy `Policies::Identity::RecordAppOpenPolicy` (ADR-0028, une policy par use case ; corrigé à l'exécution, la première version disait « aucune policy propre ») : seuls un élève ou un enseignant connectés marquent leur propre compte, les seuls rôles que compte le pilotage ; tout autre acteur est refusé sans rien écrire, sans erreur. Une erreur d'écriture n'empêche jamais la redirection vers l'accueil : elle est signalée (`Rails.error`), pas avalée en silence.
- `HomepageController#index` l'appelle quand `params[:source] == "app"` et qu'un compte est connecté, puis redirige vers l'accueil comme aujourd'hui. Toute autre valeur de `source` est ignorée.
- `AnonymizeUser` remet `app_opened_at` à `NULL` (ADR-0036 : on ne garde pas de trace d'usage d'un compte anonymisé).

### 4.4 Indicateur du pilotage (amende l'ADR-0062)

`Queries::School::TeamDashboardQuery` gagne `app_openers` : le nombre de comptes **non anonymisés** dont `app_opened_at` tombe dans la période (`@since..`), par rôle `student` et `teacher`. Une seule requête de plus (`GROUP BY role`), dans le même cache que les autres flux.

### 4.5 Bandeau d'installation

**Aucune donnée serveur.** Le choix « Plus tard » vit dans le `localStorage` du navigateur, lu et écrit sous `try/catch`. Les colonnes `users.install_banner_status` et `users.install_banner_last_changed_at` de la feuille de route **ne sont pas créées**, ni la route `PATCH /install_banner`. « Installée » n'est jamais enregistré : le bandeau se cache quand la page tourne en mode `standalone` ou après l'événement `appinstalled`. Rendu : [UDR-0078](../udr/0078-bandeau-d-installation-et-page-pas-de-connexion.md).

### 4.6 Amendement de l'ADR-0070

La phrase « La PWA (`installation-pwa`, V4) et l'app iOS restent au backlog » ne vaut plus pour la PWA, livrée par ce chantier. Les apps Android restent en attente. Sur Android, Chrome laisse sans conflit une PWA installée cohabiter avec une app du Play Store.

## 5. Conséquences

### 🟢 Positives

- Lnclass s'installe sur Android et iPhone, sans magasin ni compte développeur, et les écrans restent ceux du site.
- Sans réseau, une page Lnclass explique la situation au lieu de l'erreur du navigateur.
- Rien de personnel n'est gardé sur le téléphone : le moteur 1 tient sur un téléphone partagé.
- Aucune dépendance, aucune requête de mesure côté client, aucun cookie de plus.

### 🔴 Coûts consentis

- **Aucune lecture hors ligne** : un élève sans réseau ne relit ni son accueil ni ses leçons. C'est l'objet de `eleve-hors-ligne`, qui devra amender cet ADR (§4.2) pour garder des données sur le téléphone.
- **L'indicateur est grossier** : la dernière ouverture seulement, ni fréquence ni appareil. Un compte ouvert depuis l'icône hors de la période n'est pas compté, même s'il a l'app. Un Android qui reprend l'app en mémoire sans recharger l'adresse de départ n'est pas compté.
- **`source=app` se falsifie** : n'importe qui peut taper `/?source=app` et se compter. L'indicateur sert à suivre une tendance, jamais à décider pour un compte.
- **iPhone** : pas de bouton d'installation possible, et Safari peut effacer le stockage du site, ce qui fait réapparaître le bandeau.
- **Changer l'icône ou le nom** met plusieurs jours à atteindre les écrans d'accueil (rafraîchissement du manifeste décidé par le navigateur).
- **Un programme d'arrière-plan défectueux reste actif** jusqu'à la version suivante : le fichier est revalidé à chaque visite et ne garde aucune page, ce qui limite le risque à la page « Pas de connexion ».

## 6. Notes d'implémentation

```javascript
// ⚡ FRONT · pwa/service-worker — réseau seul pour les pages ; seule la page « Pas de connexion » est gardée
// Rôle : installe la page hors ligne, purge les anciennes versions, répond hors ligne aux seules navigations
// ADR  : 0082, 0049, 0076
const CACHE = "lnclass-offline-v1"
const OFFLINE_FILES = ["/offline.html", "/offline.css", "/icon-192.png"]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(OFFLINE_FILES)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET" || request.mode !== "navigate") return

  event.respondWith(fetch(request).catch(() => caches.match("/offline.html")))
})
```

## 7. Comment vérifier que la décision est respectée

- Test d'intégration : `GET /manifest.json` rend le JSON du §4.1 ; `GET /service-worker.js` rend un `Cache-Control` qui exige la revalidation (`no-cache`, ou `max-age=0` et `must-revalidate`).
- Test : la constante `OFFLINE_FILES` du programme ne contient que les trois chemins du §4.2, et le fichier ne contient pas `cache.put`.
- Test système (Chrome) : programme actif, réseau coupé, navigation vers l'accueil → « Pas de connexion » ; le contenu de `caches` se limite à `OFFLINE_FILES`.
- `grep -rn "install_banner" app db` ne trouve rien.
- Test de use case : `RecordAppOpen` pose `app_opened_at` à l'heure de l'horloge injectée ; test de contrôleur : `/?source=app` sans compte connecté n'écrit rien.
- Test de query : un compte anonymisé et une ouverture antérieure à la période ne sont pas comptés.

## 8. Remplace, complète, amende

- **Amende** l'ADR-0070 (§4.6) et l'ADR-0062 (§4.4).
- **Complète** l'ADR-0049 (aucune mesure côté client), l'ADR-0051 (poids) et l'ADR-0076 (aucun HTML en cache, y compris dans le programme d'arrière-plan).
- **Corrige** la feuille de route de `refonte-application` : la migration `AddInstallBannerStatusToUsers` et la route `PATCH /install_banner` sont abandonnées (ID-26, TR-25).
- Sera amendé par l'ADR de `eleve-hors-ligne`.
