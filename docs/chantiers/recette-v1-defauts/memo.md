# Memo — Défauts de la recette V1

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré (PR ouverte, en attente de revue) |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `fix/recette-v1-defauts` |
| **Programme** | — |

Source : [recette `Staging` du 2026-09-28](../boucle-pedagogique/journal.md#recette-staging-du-2026-09-28), défauts D1 et D2. Pas d'ADR : aucune cause architecturale. D1 change ce que voit l'élève : [amendement du 2026-09-28 de l'UDR-0009](../../decisions/udr/0009-rejoindre-une-classe.md#amendement-du-2026-09-28--join-vérifie-le-code).

## D1 (majeur) — `/join` et un code bien formé mais inconnu

**Symptôme** — Sur `/join`, l'élève saisit `ZZZ99` et presse « Continuer » : pas de message sous le champ. À la recette (téléphone, `Staging`), l'écran restait sur `/join`, vide de tout message ; en Chromium local, Turbo affiche la page 404 de `/c/zzz99`. Dans les deux cas, le formulaire ne dit pas que le code est faux.

**Reproduction** — Visiteur, aucune classe de code `zzz99`. `GET /join` → saisir `ZZZ99` → « Continuer ». `POST /join` répond 303 vers `/c/zzz99`, qui répond 404. Test système : `test/system/classroom/join_test.rb`, « D1: a well-formed but unknown code… » (bureau et 390 px), rouge avant correctif : `expected to find css "#join_code_error" but there were no matches`.

**Portée** — Depuis la livraison de `/join` (Lot A1, 2026-09-27). Tout élève qui se trompe de code. Aucune donnée écrite, rien à réparer.

**Root cause** — `Classroom::JoinCodesController#create` redirigeait tout code bien formé sans le chercher (UDR-0009 point 1, choix délibéré pour laisser `/c/<code>` seule sous limite de débit). L'erreur n'existait qu'après la redirection, en 404, là où Turbo Drive ne rend pas une réponse de formulaire de façon fiable. Trou de test : le test contrôleur affirmait ce comportement (« an unknown well-formed code still opens its page ») et le test système ne passait par `/join` qu'avec un code valide.

**Correctif** — `create` interroge `Queries::Classroom::JoinPreviewQuery` (celle de `/c/<code>`) : pas d'aperçu → 422 dans le champ, avec les mots de la 404 de `/c/`. La vérification porte la limite de débit de `/c/<code>`, même compteur (`scope: "classroom/joins"`), sur `create` seulement ; au-delà : 429, message sous le champ, aucune recherche. Un code valide redirige toujours en 303 vers `/c/<code>`.

## D2 (mineur) — pages d'erreur statiques en anglais

**Symptôme** — `public/404.html` (et 400, 422, 500) : pages Rails par défaut, en anglais.

**Reproduction** — `GET /404.html`, ou toute route inconnue en production : « The page you were looking for doesn't exist ».

**Correctif** — Quatre pages statiques `lang="fr"`, tokens du thème (couleurs, familles de polices, rayons de `application.tailwind.css`, sans charger de police), sans JavaScript ni ressource externe, lien « Revenir à l'accueil ». CSS en ligne : ces pages sont servies par `ActionDispatch::Static` ou `PublicExceptions`, en amont de `ContentSecurityPolicy::Middleware` : aucune CSP n'y est envoyée (vérifié par requête : en-tête absent). `406-unsupported-browser.html` n'existe pas et n'est pas utile : `allow_browser` prend un bloc qui prévient sans bloquer (ADR-0051).

## Hors périmètre

- D3 (`style-src-attr 'unsafe-inline'`) : décision à consigner à part.
- `/c/<code>` inchangée (aperçu d'une classe archivée qui garderait son code : impossible, l'archivage met le code à `NULL`, ADR-0041).

## Portes de sortie

- [x] Symptôme et étapes de reproduction écrits
- [x] Bug reproduit dans un vrai navigateur (Chromium, bureau et 390 px) avant le correctif
- [x] Root cause : fichier, chaîne d'appels, trou de test
- [x] Tests de reproduction écrits avant les correctifs, rouges pour la bonne raison (D1 : `#join_code_error` absent ; D2 : `html[lang=fr]` absent)
- [x] Correctif dans la couche de la cause (delivery : le contrôleur qui redirigeait sans chercher)
- [x] Cas symétrique : code valide saisi n'importe comment → `/c/kfm37` et inscription (test système existant, vert)
- [x] Données corrompues : aucune
- [x] Commits `fix(classroom): …` et `fix(ui): …` avec `Chantier:`
- [x] `journal.md` rempli
