# PRD — Régénérer en une fois les codes d'établissement et les liens des classes

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Amendé le 2026-10-16 après la réponse du porteur** (« garde la régénération des codes d'établissement et de la classe ») : Q0 tranchée, chantier élargi aux liens des classes (RM-15 à RM-24). Les recommandations Q1 à Q7 et celles du [memo](memo.md#réponses-du-porteur-2026-10-16) sont appliquées, **à confirmer par le porteur**.

## 1. Contexte

Depuis l'ADR-0083, le code d'établissement ne sert plus qu'à l'inscription de la direction (ADR-0077). L'équipe ne peut le changer qu'un établissement à la fois, depuis la fiche. Depuis l'ADR-0085, une classe n'a plus de code : son seul secret d'accès est le jeton de son lien `/c/<jeton>`, que l'enseignant, la direction ou l'équipe change un par un (« Changer le lien »). Ce chantier donne à l'équipe deux gestes qui changent, en arrière-plan, les codes de tous les établissements d'une sélection (les filtres de la liste), ou les liens de toutes les classes actives de ces établissements — ou d'un seul établissement depuis sa fiche —, suivis dans un rapport.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team `admin` | Lancer la régénération des codes des établissements filtrés dans « Établissements » ; lancer celle des liens des classes de ces établissements, ou d'un établissement depuis sa fiche ; suivre les rapports | Voir les nouveaux codes ou liens dans un rapport ; annuler une régénération |
| Team `content`, `field` | Régénérer un code un par un depuis la fiche, changer le lien d'une classe (inchangé) ; lire les rapports de l'écran des imports (inchangé) | Lancer une régénération de masse : les actions n'apparaissent pas, et les routes répondent 403 |
| SchoolStaff (direction) | « Changer le lien » d'une classe de son établissement (inchangé) | Tout geste de masse ; aucune route (403) |
| Teacher | « Changer le lien » d'une de ses classes (inchangé) | Tout geste de masse ; aucune route (403) |
| Student | — | Un ancien lien régénéré le mène à l'inscription standard |

Règle d'autorisation : `Policies::School::RegenerateCodesInBulkPolicy` (nouvelle, ADR-0096, les deux gestes) : `team` dont `team_role == "admin"`, sinon `:forbidden`. Elle est revérifiée par le job au démarrage, pour l'auteur du rapport. *À confirmer par le porteur.*

## 3. Parcours utilisateur

### Chemin nominal

1. Un `admin` ouvre « Établissements » et filtre, par exemple, la DRENA « Abidjan 1 ».
2. Dans le menu « Codes » de l'en-tête, il choisit « Régénérer les codes ».
3. Une modale lui dit : « Régénérer le code de 214 établissements de la DRENA Abidjan 1 ? », avec les conséquences (les anciens codes cessent aussitôt de marcher, les directions inscrites et les enseignants ne sont pas touchés, rien n'est envoyé).
4. Il confirme. Il arrive sur le rapport « Régénération des codes », qui se recharge tant qu'il tourne.
5. À la fin, le rapport dit : 214 codes changés, 0 déjà changés, 0 en erreur.
6. Sur la fiche d'un de ces établissements, le bloc « Code d'établissement » montre le nouveau code et « Changé le 16 octobre 2026 ».

### Chemin nominal — liens des classes

1. Un `admin` filtre la DRENA « Abidjan 1 », ouvre « Codes » et choisit « Régénérer les liens des classes ».
2. La modale dit : « Régénérer le lien de 3 120 classes de la DRENA Abidjan 1 ? », « Classes de l'année 2026-2027 seulement » (avec un lien « Inclure les années passées » qui recompte), et les conséquences (les anciens liens cessent aussitôt de marcher, les élèves inscrits restent, les classes archivées ne sont pas touchées, rien n'est envoyé).
3. Il confirme et arrive sur le rapport « Régénération des liens des classes ».
4. Depuis la fiche d'un établissement, le menu ⋮ propose aussi « Régénérer les liens des classes » : la modale compte ses classes, sans nombre à taper.
5. Un élève qui ouvre un ancien lien arrive sur l'inscription standard avec l'alerte « lien invalide » ; le nouveau lien se partage depuis la page de la classe.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Sélection hors d'une seule DRENA (plusieurs DRENA, ou aucun filtre) | La modale demande de taper le nombre d'établissements ; le bouton reste actif, le serveur vérifie |
| Nombre tapé faux, ou la liste a changé depuis l'ouverture | 422 : la modale se réaffiche avec le nombre à jour et « Tapez 3 912 pour confirmer. » ; rien n'est mis en file |
| Sélection vide | L'action est désactivée dans le menu, avec la raison ; une requête forcée reçoit 422 « Aucun établissement à régénérer. » |
| Une régénération de masse déjà en cours | Redirection vers son rapport, toast d'information « Une régénération des codes est déjà en cours. » |
| Compte `content` ou `field`, ou direction | Pas d'action dans le menu ; `GET`/`POST` de la route : 403 |
| Collision de code dans un lot | Lot rejoué établissement par établissement ; les échecs restants comptent « en erreur », avec le nom de l'établissement |
| Établissement régénéré un par un pendant le job | Compté « déjà changé », son code n'est pas touché une seconde fois |
| Job interrompu | Arrêt propre : Solid Queue rejoue le job, la reprise saute ce qui a déjà changé. Processus tué net : le rapport est dit « bloqué » à l'écran après 10 minutes sans avancée ; le lancement suivant le passe « Échec » (`fail_stale`, sur `updated_at`), et relancer change de nouveau ce qui l'avait été |
| Rôle `admin` retiré avant le démarrage du job | Le rapport passe « Échec » sans rien écrire |
| Lien d'une classe changé un par un (« Changer le lien ») pendant le job | Compté « déjà changé » ; le lien posé par l'enseignant n'est pas écrasé |
| Job relancé par Solid Queue après la mort de son processus | Il reprend le même rapport ; ce qui a déjà été changé est compté « déjà changé » |
| Même rapport exécuté une seconde fois après sa fin | Rien n'est écrit |
| Classe archivée dans un établissement sélectionné | Non comptée, non touchée |
| Établissement sans classe active (depuis sa fiche) | La modale affiche « Aucune classe à régénérer. » sans bouton de confirmation |

## 4. Critères d'acceptation

```gherkin
# RM-01 — lancer sur une DRENA
Étant donné un compte équipe admin et la DRENA « Abidjan 1 » avec 3 établissements
Quand il filtre la liste sur « Abidjan 1 », choisit « Régénérer les codes » et confirme
Alors un rapport « Régénération des codes » est créé et un job est mis en file
Et il est redirigé vers ce rapport

# RM-02 — les codes changent, et seulement ceux de la sélection
Étant donné une régénération lancée sur la DRENA « Abidjan 1 »
Quand le job a fini
Alors chacun des 3 établissements de la DRENA a un nouveau code valide et distinct, et une date de changement
Et le code d'un établissement d'une autre DRENA n'a pas changé
Et le rapport compte 3 codes changés, 0 déjà changés, 0 en erreur

# RM-03 — l'ancien code ne marche plus
Étant donné un établissement actif dont le code a été régénéré en masse
Quand une direction s'inscrit avec l'ancien code
Alors elle reçoit « Code d'établissement invalide »
Et avec le nouveau code, elle s'inscrit

# RM-04 — rien d'autre ne bouge
Étant donné une régénération de masse terminée
Alors les jetons d'invitation (direction, équipe, parrainage) des établissements sont inchangés
Et les directions et enseignants rattachés le restent

# RM-05 — audit
Quand le job change le code de 3 établissements
Alors le journal d'audit a 3 lignes « school.changed » (change « code_regenerated ») avec le public_id du rapport
Et une ligne « import.run » de kind « school_codes »

# RM-06 — confirmation tapée hors d'une DRENA
Étant donné un compte équipe admin sans filtre DRENA, et 5 établissements listés
Quand il confirme en tapant « 4 »
Alors il reçoit 422 avec « Tapez 5 pour confirmer. »
Et aucun rapport n'est créé

# RM-07 — sélection vide
Étant donné un filtre qui ne donne aucun établissement
Alors l'action « Régénérer les codes » est désactivée
Et un POST direct reçoit 422 « Aucun établissement à régénérer. »

# RM-08 — une seule à la fois
Étant donné une régénération de masse en cours
Quand un admin en lance une autre
Alors il est redirigé vers le rapport de celle qui tourne, avec un toast d'information
Et aucun second rapport n'est créé

# RM-09 — droits
Étant donné un compte équipe « content », « field » ou une direction
Alors le menu « Codes » n'a pas l'action « Régénérer les codes »
Et GET et POST de la régénération de masse répondent 403

# RM-10 — reprise sans double changement
Étant donné un établissement dont le code a changé un par un après le lancement
Quand le job le rencontre
Alors son code n'est pas changé de nouveau
Et il est compté « déjà changé »

# RM-11 — collision
Étant donné un lot où un code tiré est déjà pris
Quand le job écrit le lot
Alors le lot est rejoué établissement par établissement
Et seuls ceux qui échouent après 5 tirages sont « en erreur »

# RM-12 — aucun code dans le rapport
Quand le rapport d'une régénération de masse est affiché
Alors aucun code d'établissement n'apparaît, ni dans la page ni dans `import_reports.details`

# RM-13 — date du dernier changement sur la fiche
Étant donné un établissement dont le code a été changé le 16 octobre 2026
Quand l'équipe ouvre sa fiche
Alors le bloc « Code d'établissement » affiche « Changé le 16 octobre 2026 »
Et un établissement dont le code n'a jamais changé n'affiche pas de date

# RM-14 — établissements importés après le lancement
Étant donné une régénération de masse lancée sans filtre
Quand un établissement est importé pendant le job
Alors son code n'est pas changé par le job

# RM-15 — lancer les liens des classes depuis la liste
Étant donné un compte équipe admin et la DRENA « Abidjan 1 » avec 2 établissements et 5 classes actives de l'année
Quand il filtre la liste sur « Abidjan 1 », choisit « Régénérer les liens des classes » et confirme
Alors un rapport « Régénération des liens des classes » (kind « classroom_links ») est créé, avec 5 attendus, et un job est mis en file

# RM-16 — lancer les liens des classes depuis la fiche
Étant donné un compte équipe admin sur la fiche d'un établissement qui a 3 classes actives de l'année
Quand il choisit « Régénérer les liens des classes » dans le menu ⋮ et confirme, sans taper de nombre
Alors un rapport « classroom_links » de 3 attendus est créé

# RM-17 — les liens changent, et seulement ceux de la sélection
Étant donné une régénération des liens lancée sur un établissement
Quand le job a fini
Alors chaque classe active de l'établissement a un nouveau jeton valide, distinct, et une date de changement
Et une classe archivée de l'établissement, et une classe d'un autre établissement, gardent leur jeton
Et le rapport compte les liens changés, 0 déjà changés, 0 en erreur

# RM-18 — l'ancien lien de classe ne marche plus
Étant donné une classe dont le lien a été régénéré en masse
Quand un visiteur ouvre l'ancien lien /c/<ancien jeton>
Alors il arrive sur l'inscription standard avec l'alerte « lien invalide »
Et le nouveau lien ouvre l'aperçu de la classe
Et les élèves déjà inscrits restent dans la classe

# RM-19 — année scolaire en cours
Étant donné un établissement avec une classe active de l'année et une classe active de l'an dernier
Quand la régénération est lancée avec « année en cours seulement »
Alors seul le lien de la classe de l'année change
Et sans cette option, les deux changent

# RM-20 — course avec « Changer le lien »
Étant donné une régénération des liens lancée
Quand un enseignant change le lien de sa classe avant que le job ne l'écrive
Alors le job ne change pas ce lien une seconde fois et le compte « déjà changé »

# RM-21 — idempotence et reprise
Étant donné un rapport déjà exécuté jusqu'au bout
Quand le même rapport est exécuté de nouveau
Alors aucun code ni lien ne change
Et étant donné un rapport « importing » d'un job tué
Quand Solid Queue relance le job
Alors il reprend le rapport, compte « déjà changé » ce qui avait été fait, et change le reste

# RM-22 — droits des deux gestes
Étant donné un compte équipe « content » ou « field », une direction ou un enseignant
Alors ni la liste ni la fiche n'ont les actions de masse
Et GET et POST de la régénération de masse répondent 403, pour les deux cibles

# RM-23 — aucun jeton dans le rapport ni dans l'audit
Quand une régénération des liens est terminée
Alors aucun jeton de lien n'apparaît dans `import_reports` ni dans `audit_events.metadata`
Et le journal a une ligne « school.changed » (change « classroom_link_changed ») par classe, avec le public_id du rapport

# RM-24 — unicité
Quand le job tire des codes ou des jetons
Alors aucun code d'établissement ni aucun jeton de classe n'est en double
Et un tirage qui heurte l'index unique est rejoué objet par objet
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Dtos::School::SchoolSelection` (drena, school_type, cycle, status, search, school ; `#scoped?`) ; `Dtos::School::CodeRegenerationInput` (target, selection, current_year_only, typed_count) ; `Policies::School::RegenerateCodesInBulkPolicy` ; `UseCases::School::StartCodeRegeneration` ; moteur `UseCases::School::RegenerateInBulk`, `UseCases::School::RegenerateSchoolCodes`, `UseCases::Classroom::RegenerateClassroomLinks` ; `Entities::School::RegenerationCandidate` ; `ImportKind::SCHOOL_CODE_REGENERATION`, `CLASSROOM_LINK_REGENERATION` ; `ImportReport#created_at` ; ports étendus (ADR-0096 §4.4) |
| Infrastructure | migration : deux `kind`, `classrooms.link_token_rotated_at` ; scope partagé `Orm::School.list_filtered` ; méthodes de masse de `SchoolRepository` et `ClassroomRepository` ; `ImportReportRepository#create(details:)`, `#resume` ; `AuditLogRepository#record_many` ; jobs `School::RegenerateSchoolCodesJob`, `Classroom::RegenerateClassroomLinksJob` ; `Queries::School::CodeRegenerationPreviewQuery` ; `SchoolsQuery` et `SchoolDetailQuery` lisent `school_code_rotated_at` |
| Delivery | `GET /teams/schools/code-regenerations/new` (modale ; `target`, filtres ou `school`, `all_years`), `POST /teams/schools/code-regenerations` → `Teams::CodeRegenerationsController` |
| UI | menu « Codes » de l'en-tête de la liste, entrée du menu ⋮ de la fiche et la modale (UDR-0104) ; rapports de l'écran des imports (UDR-0105) ; date du dernier changement de code sur la fiche (UDR-0106) |

## 6. Décisions rattachées

- [ADR-0096](../../decisions/adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md) — régénération en masse par deux jobs sur un moteur commun, rapports `school_codes` et `classroom_links`, contrats de ports, garde contre la course *(Accepté)*
- [UDR-0104](../../decisions/udr/0104-regenerer-les-codes-depuis-la-liste-des-etablissements.md) — actions et confirmation depuis la liste et la fiche *(Accepté)*
- [UDR-0105](../../decisions/udr/0105-rapport-de-regeneration-des-codes.md) — rapports sur l'écran des imports *(Accepté)*
- [UDR-0106](../../decisions/udr/0106-date-du-dernier-changement-de-code-sur-la-fiche.md) — date du dernier changement sur la fiche *(Accepté)*
- Amende : ADR-0057 (code en masse), ADR-0085 §4.1 (lien en masse, `link_token_rotated_at`), ADR-0039 et ADR-0056 (`kind` sans fichier de plus)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Clics pour changer les codes d'une DRENA de 200 établissements | ~800 (ouvrir la fiche, ⋮, régénérer, confirmer) | 3 (menu, action, confirmer) | |
| Durée du job pour 3 900 établissements (`PERF=1`) | — | < 60 s | 4,2 s (2026-10-16, poste partagé) |
| Durée du job pour 20 000 classes (`PERF=1`) | — | < 60 s | 33,1 s (2026-10-16, 4 cœurs partagés par une dizaine d'agents) |
| Requêtes SQL par lot de 200 | — | fixe (lecture du lot, une mise à jour, une insertion d'audit, avancement du rapport) | fixe : 132 requêtes pour 20 lots d'établissements, 611 pour 100 lots de classes (~6 par lot, savepoint compris) |
