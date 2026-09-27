# Décisions de fondation à accepter — ADR-0026 à ADR-0054, UDR-0007

> **Acceptées en bloc le 2026-09-25** par le porteur, avec trois corrections : ADR-0033 (quatre badges, Diamant = sans faute), ADR-0034 (taxonomie créée par l'équipe dès la V1, seeds hors production) et ADR-0028 (`Classroom::JoinPolicy`, sans exception). Précisions du porteur intégrées le même jour, avant l'acceptation : DRENA et établissements créés par l'équipe en V1 (ADR-0034), classes générées à la création de l'établissement (ADR-0030), imports JSON en masse et partiels pour les écoles, cours, fiches et exercices dès la V1 (ADR-0039), exemptions d'authentification de l'ADR-0028 acceptées. Voir le [journal](journal.md). La section 2 est appliquée.
>
> Rédigées le 2026-09-25 au statut `Proposé`. Chacune adopte la recommandation du [registre §3](feuille-de-route.md#3-registre-des-décisions-de-fondation). Quand la recommandation laissait un choix, c'est la variante la plus simple compatible avec les autres ADR qui a été retenue ; elle figure dans la colonne « À confirmer ».
> Les numéros 0042 (F-20) et 0046 (F-24) ne sont pas écrits : ces décisions sont retirées du plan. Les UDR-0005 et 0006 sont rédigées à part.

## 1. Relecture en 5 minutes

| ID | F | Titre court | La décision en une phrase | Remplace / amende | À confirmer |
|---|---|---|---|---|---|
| [ADR-0026](../../decisions/adr/0026-contrat-result-entites-et-dto.md) | 01, 03 | Contrat `Result` | Tout use case renvoie un `Shared::Result` (`value`, `code`, `errors`, six codes fermés), toute query un `Data`, et le domaine n'importe ni ActiveRecord ni `Repositories::` ni `Queries::`. | Remplace 0006, 0012 §3.1, 0021, 0022 §2.A-C ; amende 0014 §2.1 | champ `code` distinct de `errors` |
| [ADR-0027](../../decisions/adr/0027-contextes-bornes-et-arborescence.md) | 02 | Contextes et arborescence | Six contextes avec une table → contexte fixée, un rangement couche puis contexte, et toute personne référencée par `users.id`. | Remplace 0023, 0014 §2.2, noms de 0018 §3.2 | `teacher_schools` dans `school` ; `audit_events` dans `identity` |
| [ADR-0028](../../decisions/adr/0028-policies-de-domaine-par-use-case.md) | 04 | Policies | Une policy pure par use case, appelée avant toute écriture, qui renvoie `:forbidden` (ou `:not_found` en lecture) ; `JoinWithCode` a sa `Classroom::JoinPolicy`, qui accepte l'anonyme (correction du porteur). | Complète 0004 §3.3, 0015 | l'enseignant ne voit pas le contact de ses élèves |
| [ADR-0029](../../decisions/adr/0029-identifiants-exposes-public-id-et-slugs.md) | 05 | `public_id` et slugs | 14 caractères base58 sans préfixe hors catalogue, slug figé pour le catalogue, `bigint` partout, jamais `:id` dans une URL. | Complète 0017 ; remplace la clé nanoid de 0018 | exercices en `public_id`, pas en slug |
| [ADR-0030](../../decisions/adr/0030-une-ecole-par-enseignant-et-creation-des-classes.md) | 06 | Une école par enseignant | `teacher_schools` avec une seule ligne `primary` en V1 ; l'enseignant déclare ses classes ; `schools.cycle` explicite ; classes par défaut générées dans la transaction de l'établissement, par slug ; gestion par l'équipe (V1) puis la direction (V2). | Remplace 0004 §2 et §3.1 | auto-déclaration sans validation ; direction créatrice dès la V2 ; plan de génération de l'ancien, corrigé |
| [ADR-0031](../../decisions/adr/0031-second-facteur-totp-pour-l-equipe.md) | 07 | TOTP équipe | TOTP obligatoire à chaque session `team`, 10 codes de secours, réinitialisation par un autre membre. | Complète 0025 comp. 5 | pas de « se souvenir de cet appareil » |
| [ADR-0032](../../decisions/adr/0032-recuperation-assistee-du-pin.md) | 08 | Récupération du PIN | Code de 8 chiffres émis par l'enseignant de la classe ou l'équipe, valable 15 min, 5 essais, qui coupe toutes les sessions. | Complète 0025 comp. 6 ; amende 0002 §4 | 8 chiffres ; tout élève d'une classe déclarée |
| [ADR-0033](../../decisions/adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) | 10, 11 | Badges et seuils | Bronze 50, Argent 70, Or 80, Diamant 100 (correction du porteur), un badge par exercice qui ne monte que strictement ; seuils nommés `PASS`/`MASTERY`/`GOLD`/`PERFECT` ; avancement et score séparés. | Remplace 0008 §3 (badges) et §4 | or à 100 % ; pas d'historique des badges |
| [ADR-0034](../../decisions/adr/0034-reprise-des-donnees-et-referentiel-seede.md) | 12 | Reprise des données | Aucune reprise de l'ancienne base ; niveaux, séries, `level_series`, matières, DRENA et établissements créés par l'équipe dès la V1 (corrections du porteur) ; aucun seed métier en production. | — | **aucune donnée réelle (préalable)** ; `2nd` ou `2nde` ; séries de seconde ; liste des matières |
| [ADR-0035](../../decisions/adr/0035-cycle-de-vie-et-propriete-du-contenu.md) | 13 | Cycle de vie du contenu | `draft`/`published`/`archived` sur cours, fiches, exercices, lu par policy (404 hors équipe) ; le contenu appartient à la plateforme, l'auteur n'est qu'une trace. | Complète 0022 §2.A | pas de retour en brouillon ; tout `team` modifie tout |
| [ADR-0036](../../decisions/adr/0036-suppression-archivage-et-anonymisation.md) | 14 | Suppression et archivage | FK `restrict` par défaut ; contenu publié archivé, taxonomie référencée non supprimable, comptes anonymisés, classes archivées. | Complète et amende 0005 (`nullify` → `restrict`) ; complète 0016 | anonymisation ≠ effacement total |
| [ADR-0037](../../decisions/adr/0037-nom-et-prenoms-en-deux-champs.md) | 15 | Nom et prénoms | Deux champs, `squish` seul, jamais de changement de casse ni de `titleize`. | — | longueurs 50/80 ; chiffres refusés |
| [ADR-0038](../../decisions/adr/0038-comptes-de-l-equipe-et-sous-roles.md) | 16 | Équipe et sous-rôles | `team` créé seulement par invitation ; `team_role` `admin`/`content`/`field` posé dès la V1 ; matrice appliquée en V4 ; TOTP pour tous. | Complète 0025 comp. 5 (C-20) | les trois sous-rôles et la matrice ; invitation de 72 h |
| [ADR-0039](../../decisions/adr/0039-format-d-import-du-contenu.md) | 17 | Import du contenu | Quatre formats JSON versionnés (écoles, cours en arbre, fiches, exercices) ; job Solid Queue ; validation complète, puis import partiel atomique par élément racine ; `insert_all` par lots ; résolution par slug sans création ; en brouillon ; rapport à quatre compteurs. | Remplace 0012 §3.3, 0020 sauf §2.1 et §2.2 | **import partiel** (arbitrage du porteur) ; doublons ignorés ; limites de taille ; import en brouillon |
| [ADR-0040](../../decisions/adr/0040-classe-principale-unique-de-l-eleve.md) | 18 | Classe principale | Une classe principale active par élève (index partiel), une seule classe active jusqu'à la V3. | Amende 0003 §2 et §4 | pas de cours du soir avant la V3 |
| [ADR-0041](../../decisions/adr/0041-vie-d-une-classe-annee-scolaire-et-code.md) | 19 | Vie d'une classe | Année scolaire sur la classe, archivage annuel en lecture seule, code révocable et régénérable, plafond d'effectif. | — | plafond 80 (max 150) ; rentrée au 1er septembre |
| [ADR-0043](../../decisions/adr/0043-remediation-declenchee-par-la-cloture.md) | 21 | Remédiation | Lacunes ouvertes et résolues par la seule clôture ; session `kind: remediation` ; une lacune en attente par élève et par fiche. | Remplace 0018 §3 | unicité par fiche ; réutilisation d'exercices |
| [ADR-0044](../../decisions/adr/0044-rattachement-de-la-direction-par-invitation.md) | 22 | Direction | Invitation par l'équipe ou un membre de l'école ; une école par membre ; quatre fonctions ; un proviseur actif ; TOTP obligatoire. | — (corrige le glossaire §1) | tout membre invite ; TOTP pour la direction |
| [ADR-0045](../../decisions/adr/0045-annonces-publication-programmee-et-audience.md) | 23 | Annonces V6a | Job de publication toutes les 5 min, audience `school_admins`, `show` filtré, rejets en base, pièces jointes validées sur le bucket. | — | pas d'audience `teams` ; texte simple ; tailles |
| [ADR-0047](../../decisions/adr/0047-stockage-objet-s3-sur-railway.md) | 25 | Stockage objet | Bucket Railway par environnement dès la V0, service S3 d'Active Storage, fichiers servis en mode proxy, CSP inchangée. | Complète 0010 | bucket dès la V0 ; proxy ; pas de sauvegarde |
| [ADR-0048](../../decisions/adr/0048-statuts-d-assignation-active-et-archived.md) | 26 | Statuts d'assignation | `active`/`archived`, `assigned_by_id` → `users`, nouvelle ligne à la réassignation, session rattachée à son assignation. | Remplace 0016 §2, 0007 §5 | nouvelle ligne plutôt que réactivation ; `ExamSubject` retiré |
| [ADR-0050](../../decisions/adr/0050-authentification-et-session.md) | 28 | Authentification | Contact normalisé `0[157]` + 8 chiffres, `Identity::Authenticate`, `reset_session` + table `sessions`, verrouillage 5/10/20 échecs, `audit_events`. | Remplace 0002 §3.2, §3.3, §5 (et Wave au §1) ; complète 0025 comp. 1 à 4 | paliers de verrouillage ; durées 30 j / 12 h |
| [ADR-0053](../../decisions/adr/0053-validation-collaborative-requalifiee.md) | 33 | Validation collaborative | Rien avant une décision produit (V8), et aucun label « Conforme au programme ». | Remplace 0011 | retrait du bandeau dès la V1 |
| [ADR-0054](../../decisions/adr/0054-moteur-d-evaluation-soumission-et-cloture.md) | 34 | Moteur d'évaluation | Soumission corrigée par identifiants, tentative unique et immuable, clôture seule responsable du score, du badge et de la lacune, `essential_id` obligatoire. | Remplace 0008 §3 et §6 | pas d'abandon automatique ; `bigint[]` plutôt que `jsonb` |
| [UDR-0007](../../decisions/udr/0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) | 32 | Vocabulaire | « Fiche essentielle », « Exercice », « Session », « Tentative », « Proposition », badges Bronze/Argent/Or/Diamant ; jamais « Quiz », « Habileté ». | Vocabulaire des UDR-0001 et 0003 | « Fiche essentielle » plutôt que « Habileté » ; « Session » pour `ExerciseSession` |

## 2. Modifications à appliquer à l'acceptation

### 2.1 Statuts à passer à `Accepté` (date de l'acceptation)

- Dans chaque fichier : ADR-0026 à 0041, 0043, 0044, 0045, 0047, 0048, 0050, 0053, 0054 ; UDR-0007.
- Dans l'index [`adr/README.md`](../../decisions/adr/README.md) : colonne Statut des mêmes lignes (retirer « remplacerait » au profit de « remplace »), et retrait de l'encadré « Proposé » en tête de l'index.
- Dans l'index [`udr/README.md`](../../decisions/udr/README.md) : ligne UDR-0007 (tenu par l'agent des UDR).

### 2.2 Anciens ADR à marquer (ligne `Remplacé par`, encadré d'avertissement en tête, ligne dans « Décisions remplacées » de l'index)

| Ancien | Marquage | Par |
|---|---|---|
| 0006 | **Remplacé** | 0026 |
| 0011 | **Remplacé** | 0053 |
| 0012 | **Remplacé** (§3.1 par 0026, §3.3 par 0039) | 0026, 0039 |
| 0020 | **Remplacé partiellement** (tout sauf §2.1 et §2.2) | 0039 |
| 0021 | **Remplacé** | 0026 |
| 0023 | **Remplacé** | 0027 |
| 0002 | Remplacé partiellement : §3.2, §3.3, §5, mention de Wave au §1 ; amendé §4 | 0050 ; 0032 |
| 0003 | Amendé §2 et §4 | 0040 |
| 0004 | Remplacé partiellement : §2 (création de classe), §3.1 ; complété §3.3 | 0030 ; 0028 |
| 0005 | Complété et amendé (`on_delete: :nullify` → `:restrict`) | 0036 |
| 0007 | Remplacé partiellement : §5 (statuts, types assignables) | 0048 |
| 0008 | Remplacé partiellement : §3 (badges → 0033, statuts et correction → 0054), §4 (échelles), §6 | 0033, 0054 |
| 0010 | Complété (stockage de fichiers) | 0047 |
| 0014 | Remplacé partiellement : §2.2 ; amendé §2.1 | 0027 ; 0026 |
| 0015 | Complété (test de refus obligatoire) | 0028 |
| 0016 | Remplacé partiellement : §2 (statuts, réactivation, `teacher_id`) ; complété (archivage étendu) | 0048 ; 0036, 0041 |
| 0017 | Complété | 0029 |
| 0018 | Remplacé partiellement : §3 ; noms du §3.2 ; clé nanoid | 0043 ; 0027 ; 0029 |
| 0022 | Remplacé partiellement : §2.A à §2.C ; complété §2.A (statut) | 0026 ; 0035 |
| 0025 | Complété : comp. 1 à 4, 5, 6 | 0050, 0031 et 0038, 0032 |
| UDR-0001 | Vocabulaire « essentiels (habiletés) » remplacé | UDR-0007 |
| UDR-0003 | Vocabulaire « Quiz interactif » et badge « Diamant » remplacés | UDR-0007, ADR-0033 |

### 2.3 Feuille de route

- **§3, colonne Statut** : passer à « **Accepté** AAAA-MM-JJ », avec le lien vers le fichier, les lignes F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-08, F-10, F-11, F-12, F-13, F-14, F-15, F-16, F-17, F-18, F-19, F-21, F-22, F-23, F-25, F-26, F-28, F-32, F-33, F-34. F-09 et F-31 (UDR-0005, 0006) suivent leur propre acceptation.
- **§4** : marquer fermées C-01, C-02, C-03, C-04, C-06, C-07, C-08, C-10, C-11, C-12, C-14, C-15, C-16, C-17, C-18, C-19, C-20, C-21, C-22, C-23, C-24, C-25, C-26, C-27, C-28, C-29, C-30, C-33, C-34, C-37 (temps réel), C-39, C-40, C-42, C-43, C-44, C-45, C-46, C-47, C-48, C-49.

### 2.4 Documents de rang 5 à corriger ensuite

- [`guide/glossaire.md`](../../guide/glossaire.md) :
  - §1 : rôles sans `parent`, `SchoolRole` remplacé par quatre fonctions ;
  - §2 : `TeacherSchool` avec une principale ;
  - §4 : statuts, `selected_answer_ids`, lacune en `bigint` ;
  - §5 : `ClassroomAssignment` à deux statuts, sans `ExamSubject` ;
  - §6 : audiences des annonces ;
  - §7 : `public_id` sans préfixe.
- [`guide/architecture.md`](../../guide/architecture.md) : §2.7 (moteur d'évaluation, or), §5 (DRENA dans `school`).
- [`blueprints/result.md`](../../blueprints/result.md) et [`blueprints/policy.md`](../../blueprints/policy.md) : réécrits sur `Shared::Result` et `Policies::<Contexte>::…`.
- [`securite.md`](securite.md) : trous d'autorisation fermés par l'ADR-0028, C-21 fermée par l'ADR-0050.
