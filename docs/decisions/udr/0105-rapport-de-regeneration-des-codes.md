# UDR-0105 : La régénération des codes se suit dans l'écran des imports, avec ses propres mots et sans aucun code
<!-- index
titre: La régénération des codes se suit dans l'écran des imports, avec ses propres mots et sans aucun code
statut: Proposé
adr-lie: [0096](../adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md)
problematique: Rapport `school_codes` sans fichier : titre « Régénération des codes », sous-titre avec la sélection, compteurs « Codes changés / Déjà changés / En erreur / Attendus », erreurs par nom d'établissement ; filtre et ligne de la liste des imports ; seules des clés de locale `by_kind.school_codes` et un sous-titre.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — RM-01, RM-02, RM-08, RM-12 |
| **ADR lié** | ADR-0096 |
| **Remplacé par** | — |

---

## 1. Contexte

Après « Régénérer les codes », l'équipe attend un geste qui dure de quelques secondes à une minute. Elle doit voir qu'il avance, ce qu'il a fait et ce qui a échoué, puis le retrouver plus tard. L'écran des imports le fait déjà pour la génération des classes (UDR-0043), avec un rapport sans fichier. Ses mots (« Importés », « Ignorés (doublons) ») ne disent pas ce qui se passe ici.

## 2. Décision

- **Aucun écran nouveau** : le rapport `school_codes` s'affiche dans `teams/imports/show`, se recharge tant qu'il tourne, et figure dans la liste et le filtre de `teams/imports`, comme `classrooms`.
- Les compteurs et les phases prennent **leurs propres mots** par les clés `teams.imports.status.by_kind.school_codes.*`, que `report_text` lit déjà avant les clés communes.
- Le rapport **ne montre aucun code**, ni nouveau ni ancien : ni dans les compteurs, ni dans les erreurs, ni dans les détails (ADR-0096, moteur 4).

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**

- Fichiers : `config/locales/teams/imports.fr.yml` et `config/locales/shared/common.fr.yml` (clé `import_kinds`) — **Lot 0** ; `app/views/teams/imports/show.html.erb` (sous-titre) — Lot B.
- Titre (rapport sans fichier, branche existante `import_kind == false`) : `t("import_kinds.school_codes")` = « Régénération des codes ».
- Onglet : « Régénération des codes ».
- Sous-titre : la branche `subtitle_without_file` existante (« %{author} · %{date} »), suivie, pour `school_codes` seulement, d'une seconde ligne `text-sm text-mute` : « Sélection : DRENA Abidjan 1 · Lycée · Actif » à partir de `details["selection"]` (libellés traduits ; « Tous les établissements » sans filtre) et « 214 attendus ».

**Textes** (clés `teams.imports.status.by_kind.school_codes`)

| Clé | Texte |
|---|---|
| `phases.queued` | « La régénération attend son tour. » |
| `phases.importing` | « Changement des codes… » |
| `processed` | « %{count} établissement traité » / « %{count} établissements traités » |
| `counters.imported` | « Codes changés » |
| `counters.skipped` | « Déjà changés » |
| `counters.errors` | « En erreur » |
| `counters.total` | « Total » |
| `details.expected_count` | « Établissements attendus » |
| `import_kinds.school_codes` | « Régénération des codes » |

Infobulle sur « Déjà changés » (`ui_info_tip`) : « Leur code avait déjà été changé depuis le lancement, un par un ou par une reprise : il n'a pas été changé une seconde fois. »

**Erreurs**

- Bloc des erreurs existant (`_import_errors`) : chemin = **nom de l'établissement**, motif = « Aucun code libre après 5 essais. » (`write_failed`). Jamais de code.

**Tokens**

- Ceux de l'écran des imports, sans ajout : `text-ink`, `text-mute`, badges de statut existants (`import_status_tone`).

**Comportement**

- Rechargement tant que le rapport tourne : le mécanisme existant de `show` (statuts `queued`, `importing`).
- Liste `teams/imports` : la ligne affiche « Régénération des codes », l'auteur, la date ; le filtre par type propose « Régénération des codes » (il lit `ImportKind::REPORT_KINDS`).
- Lecture : toute l'équipe (policy du rapport `ManageSchoolPolicy`).

**États obligatoires**

- Vide : sans objet (un rapport n'existe qu'une fois lancé).
- Chargement : phases `queued` puis `importing` avec le compte traité.
- Erreur : statut « Échec » (droit retiré, job bloqué libéré) avec le motif existant ; erreurs par établissement.
- Succès : statut « Terminé », compteurs, « Fini le … ».

**Accessibilité**

- Les compteurs restent une `dl` (terme, valeur) ; l'avancement est dans la zone `aria-live="polite"` existante.
- Téléphone (390 px) : les quatre compteurs passent sur deux colonnes, comme pour les imports.

## 4. Conséquences

- Un troisième sens des compteurs « importés / ignorés » vit dans `import_reports` ; tout nouveau `kind` sans fichier passera par les mêmes clés `by_kind`.
- L'écran des imports est désormais aussi celui des **opérations de masse** de l'équipe. Un renommage (« Imports et opérations ») est laissé à un chantier d'interface.
