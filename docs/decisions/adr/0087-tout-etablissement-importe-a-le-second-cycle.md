# ADR-0087 : Tout établissement importé reçoit le second cycle
<!-- index
titre: Tout établissement importé reçoit le second cycle
statut: Accepté — *amende 0030 et 0039 (cycle déduit du nom)*
problematique: Un établissement importé au premier cycle seul (mot « collège » dans le nom, ou colonne `cycle` du fichier) n'avait ni 2nde, ni 1ère, ni Tle ; le terrain montre que beaucoup d'entre eux en ont.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-09 |
| **Chantier** | [`docs/chantiers/import-second-cycle-force`](../../chantiers/import-second-cycle-force/memo.md) |
| **Remplace** | — *(amende ADR-0030 et ADR-0039 sur le cycle)* |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0030 déduisait le cycle du nom (« collège » → `first`) et un établissement `first` ne recevait que la 6ème à la 3ème. Sur le fichier de 2026, de nombreux établissements nommés « collège » ont en réalité un second cycle : leurs classes manquent et rien ne les recrée (modifier le cycle ne régénère jamais les classes).

## 2. Moteurs de décision

- Une classe en trop s'archive en un clic ; une classe manquante se recrée à la main, une à une.
- Le nom d'un établissement ne dit pas ses niveaux.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — garder la déduction par le nom | décision d'origine | fausse sur le terrain |
| B — tout `both` à l'import, l'équipe et la direction archivent le surplus | simple, réversible | retenue |

## 4. Décision

> **Nous donnons le cycle `both` à tout établissement importé et générons la 6ème à la Tle, quel que soit son nom ou la colonne `cycle` du fichier (désormais ignorée). La direction et l'équipe archiveront après coup les classes en trop ; une classe qui a des élèves ne s'archive pas.**

## 5. Conséquences

### 🟢 Positives

- Aucun établissement ne manque de classes de second cycle.
- `School.cycle_for` et la règle du mot « collège » disparaissent.

### 🔴 Coûts consentis

- Des collèges auront des classes de 2nde à Tle inutiles tant qu'elles ne sont pas archivées : l'archivage est un chantier de suivi (aucun cas d'usage aujourd'hui).
- Le champ `cycle` reste modifiable sur l'établissement (`first` reste une valeur valide) ; seul l'import l'ignore.

## 6. Notes d'implémentation

- `UseCases::School::ImportSchools::CYCLE = "both"`, `app/domain/use_cases/school/import_schools.rb`.
- Réparation unique des établissements déjà importés : `UseCases::School::GrantSecondCycle`, lancée par `bin/rails schools:grant_second_cycle` (rejouable, n'ajoute que les classes du second cycle, jamais celles du premier cycle retirées à la main). Exemptée de politique d'accès dans `test/architecture/use_case_policies_test.rb` (aucun acteur, lancée en console).

## 7. Comment vérifier que la décision est respectée

`test/domain/use_cases/school/import_schools_test.rb` (« every imported school gets both cycles ») et `grant_second_cycle_test.rb`.
