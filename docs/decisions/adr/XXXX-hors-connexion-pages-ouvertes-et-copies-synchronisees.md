# ADR-XXXX : Lnclass garde hors ligne les pages déjà ouvertes et synchronise les copies rendues sans réseau
<!-- index
titre: Hors connexion : pages ouvertes gardées, copies synchronisées
statut: Accepté
problematique: L'élève sans réseau ne peut ni relire une leçon déjà lue ni rendre une copie ; il faut garder des pages de compte et un corrigé sur le téléphone sans exposer un autre compte ni laisser falsifier une note.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-12 |
| **Chantier** | `docs/chantiers/hors-connexion` |
| **Remplace** | — *(amende ADR-0082 §4.2 et ADR-0119 §4, voir §4.7)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Depuis l'ADR-0082, le programme d'arrière-plan (*service worker*) ne garde sur le téléphone que la page « Pas de connexion ». Aucune page de compte n'y reste : c'était le prix de la simplicité et de la sécurité d'un appareil partagé. La note d'une copie est calculée **uniquement sur le serveur** (`SubmitExerciseCopy`, `CloseExerciseSession`, `Grading`), et aucune page ne porte la bonne réponse (ADR-0119 §4).

Le porteur veut le hors connexion total : l'élève relit hors ligne ce qu'il a déjà ouvert, rend des copies, voit sa note tout de suite ; ses copies partent au retour du réseau, sans doublon, sans perte, avec l'heure d'origine. Le corrigé est gardé sur le téléphone et peut être lu par l'élève (risque accepté). L'enseignant relit ses classes hors ligne. Rien n'est téléchargé d'avance. Menace : [`menace.md`](../../chantiers/hors-connexion/menace.md).

Trois faits du code pèsent : une visite Turbo est un `fetch`, pas une navigation, et l'ADR-0082 ne l'intercepte pas ; le cookie de session vit 30 jours d'inactivité ; l'enseignant n'a aujourd'hui **rien à écrire** sur une copie (ADR-0115, option E), donc aucun conflit de synchronisation côté enseignant.

## 2. Moteurs de décision

1. **Le serveur reste la référence** : une note, une heure, un droit ne sont jamais crus sur parole.
2. **Aucune fuite entre comptes** sur un appareil partagé.
3. **Sans perte ni doublon** : une copie rendue hors ligne arrive une fois, ou l'élève sait pourquoi elle n'est pas arrivée.
4. **Zéro dépendance** (pas de Workbox), Safari compris, l'app Android en profite sans code natif.
5. Le moins de surface serveur possible : une colonne plutôt qu'une table, un jeton signé plutôt qu'un registre.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pages gardées par le programme sur liste fermée côté serveur + paquet de corrigé signé + file de copies en IndexedDB + recorrection au serveur | Le serveur décide ce qui est gardé ; la note locale n'a aucun poids ; un seul chemin d'écriture serveur | **Retenue** |
| B — Application monopage hors ligne (rendu client des leçons et copies depuis du JSON) | Contrôle total du rendu | Réécrit en JavaScript toutes les vues ERB des leçons et de la copie (UDR-0138) : deux rendus à tenir, des semaines de travail |
| C — Garder tout le HTML visité, sans liste | Trivial à écrire | Garde aussi PIN, facturation, profils, pages d'équipe : contraire à l'ADR-0031 et à la menace P6 |
| D — Correction hors ligne sans corrigé local (note « en attente » jusqu'au retour) | Aucun corrigé sur l'appareil | Contraire à la décision du porteur (« correction comprise ») |
| E — Enregistrer chaque ouverture de paquet en base pour borner l'heure | Trace exacte | Une table et une écriture par ouverture d'exercice ; un jeton signé porte la même information sans écrire |

## 4. Décision

> **Nous gardons sur le téléphone, par compte et pour 30 jours, les seules pages qu'une liste fermée côté serveur marque comme gardables et que le compte a déjà ouvertes ; nous servons à l'élève un paquet de corrigé signé par exercice ouvert ; nous corrigeons hors ligne en JavaScript pour une note provisoire ; nous envoyons les copies au retour du réseau, et le serveur, seul juge, rejoue droits et correction et garde l'heure d'origine bornée.**

### 4.1 Pages gardables : décidé par le serveur

- Concern `OfflineKeepable` (`app/controllers/concerns/offline_keepable.rb`) : `keep_offline only: %i[show]` pose l'en-tête de réponse `Lnclass-Offline: keep` sur une réponse 200 HTML d'un compte connecté. Aucune autre action ne le pose.
- **Liste fermée** — élève (Lot A) : leçon (`catalog/courses#show`), sujet d'exercice (`assessment/exercises#show`), copie hors ligne (`assessment/offline_copies#new`, §4.4), accueil élève. Enseignant (Lot E) : accueil enseignant, page de classe, fiche d'un élève, suivi d'une assignation, résultat d'une copie. Le test `keepable_pages_test.rb` liste les actions qui posent l'en-tête et échoue si la liste change sans lui.
- Jamais : équipe, direction, parent, facturation, identité (connexion, PIN, second facteur, profil), toute réponse `secret_response` (ADR-0031), toute réponse `no-store`.

### 4.2 Clé d'appareil et purge

- Chaque page d'un compte connecté porte `<meta name="lnclass-offline-key" content="…">` : les 16 premiers caractères hexadécimaux de `HMAC-SHA256(secret_key_base dérivée « offline-key », user_id)`. Opaque, stable, différente entre comptes. Absente sans connexion.
- Le JavaScript de page (`app/javascript/offline/`) range la clé courante. **Clé différente** de la précédente → purge du cache de pages et de la base de l'ancienne clé, **sauf sa file de copies non envoyées** (gardée 30 jours, jamais envoyée sous une autre clé).
- **Déconnexion** : le JavaScript envoie la file (§4.5), puis purge les caches `lnclass-pages-<clé>` et la base `lnclass-offline-<clé>`, puis envoie `{ type: "lnclass:forget", key }` au programme (même si la purge échoue : il remet sa clé à null, efface la clé rangée, supprime `lnclass-pages-<clé>` et retient la clé comme oubliée), puis laisse partir la déconnexion. Filet si le JavaScript n'a pas tourné (cookie expiré, session révoquée) : toute réponse HTML d'un visiteur non connecté porte `Lnclass-Offline: forget` (`OfflineKeepable`) et le programme applique la même purge ; sans clé courante, il ne sert que `/offline.html`. `Clear-Site-Data: "cache"` reste posé sur `destroy` mais ne vide pas le Cache Storage : ce n'est pas le filet. On n'envoie pas `"storage"` : il désinscrirait le programme et effacerait les files d'autres comptes.
- Toute page gardée et tout paquet expirent à **30 jours** (alignés sur `SessionLifetime`).

### 4.3 Programme d'arrière-plan (amende ADR-0082 §4.2)

`app/views/pwa/service-worker.js`, toujours sans dépendance :

- Caches : `lnclass-offline-v<N>` (page « Pas de connexion », inchangé), `lnclass-assets-v<N>` (assets digérés `/assets/*`, gardés à la première demande, cache d'abord : leur nom porte l'empreinte), `lnclass-pages-<clé>` (pages de compte).
- `fetch`, `GET` même origine qui demande du HTML (navigation **ou** visite Turbo, en-tête `Accept` contenant `text/html`) : **réseau d'abord**. Réponse 200, non redirigée, avec `Lnclass-Offline: keep`, sans `no-store` → gardée sous la clé courante (reçue de la page par `postMessage`), avec son heure. Réseau en échec → page gardée sous la clé courante de moins de 30 jours, sinon `/offline.html`.
- Au plus **60 pages** par clé : à l'ajout de la 61e, la plus ancienne sort.
- `navigator.storage.persist()` est demandé une fois, à la première page gardée ; un refus ne change rien.
- Les formulaires, `POST`, Action Cable et images `no-store` ne sont jamais interceptés.

### 4.4 Copie hors ligne et paquet de corrigé (amende ADR-0119 §4)

- `GET /exercises/:public_id/offline_pack` (`Assessment::OfflinePacksController#show`, JSON, `no-store`) : élève connecté seulement ; même autorisation que le démarrage (`StartSessionPolicy`, publication, niveau, accès `Billing`). Rend les questions **avec** leurs bonnes réponses et explications, l'empreinte de version (16 hex du SHA-256 du JSON canonique des questions) et un **jeton signé** (`ActiveSupport::MessageVerifier`, but `offline_pack`) qui porte `student_id`, `exercise_id`, `digest`, `issued_at`. Limite 30 par minute. Chargé par le sujet d'exercice ouvert en ligne, rangé dans la base locale de la clé.
- `GET /exercises/:public_id/offline_copy` (`Assessment::OfflineCopiesController#new`, gardable) : la copie sur feuille (UDR-0138) rendue **sans** session ni bonne réponse, formulaire marqué `data-offline-copy`. Hors ligne, « Commencer » mène ici quand le paquet existe.
- **Correcteur JavaScript** `app/javascript/offline/grader.js` : rejoue `Question#correct?` et `Grading.points_percent` pour les types notés (`true_false`, `single_choice`, `multiple_correct_2/3`, `fill_blank`, `numeric`, `ordering`, `matching`, `select`) ; `written` et `notebook` jamais notés. **Table de cas partagée** `test/fixtures/files/offline/grading_cases.json`, jouée par `test/domain/entities/assessment/offline_grading_parity_test.rb` (Ruby) et `test/javascript/offline/grader.test.js` (Node) : un écart casse la CI.
- La note locale est affichée **« provisoire »** jusqu'à la réponse du serveur.

### 4.5 File et synchronisation

- Base IndexedDB `lnclass-offline-<clé>`, magasins `packs` (clé `exercise_public_id`) et `copies` (clé `client_copy_id`). Une copie en file : `{ client_copy_id (UUID v4), exercise_public_id, pack_token, started_at, submitted_at, answers, provisional_percent, status: pending|synced|rejected, reason }`.
- Envoi : à l'ouverture de toute page en ligne, à l'événement `online`, et avant la déconnexion. `POST /offline_copies` (`Assessment::OfflineCopiesController#create`, JSON, `X-CSRF-Token`), 20 copies au plus par envoi, corps borné à 256 Kio, limite 30 par minute.
- Use case **`UseCases::Assessment::SyncOfflineCopy`** (une copie par appel) : vérifie le jeton (signature, `student_id` = acteur, `exercise_id`) ; `digest` ≠ version courante → `:stale` ; rejoue `StartSessionPolicy` et l'accès `Billing` **à l'heure de réception** → `:forbidden` / `:locked` ; règle `RestartPause` → `:paused` ; valide les réponses par `CopyInput` / `AttemptInput` ; **recorrige** et crée une session `completed` avec ses tentatives, dans une transaction. Une note envoyée par le client n'est jamais lue.
- **Idempotence** : colonne `exercise_sessions.client_copy_id` (`uuid`, nulle) et index unique `(student_id, client_copy_id)` ; un second envoi rend `:already_synced` avec la copie existante.
- **Heure d'origine bornée** : `started_at` et `completed_at` = heures de l'appareil ramenées dans `[issued_at du jeton, heure de réception]` et jamais plus de 30 jours avant la réception. Colonne `exercise_sessions.received_at` (`datetime`, nulle) : l'heure de réception, non nulle ⇔ copie rendue hors ligne.
- Réponse par copie : `synced` (note du serveur, lien du résultat), `already_synced`, ou `rejected` avec motif (`stale`, `forbidden`, `locked`, `paused`, `invalid`, `wrong_owner`). Une copie `paused` ou `locked` reste `pending` ; les autres refus passent `rejected`, gardées 30 jours et montrées à l'élève.

### 4.6 Enseignant

Lecture seule, Lot E : ses pages de la liste §4.1, mêmes règles de clé, purge et durée. Aucune écriture hors ligne, aucune file. Il voit sur le résultat d'une copie la mention « rendue hors ligne · reçue le … » quand `received_at` n'est pas nul.

### 4.7 Amendements

- **ADR-0082 §4.2** : « une réponse du réseau n'est jamais mise en cache » ne vaut plus que pour les réponses sans `Lnclass-Offline: keep`. La page « Pas de connexion » reste un fichier statique sans données.
- **ADR-0119 §4** : « jamais `correct` dans la page » reste vrai pour toute page HTML. Seul le paquet JSON hors ligne d'un exercice (pas d'un entraînement de notion, suite possible) porte le corrigé, à l'élève autorisé.

## 5. Conséquences

### 🟢 Positives

- L'élève révise et s'entraîne hors ligne sur ce qu'il a ouvert ; sa note s'affiche tout de suite.
- Aucune note ni heure n'est crue sans contrôle : falsifier la base locale ne change rien au serveur.
- L'app Android en profite sans ligne de Kotlin, si son WebView exécute le programme (à vérifier au Lot A).

### 🔴 Coûts consentis

- **Le corrigé est lisible par l'élève** pour tout exercice ouvert (décision du porteur) : la note faite hors ligne vaut entraînement ; l'enseignant voit qu'une copie a été rendue hors ligne.
- **Deux correcteurs** à tenir alignés (Ruby, JavaScript) ; la table de cas partagée est le seul garde-fou.
- Des pages de compte restent jusqu'à 30 jours sur un téléphone non déconnecté.
- L'heure d'origine peut être fausse dans sa fenêtre bornée.
- Un exercice modifié entre l'ouverture et l'envoi perd la copie (`:stale`), montrée « non comptée ».
- Safari peut tout effacer après 7 jours sans visite (hors app installée) : des copies non envoyées peuvent disparaître sur iPhone.
- Un programme d'arrière-plan plus gros : un bug y casse toute navigation. D'où réseau d'abord, toujours.

## 6. Notes d'implémentation

```ruby
# app/controllers/concerns/offline_keepable.rb
module OfflineKeepable
  extend ActiveSupport::Concern
  class_methods do
    def keep_offline(**options) = after_action(:mark_offline_keepable, **options)
  end
  private
  def mark_offline_keepable
    return unless authenticated? && response.status == 200 && response.media_type == "text/html"
    response.set_header("Lnclass-Offline", "keep")
  end
end
```

```js
// app/views/pwa/service-worker.js (extrait)
const keepable = (response) => response.ok && !response.redirected &&
  response.headers.get("Lnclass-Offline") === "keep" && !/no-store/.test(response.headers.get("Cache-Control") || "")
```

## 7. Comment vérifier que la décision est respectée

- `test/integration/offline/keepable_pages_test.rb` : la liste des actions qui posent `Lnclass-Offline` est exactement celle du §4.1 ; une page d'équipe, de facturation ou `secret_response` ne la pose pas.
- `test/javascript/offline/page_cache.test.js` : sans en-tête, `no-store`, 302, 500 → rien gardé ; 61e page → la plus ancienne sort ; 31 jours → purgée ; clé différente → rien servi.
- `test/domain/use_cases/assessment/sync_offline_copy_test.rb` : jeton d'un autre élève, `score` ignoré, rejeu, heures bornées, accès bloqué, exercice modifié.
- `offline_grading_parity_test.rb` et `grader.test.js` jouent la même table de cas.
- `test/integration/offline/logout_purge_test.rb` : `Clear-Site-Data: "cache"` à la déconnexion ; `Lnclass-Offline: forget` pour un visiteur non connecté.
