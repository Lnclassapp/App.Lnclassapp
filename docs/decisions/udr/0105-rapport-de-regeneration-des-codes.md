# UDR-0105 : Les régénérations des codes et des liens des classes se suivent dans l'écran des imports, avec leurs propres mots et sans aucun code
<!-- index
titre: Les régénérations des codes et des liens des classes se suivent dans l'écran des imports, avec leurs propres mots et sans aucun code
statut: Accepté
adr-lie: [0096](../adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md)
problematique: Rapports `school_codes` et `classroom_links` sans fichier : titres « Régénération des codes » et « Régénération des liens des classes », sous-titre avec la sélection, compteurs « Codes changés / Liens changés / Déjà changés / En erreur », erreurs par libellé ; filtre et ligne de la liste des imports ; clés de locale `by_kind`.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16 : chantier gardé et élargi aux liens des classes)* |
| **Date** | 2026-10-16 (amendée le même jour : rapport `classroom_links`) |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — RM-01, RM-02, RM-08, RM-12, RM-15, RM-17, RM-23 |
| **ADR lié** | ADR-0096 |
| **Remplacé par** | — |

---

## 1. Contexte

Après « Régénérer les codes d'établissement » ou « Régénérer les liens des classes », l'équipe attend un geste qui dure de quelques secondes à une minute. Elle doit voir qu'il avance, ce qu'il a fait et ce qui a échoué, puis le retrouver plus tard. L'écran des imports le fait déjà pour la génération des classes (UDR-0043), avec un rapport sans fichier. Ses mots (« Importés », « Ignorés (doublons) ») ne disent pas ce qui se passe ici.

## 2. Décision

- **Aucun écran nouveau** : les rapports `school_codes` et `classroom_links` s'affichent dans `teams/imports/show`, se rechargent tant qu'ils tournent, et figurent dans la liste et le filtre de `teams/imports`, comme `classrooms`.
- Les compteurs et les phases prennent **leurs propres mots** par les clés `teams.imports.status.by_kind.<kind>.*`, que `report_text` lit déjà avant les clés communes.
- Le rapport **ne montre aucun code ni lien**, ni nouveau ni ancien (ADR-0096, moteur 4).

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**

- Fichiers : `config/locales/teams/code_regenerations.fr.yml` et `config/locales/shared/common.fr.yml` (clé `import_kinds`) — Lot 0 ; `app/views/teams/imports/show.html.erb` (sous-titre) et `app/views/teams/imports/_status.html.erb` (détails sans la sélection) — Lot B.
- Titre (rapport sans fichier, branche existante) : `t("import_kinds.<kind>")` = « Régénération des codes » ou « Régénération des liens des classes ».
- Sous-titre : la branche `subtitle_without_file` existante (« %{author} · %{date} »), suivie, pour ces deux `kind`, d'une seconde ligne `text-sm text-mute` (`#code_regeneration_selection`) : « Sélection : DRENA Abidjan 1 · Lycée · Actif » ou « Sélection : Lycée Moderne de Cocody » ; « Tous les établissements » sans filtre ; pour les liens, « · année 2026-2027 » ou « · toutes les années ».
- Détails : `expected_count` seul ; la clé `selection` n'est pas listée.

**Textes** (clés `teams.imports.status.by_kind.school_codes` / `classroom_links`)

| Clé | `school_codes` | `classroom_links` |
|---|---|---|
| `statuses.importing` | « Régénération en cours » | « Régénération en cours » |
| `phases.queued` | « La régénération attend son tour. » | idem |
| `phases.validating` | « Préparation de la régénération… » | idem |
| `phases.importing` | « Changement des codes… » | « Changement des liens… » |
| `processed` | « %{count} établissement traité(s) » | « %{count} classe(s) traitée(s) » |
| `counters.imported` | « Codes changés » | « Liens changés » |
| `counters.skipped` | « Déjà changés » | « Déjà changés » |
| `counters.errors` | « En erreur » | « En erreur » |
| `counters.total` | « Établissements traités » | « Classes traitées » |
| `failed` | « La régénération s'est arrêtée avant la fin. Ce qui a été changé le reste. Les codes déjà changés le seront de nouveau si vous la relancez : une nouvelle régénération repart du début de la sélection. » ; sous le message, les compteurs et le motif de l'arrêt s'il y en a un (droit retiré, file indisponible) | idem, « liens » |
| `stalled` (rapport en cours sans avancée depuis 10 minutes) | « Cette régénération semble bloquée : elle n'a pas avancé depuis plus de 10 minutes, son traitement s'est probablement interrompu. Relancez-la depuis la liste des établissements : les codes déjà changés le seront de nouveau. » | idem, « liens » |
| `details.expected_count` | « Attendus au lancement » | idem |
| `import_kinds.<kind>` | « Régénération des codes » | « Régénération des liens des classes » |

Infobulle sur « Déjà changés » (`ui_info_tip`, sous les compteurs) : « Leur code ou leur lien avait déjà été changé depuis le lancement, un par un ou par une reprise : il n'a pas été changé une seconde fois. »

**Erreurs**

- Bloc des erreurs existant (`_import_errors`) : chemin = **libellé** (nom de l'établissement, ou « établissement · classe »), motif = celui de `write_failed`, existant (« L'enregistrement de cet élément n'a pas abouti. »), après 5 tirages refusés. Jamais de code ni de jeton.

**Tokens**

- Ceux de l'écran des imports, sans ajout.

**Comportement**

- Rechargement tant que le rapport tourne : le mécanisme existant de `show`.
- Liste `teams/imports` : la ligne affiche le titre du `kind`, l'auteur, la date ; le filtre par type les propose (il lit `ImportKind::REPORT_KINDS`).
- Lecture : toute l'équipe (policy du rapport `ManageSchoolPolicy`).

**États obligatoires**

- Vide : sans objet (un rapport n'existe qu'une fois lancé).
- Chargement : phases `queued` puis `importing` avec le compte traité.
- Erreur : statut « Échoué » (droit retiré, job bloqué libéré) avec le motif ; erreurs par objet.
- Succès : statut « Terminé », compteurs, « Fini le … ».

**Accessibilité**

- Les compteurs restent une `dl` ; l'avancement est dans la zone `aria-live="polite"` existante.
- Téléphone (390 px) : les quatre compteurs passent sur deux colonnes, comme pour les imports.

## 4. Conséquences

- Deux sens de plus des compteurs « importés / ignorés » vivent dans `import_reports` ; tout nouveau `kind` sans fichier passera par les mêmes clés `by_kind`.
- L'écran des imports est désormais aussi celui des **opérations de masse** de l'équipe. Un renommage (« Imports et opérations ») est laissé à un chantier d'interface.
