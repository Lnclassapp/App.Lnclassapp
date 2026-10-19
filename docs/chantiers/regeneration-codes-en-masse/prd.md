# PRD — Régénérer en une fois le code de plusieurs établissements

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.
>
> **Écrit sous les recommandations du [memo](memo.md) (Q0 à Q7), en attente du porteur.** Si Q0 conclut à l'abandon, ce PRD n'est pas exécuté.

## 1. Contexte

Depuis l'ADR-0083, le code d'établissement ne sert plus qu'à l'inscription de la direction (ADR-0077). L'équipe ne peut le changer qu'un établissement à la fois, depuis la fiche. Ce chantier lui donne un geste qui change, en arrière-plan, le code de tous les établissements d'une sélection (les filtres de la liste), suivi dans un rapport.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team `admin` | Lancer la régénération des codes des établissements filtrés dans « Établissements » ; suivre le rapport | Voir les nouveaux codes dans le rapport ; annuler une régénération |
| Team `content`, `field` | Régénérer un code un par un depuis la fiche (inchangé) ; lire les rapports de l'écran des imports (inchangé) | Lancer une régénération de masse : l'action n'apparaît pas, et la route répond 403 |
| SchoolStaff (direction) | Rien de nouveau | Tout geste de masse ; aucune route |
| Teacher, Student | Rien de nouveau | — |

Règle d'autorisation : `Policies::School::RegenerateSchoolCodesPolicy` (nouvelle, ADR-0096) : `team` dont `team_role == "admin"`, sinon `:forbidden`. Elle est revérifiée par le job au démarrage, pour l'auteur du rapport.

## 3. Parcours utilisateur

### Chemin nominal

1. Un `admin` ouvre « Établissements » et filtre, par exemple, la DRENA « Abidjan 1 ».
2. Dans le menu « Codes » de l'en-tête, il choisit « Régénérer les codes ».
3. Une modale lui dit : « Régénérer le code de 214 établissements de la DRENA Abidjan 1 ? », avec les conséquences (les anciens codes cessent aussitôt de marcher, les directions inscrites et les enseignants ne sont pas touchés, rien n'est envoyé).
4. Il confirme. Il arrive sur le rapport « Régénération des codes », qui se recharge tant qu'il tourne.
5. À la fin, le rapport dit : 214 codes changés, 0 déjà changés, 0 en erreur.
6. Sur la fiche d'un de ces établissements, le bloc « Code d'établissement » montre le nouveau code et « Changé le 16 octobre 2026 ».

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
| Job interrompu | Le lancement suivant libère le rapport bloqué depuis 10 minutes (`fail_stale`) ; il est marqué « Échec » |
| Rôle `admin` retiré avant le démarrage du job | Le rapport passe « Échec » sans rien écrire |

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
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Dtos::School::SchoolSelection` (drena, school_type, cycle, status, search ; `#single_drena?`) ; `Dtos::School::CodeRegenerationInput` (selection, typed_count) ; `Policies::School::RegenerateSchoolCodesPolicy` ; `UseCases::School::StartSchoolCodeRegeneration` ; `UseCases::School::RegenerateSchoolCodes` ; `Entities::Catalog::ImportKind::SCHOOL_CODE_REGENERATION = "school_codes"` ; ports étendus (ADR-0096 §4.4) |
| Infrastructure | migration : `school_codes` dans `import_reports_kind_values` ; scope partagé `Orm::School.list_filtered` ; `SchoolRepository#count_for_code_regeneration`, `#code_regeneration_batch`, `#replace_school_codes` ; `ImportReportRepository#create(details:)` ; job `School::RegenerateSchoolCodesJob` ; `SchoolsQuery` et `SchoolDetailQuery` lisent `school_code_rotated_at` |
| Delivery | `GET /teams/schools/code-regenerations/new` (modale, filtres en paramètres), `POST /teams/schools/code-regenerations` → `Teams::SchoolCodeRegenerationsController` |
| UI | menu « Codes » de l'en-tête de la liste et sa modale (UDR-0104) ; rapport de l'écran des imports (UDR-0105) ; date du dernier changement sur la fiche (UDR-0106) |

## 6. Décisions rattachées

- [ADR-0096](../../decisions/adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md) — régénération en masse par un job, rapport `school_codes`, contrats de ports *(Proposé)*
- [UDR-0104](../../decisions/udr/0104-regenerer-les-codes-depuis-la-liste-des-etablissements.md) — action et confirmation depuis la liste *(Proposé)*
- [UDR-0105](../../decisions/udr/0105-rapport-de-regeneration-des-codes.md) — rapport sur l'écran des imports *(Proposé)*
- [UDR-0106](../../decisions/udr/0106-date-du-dernier-changement-de-code-sur-la-fiche.md) — date du dernier changement sur la fiche *(Proposé)*
- Amende, si acceptés : ADR-0057 (régénération en masse), ADR-0039 et ADR-0056 (`kind` de rapport sans fichier de plus)

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Clics pour changer les codes d'une DRENA de 200 établissements | ~800 (ouvrir la fiche, ⋮, régénérer, confirmer) | 3 (menu, action, confirmer) | |
| Durée du job pour 3 900 établissements (`PERF=1`) | — | < 60 s | |
| Requêtes SQL par lot de 200 | — | fixe (lecture du lot, une mise à jour, une insertion d'audit, avancement du rapport) | |
