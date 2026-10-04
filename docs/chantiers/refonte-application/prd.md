# PRD cadre — Refonte Lnclass

> **PRD de programme** ([`docs/workflows/programme.md`](../../workflows/programme.md)) : il fixe ce qui vaut pour **toutes** les vagues — les acteurs, qui peut quoi, et les exigences transverses. Les critères d'acceptation d'une feature donnée vivent dans le `prd.md` du chantier de sa vague, qui ne peut pas contredire celui-ci.
> Toute évolution passe par une modification explicite de ce fichier, datée dans le [journal](journal.md).

## 1. Contexte

Lnclass est reconstruit dans un nouveau dépôt Rails 8.1, hexagonal, vague par vague ([feuille de route](feuille-de-route.md)). L'ancienne application reste la référence fonctionnelle ([inventaire](inventaire/)) mais pas un modèle : elle vérifiait l'authentification partout et l'autorisation presque nulle part ([`securite.md`](securite.md)). Ce PRD fixe donc d'abord **qui a le droit de faire quoi**, avant toute feature.

## 2. Acteurs

| Acteur | Qui | Création du compte | Vague d'arrivée |
|---|---|---|---|
| **Student** | Élève du secondaire ivoirien, sur téléphone | Inscription publique, **uniquement** avec un code de classe valide | V1 |
| **Teacher** | Enseignant, une matière | Inscription publique, rattachée à une école | V1 |
| **Team** | Membre de l'équipe Lnclass : contenu, référentiels, administration | **Jamais par formulaire public** : seed ou invitation d'un `team` existant, second facteur obligatoire ([ADR-0025](../../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md)) | V1 |
| **SchoolStaff** (rôle `school_admin`) | Direction ou personnel d'un établissement | **Jamais auto-déclaré** : invitation ou validation par un tiers déjà rattaché (décision F-22) | V2 |
| **Parent** | Tuteur d'un élève | — | **Retiré du plan** (hors périmètre le 2026-09-18, retiré le 2026-09-22) : le rôle n'est pas déclaré dans l'énumération des rôles |

Les sous-rôles internes de l'équipe évoqués dans [`feature_listing.md`](../../feature_listing.md) (admin, tech, marketing, dev, gestionnaire DRENA, agents de terrain) ne sont **pas** des acteurs de V1 : un seul rôle `team` jusqu'à la décision F-16.

## 3. Matrice des permissions cibles

Règle qui gouverne tout le tableau : **chaque use case déclare sa policy, chaque policy a son test, un use case sans policy ne passe pas la revue.** Une cellule `—` est un refus, vérifié par un test.

| Capacité | Student | Teacher | Team | SchoolStaff | Policy |
|---|---|---|---|---|---|
| Voir le catalogue publié (cours, fiches, exercices) | ✅ | ✅ | ✅ | ✅ | `Catalog::ReadPublishedPolicy` |
| Voir un contenu **non publié** | — | — | ✅ | — | idem |
| Créer, modifier, archiver du contenu | — | — | ✅ | — | `Catalog::ManageContentPolicy` |
| Voir les **bonnes réponses** d'un exercice hors correction | — | ✅ *(tout exercice qu'il peut lire, y compris avant de l'assigner ; 2026-09-25)* | ✅ | — | `Assessment::RevealAnswersPolicy` |
| Démarrer une session sur un exercice | ✅ *s'il est assigné à l'une de ses classes et publié* | — | — | — | `Assessment::StartSessionPolicy` |
| Voir le résultat d'une session | ✅ *la sienne* | ✅ *élève de sa classe* | ✅ | — | `Assessment::ReadSessionPolicy` |
| Rejoindre une classe par code | ✅ | — | — | — | `Classroom::JoinPolicy` |
| Ouvrir une classe (fiche, liste d'élèves, code d'adhésion) | ✅ *la sienne, sans la liste nominative* | ✅ *s'il y enseigne* | ✅ | ✅ *de son école* | `Classroom::AccessPolicy` |
| Déclarer les classes qu'on enseigne | — | ✅ *de son école* | — | — | `Classroom::TeachPolicy` |
| Assigner / retirer une ressource à une classe | — | ✅ *s'il y enseigne* | ✅ | — | `Classroom::AssignPolicy` |
| Gérer les référentiels (niveaux, séries, matières, DRENA, écoles) | — | — | ✅ | — | `School::ManageReferentialPolicy` |
| Gérer les classes et le personnel d'un établissement | — | — | ✅ | ✅ *de son école* | `School::ManageSchoolPolicy` |
| Voir la fiche d'un autre utilisateur | — | ✅ *élève de sa classe* | ✅ | ✅ *de son école* | `Identity::ReadUserPolicy` |
| Créer un compte `team` | — | — | ✅ *invitation* | — | `Identity::InviteTeamPolicy` |
| Supprimer ou anonymiser un compte | — | — | ✅ | — | `Identity::DeleteUserPolicy` |
| Modifier son propre profil / son PIN | ✅ | ✅ | ✅ | ✅ | `Identity::UpdateSelfPolicy` — **PIN actuel exigé** |
| Publier une annonce | — | ✅ *à ses classes (2026-10-04, ADR-0078)* | ✅ | ✅ *pour son école, officielle (2026-10-04, ADR-0078)* | `Communication::PublishPolicy` |
| Retirer l'annonce d'un autre auteur | — | — | ✅ | ✅ *d'un enseignant de son école (2026-10-04, ADR-0078)* | `Communication::WithdrawPolicy` |
| Lire une annonce | ✅ *son audience, publiée, non terminée* | ✅ *idem* | ✅ | ✅ *idem* | règle de lecture unique `Queries::Communication::ReadableMessages` *(ADR-0078 §4.3)* |

Les noms de policies sont indicatifs ; leur forme exacte est fixée par la décision F-04.

## 4. Exigences transverses — valables dès la vague 1

### Sécurité ([`securite.md`](securite.md), [ADR-0025](../../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md))

- Aucune route publique ne crée un rôle autre que `student` ou `teacher`.
- `force_ssl` en production ; `reset_session` à la connexion et à la déconnexion ; expiration de session.
- `rate_limit` sur la connexion, verrouillage progressif, journal des échecs.
- PIN validé côté serveur (`/\A\d{4}\z/`), jamais dérivé du contact, toujours saisi dans un `password_field`.
- Second facteur obligatoire pour `team` ; parcours de récupération du PIN pour tous.
- Changer son PIN ou son contact exige le PIN actuel.
- Un use case déclare ses paramètres : jamais d'assignation dynamique d'un sac d'attributs.
- Les URL n'exposent **aucun identifiant séquentiel** ; les endpoints publics (vérification de code de classe) sont limités en débit et ne renvoient que le strict nécessaire.
- Tout téléversement est validé (type, taille) ; `:contact` est filtré des logs ; un journal d'audit trace connexions, changements de secret, suppressions de compte et rattachements.

### Données ([ADR-0005](../../decisions/adr/0005-decouplage-audit-admin-et-integrite-donnees.md), [ADR-0016](../../decisions/adr/0016-conservation-historique-assignations.md))

- Aucune cascade destructrice depuis un compte, un élément de taxonomie ou un contenu vers la production des élèves (sessions, tentatives, badges, lacunes). Archivage ou refus, jamais `dependent: :destroy` sur l'historique.
- Toute invariante métier (« une adhésion principale par élève », « une lacune en attente par élève et notion », « un profil par utilisateur ») est garantie **en base** par un index, pas seulement en code.
- Toute création multi-tables (compte + profil + adhésion) est transactionnelle.

### Qualité ([ADR-0024](../../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md), [conventions §7](../../guide/conventions.md#7-ce-qui-bloque))

- 100 % de couverture lignes et branches sur `app/` et `lib/`, `# :nocov:` interdit, test de mutation sur `app/domain/`.
- Chaque parcours nominal d'une vague a son test système en navigateur réel.
- En-tête HITL sur chaque fichier de `app/`.

### Interface

- Toute chaîne passe par `t(".key")`, locale `:fr`, `raise_on_missing_translations` actif en développement et en test.
- Aucune valeur arbitraire (`[…]`), aucun hexadécimal en dur dans les vues : vérifié par un test (décision F-09).
- Cibles tactiles ≥ 48 × 48 px, focus visible au clavier, `alt` sur toute image porteuse de sens, états vide / chargement / erreur / succès sur chaque écran ([`udr/README.md`](../../decisions/udr/README.md)).
- Chaque vue est régie par une UDR.

## 5. Critères d'acceptation transverses

Chacun devient un test, dans le chantier de la vague qui introduit la capacité concernée.

```gherkin
Étant donné un visiteur non connecté
Quand il soumet un formulaire d'inscription en forçant le rôle "team" ou "school_admin"
Alors aucun compte "team" ni "school_admin" n'existe après la requête
Et tout compte créé par cette requête a le rôle "student" ou "teacher"

Étant donné un compte élève existant
Quand cinq tentatives de connexion échouent en une minute
Alors la sixième est refusée sans que le PIN soit vérifié
Et l'échec est journalisé

Étant donné un élève connecté et un exercice assigné à sa classe
Et un enseignant qui a déjà affiché la même fiche, cache de fragments actif
Quand il affiche la fiche, l'exercice ou une question en cours de session
Alors aucune bonne réponse n'est présente dans le HTML servi

Étant donné un enseignant qui n'enseigne pas dans la classe 3ème B
Quand il demande la fiche de la 3ème B, par son URL directe
Alors l'accès est refusé
Et ni le code d'adhésion ni la liste des élèves ne sont servis

Étant donné un membre de l'équipe sans second facteur validé
Quand il se connecte avec un PIN correct
Alors il n'accède à aucune page réservée à l'équipe

Étant donné un exercice sur lequel des élèves ont des sessions terminées
Quand un membre de l'équipe demande sa suppression
Alors les sessions, tentatives et badges des élèves sont conservés
```

## 6. Décisions rattachées

Registre complet, avec statut et vague bloquée : [`feuille-de-route.md` §3](feuille-de-route.md#3-registre-des-décisions-de-fondation).

- En vigueur : ADR-0001, 0002, 0003, 0005, 0006, 0007, 0008, 0010, 0013, 0016, 0017, 0024, 0025 — sous réserve des remplacements listés au registre des contradictions.
- À écrire avant la vague 0 : F-27, F-29 et F-30.
- À écrire avant la vague 1 : toutes les lignes du registre dont la colonne « Bloque » vaut V1. Ce sont F-01 à F-16, F-14 n'en faisant partie que pour le contenu, plus F-26, F-28, F-31, F-32 et F-34. F-25 s'y ajoute si la V1 téléverse des fichiers.

## 7. Mesures

| Métrique | Ancienne app | Cible |
|---|---|---|
| Couverture lignes / branches | 45,8 % / 29,5 % | 100 % / 100 % |
| Policies testées | 1 (dont le test n'autorisait rien) | 1 par use case |
| Routes publiques créant un rôle privilégié | 2 (`/team-signup`, `/staff-signup`) | 0 |
| Chaînes d'interface via `t()` | 1 vue sur 315 | 100 % |
| Valeurs arbitraires dans les vues | 559 | 0 |
