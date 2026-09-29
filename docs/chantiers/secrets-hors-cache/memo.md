# Memo — Secrets à usage unique hors de tout cache

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré sur `fix/secrets-hors-cache` (pas de PR) |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `fix/secrets-hors-cache` |
| **Origine** | constat « Sécurité » de l'audit `finitions-ux` (§ 5c et § 8, ligne HTTP et Cache Turbo) |

---

## Le problème

Un écran qui montre un secret **une seule fois** peut être ré-affiché après coup : par l'aperçu du cache Turbo (Retour, ou retour vers une page déjà visitée), par le cache arrière du navigateur (bfcache), ou par un cache intermédiaire. Le secret devient alors lisible par quiconque reprend le téléphone, alors que l'écran promet « montré une seule fois ».

## Symptôme (littéral)

Compte `team` qui active son second facteur : il note ses 10 codes de secours, appuie sur « J'ai noté mes codes », puis sur Retour. La page des codes réapparaît (aperçu Turbo ou bfcache) : la réponse n'a ni `Cache-Control: no-store`, ni `<meta name="turbo-cache-control" content="no-cache">`. Même chose pour la clé TOTP et le QR code de la page d'enrôlement.

## Écrans recensés

Un écran est dans le périmètre s'il affiche en clair un secret qui n'est **stocké qu'en empreinte** (ou pas du tout) et qui donne un accès.

| # | Écran | Action | Secret | `no-store` avant | Exemption Turbo avant |
|---|---|---|---|---|---|
| 1 | Enrôlement du second facteur | `Identity::SecondFactorEnrollmentsController#new` (et le 422 de `#create`, qui re-rend le même QR) | clé TOTP, QR `otpauth://` | non | non |
| 2 | Codes de secours | `Identity::SecondFactorEnrollmentsController#create` (Turbo Stream et HTML) | 10 codes de secours | non | non |
| 3 | Code de récupération du PIN | `Identity::PinRecoveryCodesController#create` (modale, repli `show`) | code à 8 chiffres | oui (succès seul) | non |
| 4 | Lien d'invitation de l'équipe | `Teams::InvitationsController#create` (modale, repli `created`) | jeton du lien | oui (succès seul) | non |
| 5 | Lien d'invitation de la direction | `Teams::StaffInvitationsController#create` (modale, repli `created`) | jeton du lien | oui (succès seul) | non |

Écartés après examen (voir `journal.md`) : lien de parrainage et code d'établissement (codes **partagés** et durables, faits pour circuler), code d'adhésion des classes (idem), page d'acceptation d'une invitation (le jeton est dans l'URL, la page ne l'affiche pas), vérification du second facteur (aucun secret affiché), réinitialisation du second facteur par l'équipe (aucun secret émis).

## Reproduction

| # | Étapes | Résultat avant correctif |
|---|---|---|
| 1 | Compte `team` sans second facteur, connecté par PIN : `GET /identity/second-factor/enrollment/new` | 200, `Cache-Control: max-age=0, private, must-revalidate`, pas de `Pragma`, pas de meta `turbo-cache-control` |
| 2 | Même compte : `POST /identity/second-factor/enrollment` avec un code juste (HTML et Turbo Stream) | 200, mêmes en-têtes par défaut ; le flux Turbo ne pose aucune exemption dans `<head>` |
| 3–5 | `POST` de l'émission d'un code de récupération / d'une invitation (Turbo Stream et HTML) | `no-store` présent, mais ni `Pragma: no-cache` ni exemption du cache Turbo : la page hôte de la modale est mise en cache avec le secret dans le DOM |

Les tests de reproduction (rouges avant correctif) sont listés au journal.

## Portée

- Depuis l'ADR-0031 (second facteur) et l'ADR-0032 / ADR-0038 (code de récupération, invitations).
- Acteurs : comptes `team` (écrans 1, 2, 4, 5), enseignants et équipe (écran 3).
- **Aucune donnée à réparer** : les secrets sont stockés en empreinte ; seul l'affichage était exposé.

## Cause racine

Pas de mécanisme commun pour une réponse « secrète » : chaque contrôleur posait (ou oubliait) `response.headers["Cache-Control"] = "no-store"` à la main dans la branche succès, et aucun écran ne demandait à Turbo de ne pas garder la page en cache. Fichiers : `app/controllers/identity/second_factor_enrollments_controller.rb` (rien), `app/controllers/identity/pin_recovery_codes_controller.rb:14`, `app/controllers/teams/invitations_controller.rb:18`, `app/controllers/teams/staff_invitations_controller.rb:19` (en-tête seul, succès seul).
*Pourquoi aucun test ne l'a vu* : les tests vérifiaient l'en-tête écran par écran, là où il avait été pensé ; aucun test ne listait les écrans à secret, et aucun ne regardait le cache Turbo.

## Correctif

Un seul marquage, au niveau du contrôleur : `secret_response :new, :create` (concern `SecretResponse`, inclus dans `ApplicationController`).

- **HTTP** : `before_action` qui pose `Cache-Control: no-store` et `Pragma: no-cache` sur **toute** réponse de l'action marquée (succès, 422, repli HTML).
- **Page HTML** : le layout pose `<meta name="turbo-cache-control" content="no-cache">` quand l'action est marquée.
- **Turbo Stream** : les flux des actions marquées commencent par `turbo_stream_secret_response`, qui ajoute ce même meta au `<head>` de la page hôte (`append` sur `targets="head"`) ; Turbo ne met alors pas la page en cache quand on la quitte.
- **Garde** : un test liste les actions à secret et vérifie qu'elles, et elles seules, portent le marquage.

Décision notée en amendement daté de l'ADR-0031.

## Hors périmètre

- Préchargement au survol de Turbo, cache applicatif, ETag : volet « 8. Caching » de l'audit, chantier `optimize` séparé.
- Téléchargement / copie des codes de secours (§ 5c de l'audit) : chantier `finitions-ux`.

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit : en-têtes par tests d'intégration, et dans un vrai navigateur (Retour après les codes de secours les ré-affichait, test système rouge sur `Develop`)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test
- [x] Test de reproduction écrit **avant** le correctif
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié)
- [x] Correctif appliqué dans la couche de la **cause** (delivery : contrôleur et layout)
- [x] Test au vert · suite du contexte borné au vert
- [x] Cas symétrique vérifié : une page sans secret garde l'en-tête par défaut et reste en cache Turbo ; parcours d'invitation (équipe, direction) verts en test système
- [x] Données déjà corrompues : aucune
- [x] Commit `fix(identity): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés
- [x] `bin/rubocop` (0 offense) · `CI=1 PARALLEL_WORKERS=2 bin/rails test` (2406 tests, 0 échec, 100 % lignes 8656/8656 et branches 2109/2109) · `COVERAGE=0 bin/rails test:system` (199 tests, 0 échec) · `bin/brakeman -q --no-pager` (0 alerte)
