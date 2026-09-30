# Memo — Émetteur TOTP par environnement

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré *(2026-09-30, PR #114 vers `Develop`)* |
| **Ouvert le** | 2026-09-30 |
| **Branche** | `fix/totp-emetteur-par-environnement` |
| **Programme** | — |

---

## Symptôme

Le porteur utilise le même numéro de téléphone pour son compte équipe en production et en develop. Son application d'authentification n'affiche **qu'une seule entrée « Lnclass »**. Ses codes sont acceptés sur un environnement, et l'autre répond **« Code incorrect. »**.

## Reproduction

Constaté par le porteur le 2026-09-30, sur les environnements Railway `production` et `Develop` du même projet :

1. Un compte équipe avec le numéro N existe en production et en develop, chacun dans sa base.
2. Activer le second facteur en production : l'application d'authentification ajoute l'entrée « Lnclass · N ».
3. Activer le second facteur en develop : l'application reçoit une entrée au **même nom** « Lnclass · N », avec un autre secret, et **remplace** la précédente.
4. Se connecter en production : après le PIN, le code affiché est refusé, « Code incorrect. ». En develop, il est accepté.

Reproduction sans téléphone : le QR code des deux environnements porte la même adresse `otpauth://totp/Lnclass:N?…&issuer=Lnclass`. Seul le secret change.

## Portée

- **Acteurs** : les comptes équipe, seuls à avoir un second facteur (ADR-0031). La direction et les autres rôles ne sont pas concernés.
- **Depuis quand** : depuis qu'un même numéro a un compte équipe dans plusieurs environnements Railway (`Develop`, `Staging`, `production`). Le nom du QR code est fixe depuis l'introduction du second facteur (2026-09-25).
- **Données à réparer** : **aucune en base**. Chaque environnement garde le bon secret. Seul le téléphone du porteur a perdu une entrée : il la retrouve en réactivant le second facteur de l'environnement dont les codes sont refusés, après réinitialisation par un autre membre de l'équipe (ADR-0031), puis en renommant l'entrée existante. Cette action manuelle est hors du correctif.

## Comportement attendu et sa source

Un membre de l'équipe qui a activé son second facteur se connecte avec le code affiché par son application d'authentification (ADR-0031, §4, parcours 1 et 2).

## Hors périmètre

- Toute autre évolution du second facteur (clé matérielle, SMS, second facteur pour la direction).
- Toute autre différence entre environnements repérée en passant : elle part dans le journal, en chantier de suivi.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que voit exactement le porteur ? | Une seule entrée « Lnclass » dans l'application ; ses codes marchent sur un environnement, l'autre les refuse | L'entrée du premier environnement a été **remplacée** par celle du second, qui porte le même nom avec un autre secret. Aucune donnée n'est fausse en base : chaque environnement garde le bon secret, c'est le téléphone qui a perdu l'un des deux |
| Quel nom doit porter l'entrée dans chaque environnement ? | **« Lnclass » en production, « Lnclass (<nom de l'environnement>) » ailleurs** (porteur) | Le nom vient de l'environnement Railway, fourni à chaque déploiement : `Develop`, `Staging`, `production`. Hors Railway (poste de développement, tests), c'est l'environnement Rails qui nomme. Seules les **nouvelles** activations en profitent : une entrée déjà ajoutée garde son nom |

## Cas limites identifiés

- Environnement Railway nommé `production` : l'entrée reste « Lnclass », comme aujourd'hui, et les comptes déjà activés en production ne voient aucun changement.
- Variable d'environnement Railway absente (poste local, CI, tests) : le nom vient de l'environnement Rails (« Lnclass (development) », « Lnclass (test) ») ; un serveur de production sans la variable garde « Lnclass ».
- Un nom d'environnement contenant « : » casserait l'adresse du QR code (séparateur émetteur:compte) : les noms actuels n'en ont pas ; le caractère est retiré par précaution.
- Une page d'activation rouverte (correctif `enrolement-secret-stable`) remontre le même secret, avec le nouveau nom : cohérent.

## Questions encore ouvertes

- Aucune.

## Portes de sortie

Lot unique, aucune migration, aucun fichier partagé : `plan.md` est retiré du chantier.

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code *(par le porteur, 2026-09-30, étapes ci-dessus)*
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test *(journal)*
- [x] Test de reproduction écrit **avant** le correctif *(commit `87efde97`)*
- [x] Test lancé et **rouge**, pour la bonne raison (message vérifié) *(3 échecs « Expected "Lnclass (Develop)", Actual "Lnclass" », aucune erreur ; le cas `production` déjà vert)*
- [x] Correctif appliqué dans la couche de la **cause**, pas du symptôme *(dépôt du second facteur, infrastructure ; commit `dc2bb8d4`)*
- [x] Test au vert · suite du contexte borné au vert *(identity + intégration : 471 tests ; suite complète : 2 576 tests, 0 échec ; RuboCop et Brakeman sans remarque)*
- [x] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours *(challenger : émetteur « Lnclass » en `production` ; activation complète puis reconnexion avec un code valide, 303 vers `/teams`, en `Develop` et en `production`)*
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal *(aucune en base ; réactivation manuelle du porteur notée au journal)*
- [x] Challenger a rejoué les étapes de reproduction dans l'application *(2026-09-30 : `Develop` → « Lnclass (Develop):0700000000 », `production` → « Lnclass:0700000000 » ; code faux → 422 « Code incorrect. », même QR code)*
- [x] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [x] `journal.md` : cause, trou de test comblé, effets de bord écartés

## Contrat d'exécution

1. Écrire le test de reproduction dans `test/infrastructure/repositories/identity/second_factor_repository_test.rb` : avec l'environnement Railway `Develop`, l'adresse du QR code porte l'émetteur « Lnclass (Develop) » ; avec `production`, « Lnclass ».
2. Le lancer et le voir **échouer** sur l'émetteur (« Lnclass » reçu au lieu de « Lnclass (Develop) »), pas sur autre chose.
3. Corriger dans le dépôt du second facteur (couche infrastructure), là où l'émetteur est fixé.
4. Relancer : vert. Relancer `test/infrastructure/repositories/identity`, `test/domain/use_cases/identity` et `test/controllers/identity` : rien d'autre ne bouge.
5. Dater un amendement de l'ADR-0031 : l'émetteur dépend de l'environnement.
