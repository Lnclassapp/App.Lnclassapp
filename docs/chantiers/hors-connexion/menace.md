# Menace — hors connexion (copies et corrigés gardés sur le téléphone)

> Écrite avant tout code (contrat de session, CLAUDE.md « Menace écrite d'abord »). Trois surfaces nouvelles :
> **des pages de compte gardées sur l'appareil** (fin de la règle « aucune page de compte sur le téléphone » de l'ADR-0082),
> **le corrigé des exercices ouverts gardé sur l'appareil** (décision du porteur : lisible par l'élève, accepté),
> **des copies rédigées hors ligne et envoyées plus tard** (lues par le serveur comme une entrée hostile).
> Chaque ligne « Preuve » nomme le test du lot qui la ferme. Les lots la reprennent telle quelle.

## Qui attaque, et ce qu'il gagne

- **Un autre élève sur le même téléphone** (frère, sœur, camarade : appareil partagé, cas courant). Il veut lire les
  copies, les notes ou les pages d'un autre, ou rendre une copie sous son nom.
- **L'élève lui-même.** Il veut une meilleure note : falsifier la note locale, la date de rendu, rejouer une copie,
  rendre une copie pour un exercice qu'il n'a jamais ouvert ou auquel il n'a pas droit.
- **Un enseignant qui prête son téléphone.** Ses pages de classe portent les noms et notes de dizaines d'élèves mineurs.
- **Un script tiers** (extension, page piégée) : il n'a pas accès à l'origine Lnclass ; on ne l'élargit pas (aucune donnée
  hors de l'origine, aucune CORS ouverte).

## A. Données personnelles gardées sur un appareil partagé

| # | Attaque | Ce qui l'arrête | Preuve |
|---|---|---|---|
| P1 | **Lire les pages d'un autre compte** après sa déconnexion | La déconnexion vide tout ce que Lnclass garde sur l'appareil : réponse `Clear-Site-Data: "cache"` **et** purge par le JavaScript (caches `lnclass-pages-*`, base `lnclass-offline-*`) avant l'envoi de la déconnexion. Les copies non envoyées sont envoyées d'abord (P4) | `test/integration/offline/logout_purge_test.rb` (en-tête) ; `test/javascript/offline/purge.test.js` (caches et base vidés) |
| P2 | **Un second élève se connecte sans que le premier se soit déconnecté** (compte changé, cookie expiré) | Chaque page porte une **clé d'appareil opaque** du compte (`<meta name="lnclass-offline-key">`, HMAC de l'identifiant, jamais l'identifiant). Au chargement, si la clé diffère de celle rangée, tout ce qui appartient à l'ancienne clé est purgé, **sauf sa file de copies non envoyées** (P4). Le programme d'arrière-plan ne sert une page gardée que sous la clé courante | `test/javascript/offline/purge.test.js` (changement de clé) ; `test/integration/offline/offline_key_test.rb` (clé stable par compte, différente entre comptes, absente sans connexion) |
| P3 | **Un enfant ouvre l'app d'un compte resté connecté hors ligne** | Comme en ligne aujourd'hui : le cookie de session vit 30 jours d'inactivité (`SessionLifetime`). Hors ligne, rien de plus n'est exposé que ce qui l'est en ligne. Toute page gardée a une **durée de vie de 30 jours** (alignée sur la session), puis elle est purgée | `test/javascript/offline/page_cache.test.js` (entrée de 31 jours purgée) |
| P4 | **Les copies non envoyées d'un élève partent sous le compte d'un autre** | Chaque copie en file porte la clé d'appareil de son auteur. La synchronisation n'envoie que les copies dont la clé est celle de la page courante ; le serveur vérifie le **jeton signé du paquet** porté par la copie (`student_id`, `exercise_id`) et **refuse** une copie dont l'élève n'est pas l'acteur connecté (`:wrong_owner`, sans écrire) | `test/domain/use_cases/assessment/sync_offline_copy_test.rb` (autre élève refusé) ; `test/javascript/offline/sync.test.js` (copies d'une autre clé jamais envoyées) |
| P5 | **Pages de l'enseignant** (noms, notes d'élèves) lisibles par qui emprunte son téléphone | Mêmes règles P1–P3. En plus : seules les pages déjà ouvertes et inscrites sur la liste du Lot E ; aucune page d'équipe, de direction, de facturation ni d'identité n'est jamais gardée (liste fermée côté serveur, P6) | `test/integration/offline/keepable_pages_test.rb` (liste fermée, pages d'équipe sans l'en-tête) |
| P6 | **Une page secrète ou sensible gardée par erreur** (PIN affiché, second facteur, facture, profil) | Le serveur décide seul : seul un en-tête `Lnclass-Offline: keep`, posé par une liste fermée d'actions, autorise le programme à garder la page. Sans lui, ou avec `no-store`, ou sur une redirection, ou hors statut 200, rien n'est gardé. Les écrans `secret_response` (ADR-0031) gardent `no-store` | `test/integration/offline/keepable_pages_test.rb` ; `test/javascript/offline/page_cache.test.js` (sans en-tête, `no-store`, 302, 500 : rien gardé) |

## B. Corrigé sur l'appareil

| # | Attaque | Ce qui l'arrête | Preuve |
|---|---|---|---|
| C1 | **Lire le corrigé avant de répondre** | **Accepté par le porteur** (décision 2 du memo) : le corrigé d'un exercice ouvert est dans la base locale, lisible avec les outils du navigateur. Conséquence écrite : la note faite hors ligne est un entraînement ; la note qui compte est celle du serveur (C2), et l'enseignant voit qu'une copie a été rendue hors ligne (Lot C) | Aucune : risque consenti (ADR §5) |
| C2 | **Récupérer le corrigé d'un exercice jamais ouvert, ou interdit** (autre niveau, non publié, accès bloqué) | Le paquet de corrigé n'est servi qu'à un élève connecté, par le même chemin d'autorisation que la page de l'exercice (`StartExerciseSession` : publication, niveau, accès bêta/abonnement). Une requête par exercice ; limite 30 par minute | `test/controllers/assessment/offline_packs_controller_test.rb` (non connecté, enseignant, autre niveau, non publié, accès bloqué : refusés) |
| C3 | **Un corrigé gardé pour une version d'exercice modifiée depuis** | Le paquet porte l'empreinte de la version, reprise dans son jeton signé. À la synchronisation, une empreinte différente est refusée (`:stale`, sans écrire) et la copie est montrée à l'élève « Exercice modifié, copie non comptée » | `sync_offline_copy_test.rb` (`:stale`) |

## C. Copies rendues hors ligne

| # | Attaque | Ce qui l'arrête | Preuve |
|---|---|---|---|
| R1 | **Falsifier la note locale** (modifier la base locale, envoyer `score: 100`) | Le serveur **ne lit aucune note** envoyée : la charge ne contient que les réponses. Il recorrige avec les règles du domaine (`Question#correct?`, `Grading`). La note locale est affichée « provisoire » jusqu'au retour | `sync_offline_copy_test.rb` (une clé `score` est ignorée ; la note vient des réponses) |
| R2 | **Rejouer une copie** (même envoi deux fois, réseau qui coupe pendant l'envoi) | Identifiant de copie tiré sur l'appareil (UUID v4). Index unique `(student_id, client_copy_id)` : un second envoi rend la copie déjà enregistrée, sans en créer une autre (`:already_synced`, 200) | `sync_offline_copy_test.rb` ; `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb` (index unique, deux envois concurrents) |
| R3 | **Multiplier les copies** pour gonfler la moyenne ou contourner la pause de « Recommencer » | Une copie hors ligne compte comme une copie terminée : la règle `RestartPause` (3 copies d'affilée) s'applique à l'appareil (pas de 4e copie proposée) et au serveur (la 4e copie de la journée est refusée `:paused`, gardée en file). 20 copies par synchronisation, 30 synchronisations par minute | `sync_offline_copy_test.rb` (`:paused`) ; contrôleur : limite de débit |
| R4 | **Antidater ou postdater la copie** (horloge du téléphone changée) | L'heure d'origine est gardée (décision du porteur) mais **bornée** : jamais après l'heure de réception, jamais plus de 30 jours avant, jamais avant l'heure d'émission du paquet de corrigé (`issued_at`, dans le jeton signé par le serveur). Hors bornes : ramenée à la borne. L'heure de réception est gardée à côté ; l'enseignant voit « rendue hors ligne » | `sync_offline_copy_test.rb` (futur, 31 jours, avant le paquet) |
| R5 | **Charge hostile** : énorme, mal formée, identifiants de questions d'un autre exercice, réponses d'un type inattendu | Même DTO que la copie en ligne (`CopyInput`, 100 réponses au plus, `AttemptInput`, 2 000 caractères pour un texte) ; une question qui n'est pas de l'exercice est refusée (`:invalid`) ; corps borné à 256 Kio | `sync_offline_copy_test.rb` ; `test/controllers/assessment/offline_copies_controller_test.rb` (413, 422) |
| R6 | **Envoyer une copie sans droit** (accès bêta fini, élève désactivé, exercice dépublié entre-temps) | L'autorisation est **rejouée à la réception** : même policy que la copie en ligne, avec l'état du serveur à l'heure de réception. Refusée : rien n'est écrit, la copie reste en file 30 jours avec son motif | `sync_offline_copy_test.rb` (accès bloqué, exercice dépublié) |
| R7 | **CSRF** : une autre page fait envoyer une copie | Envoi en `fetch` même origine avec `X-CSRF-Token` (jeton lu dans la page courante, frais) ; protection Rails inchangée, aucun `skip_forgery_protection` | `offline_copies_controller_test.rb` (sans jeton : refusé, avec `allow_forgery_protection` activé dans le test) |

## Ce qui n'est pas couvert (consenti)

- Un appareil **volé déverrouillé** et resté connecté : on n'y peut rien de plus qu'en ligne ; la purge à 30 jours borne l'exposition.
- Le chiffrement de la base locale : sans secret hors de l'appareil, il ne protège de rien. Non fait.
