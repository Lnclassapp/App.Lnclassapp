# ADR-XXXX : Lnclass télécharge sur l'appareil installé tout le catalogue auquel l'élève a droit et synchronise les écritures de l'enseignant
<!-- index
titre: Hors connexion total : catalogue téléchargé, écritures enseignant synchronisées
statut: Accepté
problematique: Après l'installation, l'élève hors ligne ne lit que les pages déjà ouvertes et l'enseignant ne peut rien faire ; il faut télécharger d'avance un catalogue de plus de 100 Mo sans fuite entre comptes ni contournement de l'abonnement, et rejouer au serveur les écritures faites hors ligne.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-22 |
| **Chantier** | `docs/chantiers/hors-connexion-total` |
| **Remplace** | — *(amende ADR-0133 §1, §4.3, §4.4, §4.5, §4.6 et ADR-0119 §4, voir §4.8)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0133 garde sur le téléphone les seules pages déjà ouvertes, par compte, et ne télécharge rien d'avance. Le porteur veut désormais le hors-ligne total après l'installation (décisions du 2026-11-22, [memo](../../chantiers/hors-connexion-total/memo.md)) :

- tout le catalogue auquel le compte a droit, son niveau d'abord ;
- les images des leçons ;
- l'entraînement de notion corrigé sur l'appareil ;
- pour l'enseignant, les pages déjà ouvertes, et trois écritures hors ligne.

Faits du code qui pèsent :

- le catalogue fait 463 leçons et 98 Mo de JSON source, sans les images ;
- la page de leçon d'un élève porte sa progression (`passed/size`) ;
- les images de question sont servies `private, max-age=3600` une fois publiées, et `no-store` sinon ;
- aucune version d'exercice n'est gardée : l'empreinte est calculée à la volée, d'où le refus `stale` ;
- chaque remise de paquet de corrigé est enregistrée (`offline_pack_deliveries`) ;
- l'accès Billing ne porte une date stockée que pour l'abonnement (`subscribed_until`), et les jours gratuits se calculent.

Menace : [`menace.md`](../../chantiers/hors-connexion-total/menace.md).

## 2. Moteurs de décision

1. **Le serveur reste la référence** : droit, note, version et heure sont rejugés à la réception (inchangé).
2. **Pas de payant sans droit**, ni téléchargé ni affiché, y compris sur un appareil partagé.
3. **Un téléchargement par appareil**, pas par compte : un téléphone partagé ne retélécharge pas 100 Mo.
4. **Réseau d'abord pour toute page HTML** : le cache ne sert qu'en cas d'échec du réseau.
5. **Zéro nouvelle vue à double rendu** : les pages restent les vues ERB existantes (ADR-0133 option B toujours écartée).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Liste du catalogue par compte servie par le serveur ; pages communes rendues neutres et gardées une fois par appareil ; filtre d'affichage par la liste du compte connecté ; jetons de corrigé en lot ; versions d'exercice gardées 30 jours ; file d'actions de l'enseignant rejouée par les use cases existants | Un téléchargement par appareil ; aucune vue réécrite ; le serveur garde la main sur tout ce qui compte | **Retenue** |
| B — Télécharger les pages de compte, sous la clé de chaque compte | Aucune page neutre à rendre, purge simple | 100 Mo et plus à retélécharger à chaque changement de compte, contraire à la réponse Q5 du porteur |
| C — Paquet JSON du catalogue et rendu client | Fichier unique, compressible | Réécrit toutes les vues des leçons en JavaScript (ADR-0133, option B) |
| D — Chiffrer les pages communes par compte | Le payant illisible même avec les outils du navigateur | Un chiffrement par compte veut dire un téléchargement par compte (retour à B) ; la clé serait de toute façon sur l'appareil |
| E — Garder le refus `stale` | Pas de nouvelle table | Le téléchargement d'avance multiplie les copies faites sur une version dépassée ; contraire à la réponse Q6 |
| F — Enseignant : télécharger d'avance ses classes | Hors-ligne total aussi pour lui | Données de mineurs sur le téléphone ; refusé par le porteur (Q7) |

## 4. Décision

> **Nous servons à chaque élève une liste du catalogue filtrée par son accès, son niveau d'abord, avec sa date de fin d'accès. Les pages communes sont rendues neutres, gardées une fois par appareil et affichées seulement au compte connecté qui les a dans sa liste. Nous livrons les corrigés en lot. Nous gardons 30 jours chaque version d'exercice servie, pour corriger une copie sur la version reçue. Les écritures de l'enseignant sont rejouées au serveur par leurs use cases, une seule fois chacune.**

### 4.1 Liste du catalogue (élève)

- `GET /offline/catalog` (`Catalog::OfflineCatalogsController#show`, JSON, `no-store`, élève connecté seulement, 10 par minute). Query `Queries::Catalog::OfflineCatalogQuery` derrière le port `Ports::Catalog::OfflineCatalogPort`, une requête pour les leçons, une pour les exercices, une pour les images.
- Réponse :

  ```json
  {
    "key": "<clé d'appareil>",
    "level": "3e",
    "access_ends_on": "2026-11-30",
    "entries": [
      { "course": "<slug>", "level": "3e", "priority": 0, "paid": true,
        "version": "<16 hex>", "bytes": 182000,
        "urls": [ "…" ], "images": [ "…" ], "exercises": [ "<public_id>" ] }
    ]
  }
  ```

  - `priority` vaut 0 pour le niveau de l'élève, et 1 pour le reste.
  - `version` est l'empreinte du contenu de la leçon, exercices compris.
  - `bytes` est une estimation : la taille HTML de la dernière rendue, ou à défaut la taille du JSON source fois 1,5.
- **Filtre d'accès** : `StudentAccessPort` à l'heure de la demande. `blocked?` ⇒ seulement les leçons gratuites. Sinon tout ce qui est publié.
- **`access_ends_on`** : nouvelle méthode `Entities::Billing::Access#ends_on`. Elle vaut `subscribed_until` pour un abonné, la fin des jours gratuits pour l'essai, et `BETA_ENDS_ON` pour la bêta.
- **Gratuit ou payant** : la règle existante de l'accès ne distingue pas encore les leçons. Une leçon est `paid: true` dès que l'ouvrir exige un accès non bloqué. Le Lot 0 fige cette règle dans la query et la teste.

### 4.2 Pages communes (rendu neutre)

- Une demande qui porte l'en-tête `Lnclass-Offline-Fetch: catalog` (posé seulement par le programme d'arrière-plan) obtient, pour la leçon (`catalog/courses#show`), le sujet (`assessment/exercises#show`), la copie hors ligne (`assessment/offline_copies#new`) et l'entraînement de notion, un **rendu neutre**. Ce rendu a :
  - la coque sans nom, avatar, menu de compte ni clé d'appareil ;
  - aucune progression, note ni `passed`, ni proposition de remédiation ;
  - l'en-tête de réponse `Lnclass-Offline: catalog`.
  
  Le concern `OfflineKeepable` gagne `keep_offline_catalog only: …`. Les vues lisent `offline_neutral?` pour taire les parties de compte.
- Le compte est toujours exigé, et l'accès rejoué : un rendu neutre n'est pas une page publique.
- Le test `neutral_pages_test.rb` rend chaque page neutre pour un élève nommé, avec une note et un `passed`. Il échoue si son nom, sa note ou sa clé apparaît.

### 4.3 Programme d'arrière-plan (amende ADR-0133 §4.3)

- **Nouveaux caches**, non purgés à la déconnexion :
  - `lnclass-catalog-v1` : pages communes, clé = URL, avec `X-Lnclass-Version` ;
  - `lnclass-media-v1` : images de question publiées, `private, max-age` sans `no-store`, et seulement si l'URL figure dans une liste.
- **Liste par compte**, rangée dans `lnclass-state-v1` sous `/__lnclass/catalog/<clé>`. Elle contient l'ensemble des URL autorisées et `access_ends_on`.
- **Lecture hors ligne d'une page HTML** (réseau en échec), dans cet ordre :
  1. la page de compte gardée (`lnclass-pages-<clé>`, ADR-0133) ;
  2. sinon, la page commune, si l'URL est dans la liste de la clé courante et, pour une entrée `paid`, si `access_ends_on` n'est pas passé. Une entrée `paid` dont la date est passée donne une page statique `/offline-access-ended.html` ;
  3. sinon `/offline.html`.
  
  Sans clé courante, on ne sert que `/offline.html`.
- **Téléchargement** : piloté par la page (`offline-download`, Stimulus), pas par le programme. La page n'a pas d'API d'arrière-plan fiable sur Safari.
  - La page demande les URL de la liste avec `Lnclass-Offline-Fetch: catalog`, 2 à la fois au plus.
  - Un 429 ou un 503 fait attendre 1 s, puis le double à chaque refus, jusqu'à 60 s.
  - Le programme range chaque réponse `Lnclass-Offline: catalog` dans `lnclass-catalog-v1`.
  - Ce qui est déjà gardé à la même version ne repart pas.
  - Avant de commencer, on vérifie la place avec `navigator.storage.estimate()`.
  - Le réseau se lit avec `navigator.connection.type` ; s'il est absent, on le traite comme « données mobiles ».
- **Purge au retour du réseau** : la page relit la liste, puis envoie `{ type: "lnclass:catalog", key, list }`.
  - Le programme supprime de `lnclass-catalog-v1` et `lnclass-media-v1` toute URL absente de **toutes** les listes rangées sur l'appareil.
  - Une liste de plus de 30 jours est ignorée et supprimée.
  - À la déconnexion, `lnclass:forget` supprime aussi la liste de la clé, puis applique la même purge.
- Les pages communes ne sont **jamais** servies quand le réseau répond (moteur 4).

### 4.4 Corrigés en lot (amende ADR-0133 §4.4)

- `POST /offline/packs` (`Assessment::OfflinePacksController#create`, JSON, `no-store`, 30 par minute, 200 exercices au plus) : corps `{ exercises: [public_id…] }`. Use case `UseCases::Assessment::IssueOfflinePacks`, qui rejoue exercice par exercice ce que fait `show` aujourd'hui :
  - `StartSessionPolicy`, la publication et l'accès Billing ;
  - l'enregistrement de la remise (`offline_pack_deliveries`) ;
  - le jeton signé.
  
  Il rend `{ public_id: { digest, issued_at, token, questions } }` ; un refus rend `{ public_id: { refused: motif } }`.
- Les paquets restent rangés **par clé**, dans la base `lnclass-offline-<clé>` : ils sont purgés à la déconnexion et retéléchargés à la connexion suivante, ce qui fait quelques Mo de JSON.
- **Coût consenti** : la marque « corrigé reçu » (ADR-0133 §4.4) devient vraie pour presque toute copie d'un élève qui a téléchargé son niveau. Elle reste vraie, et l'enseignant lit qu'elle a changé de sens (UDR).

### 4.5 Versions d'exercice (amende ADR-0133 §4.5)

- Table `exercise_versions` : `exercise_id`, `digest` (16 hex), `questions` (jsonb, le `payload` du paquet), `first_served_at`, `superseded_at` (nulle). Index unique `(exercise_id, digest)`.
  - Elle est écrite par `IssueOfflinePacks` et par `show` à la première remise d'un digest (insert sans conflit).
  - `superseded_at` est posé à la première remise d'un digest nouveau.
  - Port `Ports::Assessment::ExerciseVersionRepositoryPort` (`record`, `find(exercise_id:, digest:)`, `purge_before(time)`).
- `SyncOfflineCopy` : si le digest du jeton diffère du digest courant, il lit la version gardée.
  - Elle existe et `superseded_at` date de 30 jours au plus avant la réception : la copie est corrigée sur ces questions et comptée.
  - Sinon : refus `:version_expired`, qui remplace `:stale`.
- Job quotidien : supprime les versions remplacées depuis plus de 35 jours.

### 4.6 Entraînement de notion (amende ADR-0119 §4)

- La page commune de l'entraînement porte, dans un `<script type="application/json" data-offline-practice>`, les questions **avec** leurs réponses attendues. Ce bloc n'existe **que** dans le rendu neutre, jamais dans une page servie à la navigation.
- Hors ligne, `grader.js` (étendu aux types de l'entraînement, même table de cas `grading_cases.json`) corrige. **Rien n'est envoyé** : l'entraînement reste sans trace (ADR-0119).
- En ligne, l'entraînement reste corrigé par le serveur (`CheckPractice`), sans changement.

### 4.7 Enseignant (amende ADR-0133 §4.6)

- **Lecture** : `keep_offline` sur l'accueil enseignant, la page de classe, la fiche d'un élève, le suivi d'un devoir et le résultat d'une copie. Rien n'est téléchargé d'avance.
- **Écritures**, file IndexedDB `actions` dans `lnclass-offline-<clé>` : `{ client_action_id (UUID v4), kind, payload, made_at, status, reason }`. Les types possibles :
  - `assign` (payload de `AssignmentInput`) ;
  - `assign_batch` (`AssignExerciseBatch`, 10 exercices au plus) ;
  - `archive` (`public_id`) ;
  - `session_days` (`SessionDaysInput`).
- `POST /offline/actions` (`Classroom::OfflineActionsController#create`, JSON, enseignant, `X-CSRF-Token`, 30 par minute, 20 actions au plus, 64 Kio au plus). Use case `UseCases::Classroom::SyncOfflineAction`, une action par appel, dans une transaction :
  1. il lit le reçu `(user_id, client_action_id)` ; s'il existe, il rend le résultat rangé (`already_synced`) ;
  2. il construit le DTO et appelle le use case existant avec l'acteur de la session ;
  3. il écrit le reçu (port `Ports::Shared::OfflineActionReceiptPort`, table `offline_action_receipts`, index unique).
  
  Les refus du use case rendent `rejected` avec leur motif. Ils sont gardés 30 jours dans la file et montrés à l'enseignant.
- `made_at` est ramené dans `[réception − 30 jours, réception]`. Un devoir créé ainsi porte `assignments.made_offline_at` et `assignments.received_at`, qui ne sont posées que par `SyncOfflineAction`.
- Ordre : la file part dans l'ordre de `made_at`. Pour les jours de cours, le dernier envoyé gagne : les jours appartiennent à un seul enseignant, donc il n'y a pas de conflit entre collègues.
- Hors ligne, « Retirer de la classe » et « Changer le lien » sont désactivés.

### 4.8 Amendements

- **ADR-0133 §1** (« rien n'est téléchargé d'avance ») : vrai pour l'enseignant seulement.
- **ADR-0133 §4.3** : ajoute deux caches communs et la liste par compte (§4.3 ci-dessus). Les 60 pages par clé restent pour les pages de compte.
- **ADR-0133 §4.5** : `:stale` est remplacé par la correction sur la version gardée, et par `:version_expired` au-delà de 30 jours.
- **ADR-0133 §4.6** : l'enseignant n'est plus en lecture seule. Il a quatre types d'écriture et une file.
- **ADR-0119 §4** : une page HTML peut porter les réponses d'un entraînement, mais seulement le rendu neutre demandé par le programme d'arrière-plan.

## 5. Conséquences

### 🟢 Positives

- Après l'installation, toute leçon à laquelle l'élève a droit se lit hors ligne, même jamais ouverte.
- Un téléphone partagé ne télécharge le catalogue qu'une fois.
- Une copie faite sur une version dépassée compte, si cette version a été remplacée depuis 30 jours au plus.
- L'enseignant donne ses devoirs sans réseau.

### 🔴 Coûts consentis

- **Le payant gardé est lisible avec les outils du navigateur** par un autre compte de l'appareil : le filtre est d'affichage (menace T1).
- **Un appareil jamais reconnecté et dont on recule l'horloge garde le payant lisible** (T2).
- Plus de 100 Mo par appareil, plus les images, pour qui télécharge tout. Safari peut effacer les données d'un site non installé.
- Deux rendus par page de leçon : le normal et le neutre. Le test `neutral_pages_test.rb` est le seul garde-fou.
- La marque « corrigé reçu » perd de sa finesse (§4.4).
- Une nouvelle table de versions, qui garde jusqu'à 35 jours les questions remplacées.
- Le pic de téléchargement le jour d'un lancement (T8) : 2 demandes à la fois par appareil, et attente qui double après un refus.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/billing/access.rb (ajout)
def ends_on = subscribed_until&.to_date || (free? ? today + days_left : nil) || (beta? ? Offer::BETA_ENDS_ON : nil)
```

```js
// app/views/pwa/service-worker.js (extrait)
const servableFromCatalog = (list, url, now) =>
  list && list.urls.has(url) && (!list.paid.has(url) || !list.accessEndsOn || now <= list.accessEndsOn)
```

## 7. Comment vérifier que la décision est respectée

- `test/integration/offline/catalog_list_test.rb` : CA-1 à CA-3.
- `test/integration/offline/neutral_pages_test.rb` : CA-4 (aucun nom, aucune note, aucune clé, l'en-tête `catalog`).
- `test/javascript/offline/page_cache.test.js` (étendu) :
  - CA-8 à CA-12 ;
  - une page commune n'est jamais servie quand le réseau répond ;
  - sans clé, seule `/offline.html` est servie.
- `test/javascript/offline/download.test.js` : CA-5 à CA-7.
- `test/domain/use_cases/assessment/issue_offline_packs_test.rb` : CA-13.
- `test/domain/use_cases/assessment/sync_offline_copy_test.rb` (amendé) : CA-14 à CA-16.
- `offline_grading_parity_test.rb` et `grader.test.js` (étendus aux types de l'entraînement) : CA-17.
- `test/integration/offline/media_test.rb` : CA-18.
- `test/integration/offline/keepable_pages_test.rb` (étendu) : CA-19.
- `test/domain/use_cases/classroom/sync_offline_action_test.rb` : CA-20 à CA-22, CA-25.
- `test/javascript/offline/actions.test.js` : CA-23.
- `test/system/offline/teacher_offline_test.rb` : CA-24.
