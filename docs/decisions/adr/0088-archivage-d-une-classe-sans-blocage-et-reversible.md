# ADR-0088 : Archivage d'une classe — sans blocage, réversible, lectures filtrées
<!-- index
titre: Archivage d'une classe : sans blocage, réversible, lectures filtrées
statut: Accepté
problematique: Après l'import qui donne la 6ème à la Tle à tous (ADR-0087), la direction et l'équipe doivent pouvoir écarter les classes en trop, même peuplées, sans rien perdre ni casser les écrans des élèves et des enseignants.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-10 |
| **Chantier** | [`docs/chantiers/archivage-classes`](../../chantiers/archivage-classes/memo.md) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Une classe a déjà `status` (`active` / `archived`) et `archived_at` (contrainte : l'un si et seulement si l'autre), et la plupart des lectures élève, enseignant et direction ne gardent que les classes actives. Mais aucun cas d'usage n'écrit l'archivage : le seul retrait possible est le « − », qui ne supprime qu'une classe jamais utilisée. Le porteur veut pouvoir archiver une classe quel que soit son contenu, avec confirmation.

## 2. Moteurs de décision

- Ne perdre aucune donnée et pouvoir revenir en arrière.
- Un seul chemin d'écriture, tracé.
- Réutiliser les filtres `active` déjà en place plutôt que d'en répandre de nouveaux.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — refuser si élèves, enseignants ou assignations | prudent | refusé par le porteur : bloque exactement les classes en trop une fois peuplées |
| B — archiver sans toucher aux adhésions ni assignations, réversible | simple, rien de perdu | retenue |
| C — fermer les adhésions à l'archivage | libère les élèves | irréversible de fait, la restauration demanderait de tout réinscrire |

## 4. Décision

> **Nous archivons une classe en posant `status = archived` et `archived_at`, sans toucher aux adhésions, aux rattachements d'enseignants ni aux assignations. La restauration remet `active` et efface `archived_at`. Les adhésions étant intactes, tout revient comme avant ; le lien d'inscription refuse les nouveaux élèves tant que la classe est archivée. Trois cas d'usage (archiver une classe, restaurer une classe, archiver les classes actives d'un niveau) utilisent la politique « structure d'établissement » existante. Les listes gardent une classe archivée visible 7 jours après `archived_at`, puis la masquent derrière un paramètre « archives ».**

## 5. Conséquences

### 🟢 Positives

- Aucune migration, aucune donnée perdue.
- La restauration est exacte, sans ressaisie.
- Les filtres `active` existants font disparaître la classe des écrans élève et enseignant.

### 🔴 Coûts consentis

- Une classe archivée garde des adhésions ouvertes : un élève dont c'est l'unique classe tombe sur « Choisis ta classe » ; son adhésion n'est fermée qu'à son prochain choix de classe (comportement existant de `JoinAsStudent`).
- Quelques lectures ne filtrent pas encore et doivent le faire : compteurs de niveau de la fiche établissement, libellé de classe de l'en-tête élève.
- Le « − » compte encore les classes archivées pour trouver la dernière classe d'un niveau (hors périmètre).
- Archiver à tort avec des élèves a un effet immédiat sur leurs écrans ; seule la confirmation protège.

## 6. Notes d'implémentation

- Patron : `UseCases::Classroom::RemoveLevelClassroom` (établissement lu, politique, classe de l'année en cours, transaction, audit).
- Audit : `school.changed` avec `change: classroom_archived | classroom_restored | level_archived` (nombre de classes pour le niveau).
- Écriture atomique avec verrou de ligne ; archiver une classe déjà archivée → `:conflict` (`already_archived`).
- Écrans concernés : fiche établissement de l'équipe, écrans de la direction, bloc « Classes par niveau », en-tête élève.

## 7. Comment vérifier que la décision est respectée

Tests de domaine et d'infrastructure des trois cas d'usage (adhésions et assignations inchangées, droits, conflit) et tests des lectures par rôle ; un test d'architecture existant exige déjà une politique injectée dans chaque cas d'usage.
