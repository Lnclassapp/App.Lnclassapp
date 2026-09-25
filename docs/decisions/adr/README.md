# Registre des décisions d'architecture (ADR) — Lnclass

Un **ADR** (*Architecture Decision Record*) consigne le contexte, les moteurs de décision, la décision retenue et ses conséquences — positives comme négatives. C'est la mémoire longue du projet : la décision se devine parfois, le contexte jamais.

Le format de référence est [`TEMPLATE.md`](./TEMPLATE.md). Les décisions d'**interface** vivent dans [`../udr/`](../udr/README.md).

---

## Index des ADR

| N° | Titre | Statut | Date | Problématique |
| :--- | :--- | :--- | :--- | :--- |
| [0001](./0001-architecture-hexagonale-rails8-monolithe.md) | Adoption de l'architecture hexagonale (DDD) dans un monolithe Rails 8 | Accepté | 2026-06-05 | Isoler les règles métier (`app/domain/`) d'ActiveRecord et des contrôleurs pour obtenir des tests unitaires en quelques millisecondes et éliminer les « Fat Models ». |
| [0002](./0002-authentification-native-contact-telephonique-sans-devise.md) | Authentification native par contact téléphonique (`has_secure_password`) | Accepté | 2026-06-12 | Abandonner Devise et la dépendance à l'email au profit d'une connexion par numéro de téléphone à 10 chiffres, adaptée au contexte ivoirien. |
| [0003](./0003-multi-appartenance-et-denormalisation-eleves.md) | Multi-appartenance et dénormalisation des élèves (`ClassroomStudent`) | Accepté | 2026-06-20 | Supprimer les clés étrangères directes sur `Student` (`level_id`, `school_id`) au profit d'une table de jointure avec attribut `primary: true` (classe officielle). |
| [0004](./0004-autorisation-multi-etablissements-enseignants.md) | Autorisation multi-établissements des enseignants (`ClassroomAccessPolicy`) | Accepté | 2026-06-25 | Permettre à un professeur d'enseigner dans plusieurs lycées via `teacher_schools` et sécuriser l'attribution des cours par un objet Policy pur Ruby. |
| [0005](./0005-decouplage-audit-admin-et-integrite-donnees.md) | Découplage de l'audit admin (`Team`) et règle anti-cascade | Accepté | 2026-07-02 | Interdire `dependent: :destroy` sur les créateurs d'écoles ou de cours ; utiliser systématiquement `on_delete: :nullify` pour empêcher la destruction accidentelle de la scolarité. |
| [0006](./0006-separation-ecriture-lecture-et-optimisation-queries.md) | Séparation écriture/lecture (CQRS léger) et anti-`group_by` en RAM | Accepté | 2026-07-08 | Réserver les Use Cases aux modifications et confier les lectures lourdes (dashboards) à des objets Query (`app/infrastructure/queries/`) exploitant l'agrégation SQL native. |
| [0007](./0007-hierarchie-pedagogique-et-assignations-polymorphes.md) | Hiérarchie pédagogique et assignations polymorphes (`ClassroomAssignment`) | Accepté | 2026-07-15 | Hiérarchiser le contenu en Matière ➔ Cours ➔ Fiche ➔ Exercice et utiliser une table d'assignation polymorphe traçant l'auteur (`assigned_by_id`). |
| [0008](./0008-moteur-evaluation-et-gamification.md) | Moteur d'évaluation, tentatives et gamification en temps réel | Accepté | 2026-07-18 | Évaluer les réponses aux exercices en batch sans N+1, verrouiller les sessions terminées et décerner instantanément les distinctions (`ExerciseBadge`). |
| [0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md) | Stack frontend — Tailwind v4, Hotwire (Turbo/Stimulus), Redux & KaTeX | ⚠️ **Remplacé partiellement** par [0013](./0013-suppression-redux-et-introduction-dto.md) *(partie Redux)* | 2026-07-22 | Éviter une SPA lourde en optant pour le rendu serveur (Turbo Stream) et KaTeX pour les formules. **Redux n'est plus en vigueur** ; Tailwind v4, Hotwire et KaTeX le restent. |
| [0010](./0010-stack-ops-solid-suite-postgresql-railway.md) | Infrastructure native Rails 8 — Solid Suite (Queue, Cache, Cable) & Railway | Accepté | 2026-07-25 | Abandonner Redis et Sidekiq au profit des tables SQL de la Solid Suite, réduisant les coûts et simplifiant le déploiement. |
| [0011](./0011-validation-collaborative-crowdsourcing.md) | Architecture et modélisation de la validation collaborative | Accepté | 2026-07-29 | Isoler la soumission de validation dans le Domaine avec des relations polymorphiques, pour que les enseignants signalent erreurs et non-conformités. |
| [0012](./0012-deep-modules-et-strict-cqrs.md) | Approfondissement des modules (Deep Modules) et CQRS strict | Accepté | 2026-07 *(jour non documenté)* | Supprimer les modules superficiels (passe-plats) et la duplication d'imports en utilisant des Query Objects et des ViewObjects pour la lecture. |
| [0013](./0013-suppression-redux-et-introduction-dto.md) | Suppression de Redux, maintien de Yarn et introduction des DTO | Accepté — *remplace [0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md) (partie Redux)* | 2026-08-12 | Abandonner Redux Toolkit au profit de Turbo/Hotwire et Stimulus, et découpler la couche Web du Domaine par des DTO. |
| [0014](./0014-standardisation-namespaces-et-validation-frontiere.md) | Standardisation des namespaces et validation aux frontières (DTOs) | Accepté | 2026-08-15 | Valider les inputs HTTP via des objets dédiés avant le passage au Domaine, et clarifier les espaces `presentation/`, `adapters/`, `ports/`. |
| [0015](./0015-strategie-de-tests-metier-isolement-des-policies.md) | Stratégie de tests métier et isolation des Policies | Accepté | 2026-08 *(jour non documenté)* | Tester les règles d'autorisation unitairement sur les objets Policy avec des Fakes en mémoire, au lieu de surcharger les tests de Use Cases. |
| [0016](./0016-conservation-historique-assignations.md) | Conservation de l'historique via soft delete (archivage) | Accepté | 2026-08 *(jour non documenté)* | Utiliser un statut `archived` au lieu d'un `destroy` pour les assignations polymorphes, afin de préserver l'historique et la traçabilité. |
| [0017](./0017-remplacement-nanoid-par-secure-random.md) | Remplacement de Nanoid par SecureRandom natif | Accepté | 2026-08-21 | Supprimer la dépendance `nanoid` et le concern `PublicIdGenerator` au profit de `SecureRandom.base58` pour alléger l'application. |
| [0018](./0018-remediation-just-in-time-et-historique-lacunes.md) | Remédiation, génération just-in-time et historique des lacunes | Accepté | 2026-08-27 | Tracer les lacunes (`KnowledgeGap`) d'un élève et générer la session de rattrapage au moment exact du clic, sans polluer la base de sessions orphelines. |
| [0019](./0019-simulation-eleves-demo.md) | Simulation des élèves de démonstration (Demo Students) | Accepté | 2026-08-27 | Peupler automatiquement une classe neuve d'élèves `is_demo` réalistes pour déclencher l'« aha moment » de l'enseignant face à un tableau de bord vide. |
| [0020](./0020-optimisations-bulk-insert-donnees-catalogue.md) | Optimisation des imports massifs via bulk insert (`insert_all`) | Accepté | 2026-08-29 | Éliminer les timeouts et le N+1 des imports (cours, classes, élèves démos) en déléguant l'insertion aux Repositories via `insert_all!` / `upsert_all`. |
| [0021](./0021-gestion-de-l-identite.md) | Migration de la gestion de l'identité vers le domaine pur | Accepté | — | Extraire la logique métier des modèles `Orm::User`, `Orm::Student`, `Orm::Teacher` vers `Entities::Identity::*`, via une délégation au vol qui ne casse pas les vues. |
| [0022](./0022-modelisation-hexagonale-du-catalogue-pedagogique.md) | Modélisation hexagonale du catalogue pédagogique | Accepté | — | Extraire le catalogue (Niveaux, Séries, Matières, Cours, Essentiels) des modèles ActiveRecord vers des entités, ports et use cases purs. *(Renuméroté depuis ADR-0014.)* |
| [0023](./0023-modelisation-de-l-organisation-scolaire.md) | Modélisation de l'organisation scolaire (hexagonale) | Accepté | — | Isoler la hiérarchie DRENA ➔ École ➔ Classe dans un bounded context `Identity` avec entités, ports et repositories dédiés. *(Renuméroté depuis ADR-0015.)* |
| [0024](./0024-couverture-de-tests-a-100-pourcent.md) | Couverture de tests à 100 %, bloquante sur le projet cible | Accepté | 2026-09-18 | Exiger 100 % de couverture lignes **et** branches sur `app/` et `lib/`, avec `# :nocov:` interdit et test de mutation obligatoire. Bloquant dès le premier commit du projet Rails cible ; sur ce dépôt, cliquet non régressif à 45 %/29 % jusqu'à la migration. |
| [0025](./0025-pin-a-4-chiffres-comme-secret-d-authentification.md) | PIN à 4 chiffres comme secret d'authentification, sous conditions | Accepté | 2026-09-18 | Conserver le code à 4 chiffres pour ne pas barrer l'accès des élèves, **à la condition stricte** de six compensations indissociables : limitation de tentatives, verrouillage progressif, validation serveur, aucune dérivation depuis le contact, second facteur sur les rôles privilégiés, parcours de récupération. |
| [0049](./0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) | Mesure d'audience côté serveur, sans script tiers, sous une CSP stricte | Accepté | 2026-09-24 | Aucun script, style, police ni iframe tiers ; CSP bloquante dès la V0 (scripts sous nonce, `object-src 'none'`, `frame-ancestors 'none'`) ; indicateurs métier agrégés lus côté serveur et affichés dans l'espace équipe en V4 ; aucun traceur ni bandeau de consentement. Tranche F-27 du programme de refonte. |
| [0051](./0051-navigateurs-supportes-et-budget-de-poids.md) | Navigateurs supportés sans blocage, et budget de poids vérifié en CI | Accepté — *complète [0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md)* | 2026-09-24 | Plus aucun 406 : plancher testé Chrome 111 / Safari 16.4 / Firefox 128 (celui de Tailwind v4), bandeau non bloquant en dessous ; budget gzip bloquant en CI (JS commun ≤ 60 Ko, CSS ≤ 30 Ko) ; Trix, KaTeX et confetti chargés à la demande. Tranche F-29 du programme de refonte. |
| [0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) | Chaîne de livraison versionnée, worker toujours actif dans Puma, échecs de job visibles | Accepté — *amende [0010](./0010-stack-ops-solid-suite-postgresql-railway.md) §3.1 et §5* | 2026-09-24 | `railway.json` versionné ; recette (`Staging`) et production (`main`) sur deux environnements Railway ; plugin Solid Queue inconditionnel, adaptateur `:solid_queue` en développement ; échecs visibles dans Mission Control Jobs ; `/up` testé et exclu de `force_ssl` ; Thruster gardé pour la compression. Tranche F-30 du programme de refonte. |

---

## Décisions remplacées — à lire avant d'agir

| ADR | Ce qui n'est plus en vigueur | Remplacé par |
| :--- | :--- | :--- |
| [0009](./0009-stack-frontend-vanilla-css-tailwind-hotwire.md) | **Redux Toolkit / `store.js`** : Redux a été retiré du projet. L'état local du client est géré exclusivement par des contrôleurs Stimulus. Le reste de l'ADR-0009 (Tailwind v4, Hotwire, KaTeX) reste en vigueur. | [0013](./0013-suppression-redux-et-introduction-dto.md) |
| [0010](./0010-stack-ops-solid-suite-postgresql-railway.md) | **§3.1** : le worker intégré à Puma est lancé **sans condition**, en développement comme en production. **§5** : Thruster est **requis** (compression, ADR-0051) ; Kamal reste inutile. Le reste de l'ADR-0010 (Solid Suite sur PostgreSQL, Railway) reste en vigueur. | [0052](./0052-chaine-de-livraison-versionnee-et-worker-dans-puma.md) *(amendement)* |

---

## Conventions de nommage

- Un fichier par décision : **`NNNN-titre-en-kebab-case.md`**.
- **4 chiffres**, séquentiel, **jamais réutilisé** — même si un ADR est déprécié ou remplacé, son numéro reste consommé.
- Pas d'accent, pas de majuscule, pas de `_` dans le nom de fichier ; seul le titre à l'intérieur du document porte les accents.
- Le numéro dans le nom de fichier, le numéro du titre `# ADR-NNNN : …` et la ligne d'index doivent toujours coïncider.

## Ajouter un ADR

1. Relever le dernier numéro pris : `ls docs/decisions/adr/ | tail -3`.
2. Copier [`TEMPLATE.md`](./TEMPLATE.md) vers `NNNN-titre-en-kebab-case.md` et remplir le bloc de métadonnées (Statut, Date, Chantier, Remplace, Remplacé par).
3. Rédiger le **contexte** en priorité : c'est la partie qu'on ne peut pas reconstituer plus tard.
4. Inclure du **code réel du projet** (avec son chemin de fichier) dans les notes d'implémentation, jamais du pseudo-code.
5. Renseigner honnêtement les **coûts consentis** : un ADR sans coût consenti n'a pas été écrit honnêtement.
6. Ajouter la ligne correspondante dans le tableau d'index ci-dessus.
7. **Si l'ADR en contredit un précédent** : renseigner `Remplace : ADR-NNNN` dans le nouveau, `Remplacé par : ADR-NNNN` dans l'ancien, ajouter un encadré d'avertissement en tête de l'ancien, et une ligne dans la table « Décisions remplacées ». Un ADR périmé n'est jamais supprimé ni réécrit : il est marqué.

## Champs inconnus

Quand une information (date, chantier, statut d'origine) est introuvable dans l'historique, écrire `—` ou `*(non documenté)*`. Ne jamais reconstituer une date ou une justification de mémoire.
