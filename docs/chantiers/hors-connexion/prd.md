# PRD — Lnclass hors connexion

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Sans réseau, Lnclass n'affiche que « Pas de connexion ». L'élève doit pouvoir relire et refaire hors ligne les leçons et exercices déjà ouverts en ligne, avoir sa note tout de suite (provisoire) et voir ses copies partir seules au retour du réseau, sans doublon ni perte, à l'heure d'origine ; l'enseignant relit hors ligne ses pages déjà ouvertes. Le serveur reste juge de la note, de l'heure et des droits ([memo](memo.md), [menace](menace.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Relire hors ligne ses pages gardables déjà ouvertes (30 jours, 60 pages) ; recevoir le paquet de corrigé d'un exercice qu'il peut démarrer ; rendre hors ligne une copie d'un exercice dont il a le paquet ; envoyer ses copies en file | Recevoir le paquet d'un exercice qu'il ne peut pas démarrer ; envoyer une copie sous un autre compte ; faire compter une note qu'il a calculée ; rejouer une copie ; démarrer hors ligne un exercice jamais ouvert |
| Teacher | Relire hors ligne ses pages gardables déjà ouvertes (Lot E) ; voir qu'une copie a été rendue hors ligne | Écrire quoi que ce soit hors ligne ; recevoir un paquet de corrigé |
| Parent, SchoolStaff, Team | Rien de nouveau : leurs pages ne sont jamais gardées | — |

Règles : paquet = `Policies::Assessment::StartSessionPolicy` + accès `Billing` (comme `StartExerciseSession`) ; envoi = jeton signé du paquet (`student_id` = acteur) + mêmes règles rejouées à la réception ; pages = liste fermée `OfflineKeepable` (ADR §4.1).

## 3. Parcours utilisateur

### Chemin nominal (élève)

1. En ligne, l'élève ouvre une leçon et un exercice. Les deux pages sont gardées ; le paquet de corrigé de l'exercice est rangé sur le téléphone.
2. Plus tard, hors ligne, il rouvre la leçon : elle s'affiche, avec le bandeau « Hors ligne · gardée le … ».
3. Il ouvre l'exercice, touche « Commencer », remplit la copie, la rend : sa note s'affiche, étiquetée « Provisoire », avec le corrigé.
4. Le réseau revient ; à la page suivante, la copie part. L'accueil dit « Copie envoyée · 75 % » : la note du serveur remplace la provisoire.
5. Son enseignant voit la copie, « rendue hors ligne le … · reçue le … ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Page jamais ouverte, hors ligne | `offline.html`, qui dit que seules les pages déjà ouvertes restent lisibles |
| Exercice ouvert sans paquet (ouvert avant le chantier), hors ligne | « Commencer » désactivé, message « Ouvre cet exercice une fois avec du réseau… » |
| Copie envoyée deux fois | Une seule copie en base ; la seconde réponse dit `already_synced` |
| Exercice modifié entre-temps | `stale` : « Exercice modifié depuis : copie non comptée » |
| Accès bloqué, exercice dépublié, élève désactivé | Copie refusée, rien écrit ; `locked` reste en file, les autres sont montrées refusées |
| 4e copie d'affilée | Pause appliquée sur le téléphone ; au serveur `paused`, gardée en file |
| Un autre élève se connecte sur le téléphone | Les pages et paquets du premier sont purgés ; sa file reste, jamais envoyée sous le second |
| Déconnexion | La file part d'abord, puis tout est purgé |
| Stockage plein | « Copie non gardée : libère de la place… », réponses laissées dans le formulaire |
| Horloge du téléphone fausse | Heure ramenée dans la fenêtre [émission du paquet, réception] et 30 jours au plus |

## 4. Critères d'acceptation

```gherkin
# CA-1 — Pages gardables (Lot 0 / A)
Étant donné un élève connecté
Quand il ouvre une leçon, un sujet d'exercice ou son accueil
Alors la réponse porte l'en-tête « Lnclass-Offline: keep »
Et une page d'équipe, de facturation, de profil ou de PIN ne le porte jamais

# CA-2 — Clé d'appareil (Lot 0)
Étant donné deux élèves connectés tour à tour
Alors chaque page porte une meta « lnclass-offline-key » stable pour un compte, différente entre les deux
Et la clé ne contient pas l'identifiant du compte
Et une page sans connexion ne la porte pas

# CA-3 — Page gardée servie hors ligne (Lot A)
Étant donné une leçon ouverte en ligne par l'élève de clé K
Quand le réseau échoue sur une visite de cette leçon (navigation ou Turbo)
Alors la page gardée sous K est servie
Et une page sans « Lnclass-Offline: keep », en « no-store », redirigée ou non 200 n'est jamais gardée
Et une page de plus de 30 jours ou d'une autre clé n'est jamais servie
Et à la 61e page gardée, la plus ancienne sort

# CA-4 — Purge (Lot A)
Étant donné des pages et paquets gardés sous la clé K et une copie en file sous K
Quand une page porte une clé L différente
Alors les pages et paquets de K sont purgés et la file de K est gardée
Et quand l'élève se déconnecte, la réponse porte « Clear-Site-Data: "cache" »

# CA-5 — Paquet de corrigé (Lot B)
Étant donné un élève qui peut démarrer l'exercice E
Quand il demande le paquet de E
Alors il reçoit les questions avec bonnes réponses et explications, l'empreinte et un jeton signé
Et un visiteur, un enseignant, un élève d'un autre niveau, un exercice non publié ou un accès bloqué sont refusés
Et la réponse est « no-store »

# CA-6 — Correcteur JavaScript fidèle (Lot B)
Étant donné la table de cas partagée
Alors le correcteur Ruby et le correcteur JavaScript rendent le même verdict par case et la même note sur chaque cas

# CA-7 — Copie hors ligne (Lot B)
Étant donné un exercice dont le paquet est rangé, hors ligne
Quand l'élève rend sa copie
Alors la note s'affiche avec l'étiquette « Provisoire » et le corrigé
Et la copie est en file avec un identifiant unique, l'heure de début et de rendu de l'appareil, sans note envoyée

# CA-8 — Synchronisation nominale (Lot C)
Étant donné une copie en file valide
Quand elle est envoyée
Alors une copie terminée existe pour l'élève, notée par le serveur à partir des seules réponses
Et completed_at est l'heure d'origine et received_at l'heure de réception

# CA-9 — Rejeu (Lot C)
Quand la même copie est envoyée deux fois, ou deux fois en même temps
Alors une seule copie existe et la seconde réponse est « already_synced »

# CA-10 — Note falsifiée (Lot C)
Quand la charge porte une clé « score » ou « provisional_percent » à 100
Alors la note enregistrée est celle des réponses

# CA-11 — Mauvais propriétaire (Lot C)
Quand un élève envoie une copie dont le jeton a été émis pour un autre élève, ou un jeton altéré
Alors elle est refusée « wrong_owner » et rien n'est écrit

# CA-12 — Heure bornée (Lot C)
Quand l'heure d'origine est dans le futur, plus de 30 jours avant la réception ou avant l'émission du paquet
Alors elle est ramenée à la borne

# CA-13 — Droits rejoués (Lot C)
Quand l'accès est bloqué, l'exercice dépublié, ou la version changée à la réception
Alors la copie est refusée (« locked », « forbidden », « stale ») et rien n'est écrit

# CA-14 — Pause (Lot C)
Étant donné 3 copies terminées d'affilée de l'exercice
Quand une 4e copie hors ligne arrive
Alors elle est refusée « paused » et rien n'est écrit

# CA-15 — Copies à envoyer (Lot C)
Étant donné 2 copies en file
Alors l'accueil élève dit « 2 copies à envoyer » ; après envoi, « Copie envoyée · N % »

# CA-16 — Vue enseignant (Lot C)
Étant donné une copie rendue hors ligne
Quand l'enseignant de l'élève ouvre son résultat
Alors il lit « Rendue hors ligne le … · reçue le … »

# CA-17 — Enseignant hors ligne (Lot E)
Étant donné un enseignant connecté
Quand il ouvre son accueil, une classe, une fiche d'élève, un suivi d'assignation ou un résultat de copie
Alors la réponse porte « Lnclass-Offline: keep »
Et aucune page d'enseignant qui écrit (formulaires d'assignation, d'annonce, de classe) ne le porte
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `UseCases::Assessment::SyncOfflineCopy` ; `Entities::Assessment::OfflineCopyWindow` (bornes d'heure) ; port `ExerciseSessionRepositoryPort#record_offline_copy` et `#find_by_client_copy_id` ; port `Ports::Assessment::OfflinePackSignerPort` |
| Infrastructure | Migration `exercise_sessions.client_copy_id` (uuid) + `received_at` + index unique ; adaptateur `Adapters::Assessment::OfflinePackSigner` (MessageVerifier) ; `Queries::Assessment::OfflinePackQuery` |
| Delivery | `OfflineKeepable` ; `Assessment::OfflinePacksController#show` ; `Assessment::OfflineCopiesController#new/#create` ; routes ; `Clear-Site-Data` à la déconnexion ; meta de clé |
| UI | `service-worker.js` ; `app/javascript/offline/*` (store, page cache, grader, queue, sync, purge) ; contrôleurs `offline-status`, `offline-start`, `offline-copy`, `offline-queue` ; partials `shared/offline/*` ; `offline.html` |

## 6. Décisions rattachées

- ADR-XXXX-hors-connexion-pages-ouvertes-et-copies-synchronisees — amende ADR-0082 §4.2 et ADR-0119 §4
- UDR-XXXX-hors-connexion-bandeau-copie-provisoire-et-file — amende UDR-0078 §3.2

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Pages déjà ouvertes lisibles hors ligne (élève) | 0 % | 100 % des pages de la liste fermée, sous 30 jours | |
| Copies rendues hors ligne arrivées une seule fois | — | 100 % (hors refus motivés) | |
| Taille du programme d'arrière-plan | ~1 Kio | < 8 Kio | |
