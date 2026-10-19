# UDR-0103 : Historique de l'élève — « Mes classes » dit la période de chaque classe et marque la classe actuelle
<!-- index
titre: Historique élève : période de chaque classe, classe actuelle marquée
statut: Proposé
adr-lie: [0095](../adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md)
problematique: Élève qui a changé de classe dans l'année : deux classes de la même année se distinguent par leur période (« depuis le 12 oct. » / « du 15 sept. au 12 oct. ») ; la classe actuelle porte le badge « Actuelle ». Amende UDR-0090 §3.3
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/changement-etablissement-eleve`](../../chantiers/changement-etablissement-eleve/memo.md) |
| **ADR lié** | [ADR-0095](../adr/0095-l-eleve-change-lui-meme-de-classe-et-d-etablissement.md) |
| **Amende** | [UDR-0090](0090-historique-eleve-carte-bleue-exercices-par-mois.md) §3.3 (« Mes classes », contenu inchangé) |
| **Remplacé par** | — |

---

## 1. Contexte

« Mes classes » (UDR-0090 §3.3) liste chaque classe avec son nom, « niveau · établissement » et l'année scolaire. Tant qu'un élève n'avait qu'une classe par an, l'année suffisait. Dès qu'il change de classe en cours d'année (ADR-0095), deux lignes portent « 2026-2027 » : il ne sait plus laquelle est la sienne aujourd'hui, ni quand il a changé.

## 2. Décision

> **Chaque ligne de « Mes classes » dit sa période à la place de l'année scolaire seule, et la classe actuelle porte le badge « Actuelle ». L'ordre reste du plus récent au plus ancien.**

Pourquoi pas de lien entre une classe et ses exercices : l'historique n'a ni filtre ni ligne cliquable (UDR-0090), et le porteur l'a voulu ainsi.

## 3. Règles d'implémentation

### 3.1 Données

- `Queries::Classroom::StudentArchiveQuery::ClassroomRow` gagne `joined_at` et `left_at` (colonnes de `classroom_students`). La requête reste unique pour les classes ; l'ordre `joined_at DESC, id DESC` est inchangé.
- Classe actuelle : `left_at` nul **et** classe active (le statut de la classe s'ajoute aux colonnes lues).

### 3.2 Ligne d'une classe

- Structure inchangée (pastille `academic-cap`, nom en `font-display font-bold`, « niveau · établissement » en `text-sm text-mute`).
- À droite du nom, à la place de l'année scolaire, en `text-sm text-mute tabular-nums` :
  - classe actuelle : « depuis le %{date} » ;
  - classe quittée : « du %{début} au %{fin} » ;
  - classe non quittée mais archivée : « depuis le %{date} » sans badge.
- Dates : format court localisé (`l(date, format: :short_day_month)`, « 12 oct. »), complété de l'année quand elle diffère de l'année en cours (« 15 sept. 2025 »).
- L'année scolaire passe sous le nom, à la fin de la ligne « niveau · établissement » : « %{niveau} · %{établissement} · %{année} ».
- Classe actuelle : `ui_badge "Actuelle", tone: :brand, size: :sm` après le nom ; le nom ne se tronque pas à cause du badge (passage à la ligne au téléphone, comme UDR-0081 §3.7 amendée).

### 3.3 Tokens

- `ink`, `mute`, `brand`, `brand-soft`, `brand-strong`, `line` ; aucune valeur en dur.

### 3.4 États obligatoires

- Une seule classe (actuelle).
- Deux classes la même année (une quittée, une actuelle), dans deux établissements.
- Aucune classe actuelle (élève retiré, ou classe archivée).
- Liste longue (« Voir plus » d'`ui_reveal_more`, inchangé).
- Thème sombre ; 390 px et 1 280 px.

### 3.5 Accessibilité

- La période est du texte, lue avec la ligne ; aucune information portée par la seule couleur : « Actuelle » est un mot.
- Ordre de lecture : nom, badge, période, détail.

## 4. Conséquences

- Seule la carte « Mes classes » change ; la carte bleue et « Mes exercices terminés » sont intactes.
- Tests à relire : `test/infrastructure/queries/classroom/student_archive_query_test.rb`, `test/system/classroom/student_archive_test.rb`.
