# Memo — La vie de la classe : la modifier, la lire, la fermer pour de bon

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (Lots 0 et A, PR `feature/vie-de-la-classe`) ; Lot B retiré ; Lot C en correctif séparé (`fix/classe-archivee-sous-pages`) |
| **Ouvert le** | 2026-10-16 |
| **Branche** | `docs/cadrage-vie-de-la-classe` (cadrage, docs seules) ; le code passera par `feature/vie-de-la-classe` et une PR |
| **Programme** | `refonte-application`, vague V3 ([feuille de route §5](../refonte-application/feuille-de-route.md#v3--suivi-pédagogique-enseignant)) |

---

## Le problème

Une classe, une fois créée, ne se corrige plus. Son nom vient du barème (« 6ème 3 ») ou d'une saisie de l'équipe, son plafond vaut 80 élèves : aucun écran ne permet de les changer. Un établissement qui nomme ses classes « 6ème A, B, C » garde des noms qu'il ne reconnaît pas, et une classe de 95 élèves sur le terrain se ferme au 81ᵉ. C'est CL-02, la seule feature d'inventaire que la V1 n'a pas livrée (déplacée en V3 le 2026-09-28).

Deux restes complètent le chantier : l'enseignant ne voit pas les chiffres de sa classe que la direction voit déjà (CL-14), et une classe archivée garde des sous-pages lisibles par ses membres (dette de [`archivage-classes`](../archivage-classes/journal.md)).

## Inventaire au 2026-10-16

Relevé dans le code de `origin/Develop` (d1226437). La feuille de route date du 2026-09-28 : depuis, cinq chantiers ont livré une bonne partie de ce qu'elle rangeait ici.

| Besoin | État | Où | Dans le périmètre ? |
|---|---|---|---|
| **Modifier une classe** (CL-02) | ❌ Absent. Seule la création par l'équipe saisit le nom et le plafond (`Teams::SchoolClassroomsController`, `CreateClassroom`, UDR-0031) ; le « + » nomme au barème (ADR-0059). Aucun use case, port, route ni écran ne les change ensuite | — | **Oui** (Lot A) |
| **Archiver, restaurer une classe, archiver un niveau** (CL-03) | ✅ Livré le 2026-10-10 : équipe et direction, menu ⋮ des cartes, confirmation chiffrée, rien de supprimé | [`archivage-classes`](../archivage-classes/memo.md), ADR-0088, UDR-0083 | Non |
| Retirer la dernière classe jamais servie | ✅ Livré (« − ») | [`classes-par-niveau`](../classes-par-niveau/memo.md), ADR-0059 | Non |
| Sous-pages d'une classe archivée | ⚠️ La page principale répond 404, mais cours, essentiel, suivi d'un exercice et jours de séance restent lisibles par ses membres | `classroom/classroom_courses`, `classroom_essentials`, `assignment_follow_ups`, `session_days` ; dette du [journal d'`archivage-classes`](../archivage-classes/journal.md) | **Oui** (Lot C) |
| Code d'adhésion révocable et régénérable (ADR-0041) | ✅ Remplacé par le lien à jeton remplaçable, « Changer le lien » | ADR-0085 §4.1, `ChangeClassroomLink` | Non |
| Dette « codes consommés par les classes archivées » | Sans objet : il n'y a plus de code ; le lien d'une classe archivée est invalide | ADR-0085 §4.1 | Non (à rayer de la feuille de route à la clôture) |
| Retirer un élève | ✅ Livré : enseignant de la classe, direction, équipe | ADR-0085 §4.5, `RemoveStudent` | Non |
| Changer un élève de classe par l'enseignant ou l'équipe (ADR-0040 §5) | Remplacé : l'élève retiré ou dont la classe est archivée choisit lui-même (« Choisis ta classe ») | ADR-0085 §4.3, [`choix-classe-eleve`](../choix-classe-eleve/memo.md) | Non |
| **Page d'une classe, enseignant et équipe** (CL-10, CL-14) | ⚠️ Livrée : en-tête (effectif / plafond, lien), jours de séance, cours, exercices assignés et leurs comptes, élèves (recherche, nouveaux, voie, dernier score, retrait). **Manquent** les chiffres de la classe : devoirs donnés, taux de rendu, moyenne | `classroom/classrooms#show`, UDR-0027, 0054, 0062, 0081 | **Oui** (Lot B), selon Q6 |
| Page d'une classe, direction | ✅ Livrée : lien, trois tuiles (devoirs, taux de rendu, moyenne), élèves avec rendus et moyenne, recherche, retrait | `school_admin/classrooms#show`, UDR-0074, 0081 | Non |
| **Liste des élèves** (CL-15) | ✅ Livrée sur les trois pages, avec recherche, **sans pagination** ; bornée par le plafond (150 au plus). Les défauts de l'ancien (liste ouverte à tout connecté, cache jamais invalidé) n'existent plus : `ReadClassroomPolicy`, `ManageClassroomMembersPolicy`, aucun cache de ligne | `_roster`, `school_admin/classrooms/show` | Non, à clore selon Q6 |
| Archivage de fin d'année (`ArchiveSchoolYear`) et reconduction à la rentrée | ❌ Absents. La génération des classes manquantes (ADR-0056) recrée déjà les classes d'une nouvelle année | ADR-0041 §4, Q8 de la feuille de route | Non (Q7) |
| `multi-classes-eleve` (Q5 de la feuille de route) | **Non tranché.** Aucune réponse depuis le 2026-09-25 ; le journal d'`archivage-classes` confirme qu'il n'existe qu'une classe principale par élève | ADR-0040 | Non (Q5) |

## Pour qui

- **L'équipe (Team)**, sur la fiche d'un établissement, quand le terrain contredit le barème : noms, effectifs.
- **La direction (SchoolStaff)**, sur la page d'un niveau, pour son seul établissement : c'est elle qui connaît les vrais noms et effectifs.
- **L'enseignant (Teacher)**, sur la page de sa classe : savoir si ses élèves rendent leurs devoirs, sans passer par chaque exercice.
- **L'élève (Student)** : il voit le nouveau nom de sa classe et retrouve une place quand le plafond est relevé. Il n'a aucun geste nouveau.

## Pourquoi maintenant

La porte de la V3 attend CL-02 depuis la clôture de la V1 (2026-09-28). L'import a donné toutes les classes de la 6ème à la Tle à chaque établissement (ADR-0087) : les directions qui ont commencé à archiver les classes en trop trouvent ensuite des noms et des plafonds qu'elles ne peuvent pas corriger. La dette des sous-pages archivées est un constat de sécurité ouvert (2026-10-10).

## Hors périmètre

- Changer le **niveau**, la **série** ou l'**année** d'une classe : ses cours, ses assignations et la cascade de l'élève en dépendent. On archive et on ajoute.
- Créer une classe au nom libre pour la direction (« Ajouter une classe » reste à l'équipe, UDR-0031).
- Changer le plafond par défaut (80) ou le maximum (150) de l'ADR-0041.
- Un geste « déplacer un élève vers une autre classe » : le retrait suivi du choix par l'élève le remplace (ADR-0085).
- La pagination des listes d'élèves (Q6).
- L'archivage de fin d'année, la reconduction des classes et le rattachement des élèves à la rentrée (Q7).
- Le multi-classes de l'élève (Q5).
- La fiche d'un élève (CL-13, AS-24) et les compteurs de badges (AS-25) : `rapports-de-classe`.
- Donner à un enseignant non confirmé moins de droits sur sa classe (coût consigné dans l'ADR-0085 §5) : chantier à part.

## Ce que le grill a révélé

> Questions posées au porteur le 2026-10-16. Chaque ligne donne la recommandation ; la colonne « Réponse » se remplit à son retour. Aucun code avant ses réponses.

| Question posée | Recommandation | Réponse | Conséquence sur le chantier |
|---|---|---|---|
| **Q1. Qui modifie une classe ?** | **L'équipe** (tout établissement) **et la direction** (son seul établissement actif), par la policy qui garde déjà « + », « − » et l'archivage (`ManageSchoolStructurePolicy`). **Pas l'enseignant** : il se déclare enseignant d'une classe sans validation (ADR-0085 §5) et il a déjà le lien et le retrait. | Oui (2026-10-16) | Revient sur Q3 de la feuille de route (« les classes restent à l'équipe ») et sur le PRD de `gestion-etablissement-direction` (« modifier une classe : non »), comme l'archivage l'a déjà fait le 2026-10-09. ADR-0098 |
| **Q2. Quels champs ?** | **Le nom et le plafond, rien d'autre.** Niveau, série et année : non (voir hors périmètre). Statut : déjà dans le menu ⋮ (archiver, restaurer). Lien : déjà « Changer le lien ». | Oui (2026-10-16) | Une modale de deux champs (UDR-0110) |
| **Q3. Le plafond** | **Entre 1 et 150**, bornes de l'ADR-0041 inchangées. **Refusé sous l'effectif présent** (« La classe compte déjà 42 élèves : le plafond ne peut pas être plus bas. ») : un plafond sous l'effectif fermerait la classe sans rien dire et sans retirer personne. Pour descendre, on retire d'abord des élèves. | Oui (2026-10-16) | Contrôle sous le verrou de la classe, celui que prend l'adhésion d'un élève |
| **Q4. La numérotation** | **Le préfixe du barème est fixe, seul le suffixe change** : « 6ème 3 » peut devenir « 6ème A » ou « 6ème Excellence » (15 caractères au plus), jamais « 5ème 3 » ni « Tle C 3 » pour une Tle D. Le « + » garde sa règle (plus grand numéro + 1 parmi les noms « préfixe n ») : dans un établissement passé aux lettres, il proposera « 6ème 1 » à côté de « 6ème A », que l'on renomme ensuite (coût accepté). Le « − » garde son ordre (numéro final, puis nom). Un nom déjà pris dans l'établissement et l'année, archivées comprises, est refusé. | Oui (2026-10-16) | `ClassroomNumbering` apprend à vérifier un nom ; ADR-0098 précise l'ADR-0059 |
| **Q5. `multi-classes-eleve` est-il demandé ?** (Q5 de la feuille de route) | **Non : le sortir du plan de la V3.** Rien ne le demande depuis le 2026-09-25, et tout le parcours élève redessiné en octobre suppose une seule classe. Il se rouvre sur une demande du terrain, sans migration (ADR-0040). | Oui : sorti de la V3 (2026-10-16) | Aucun lot ; la feuille de route le note à la clôture |
| **Q6. CL-14 et CL-15 : ici ou dans `rapports-de-classe` ?** | **CL-15 close sans pagination** : la liste existe sur les trois pages, avec recherche, et ne dépasse jamais 150 lignes. **CL-14 ici** : les trois tuiles de la direction (devoirs donnés, taux de rendu, moyenne) sur la page de l'enseignant et de l'équipe, avec les mêmes définitions, lues par la même requête. Petit, et sur la page que ce chantier touche déjà. | **Non** pour CL-14 : « pas de moyenne de classe ». Lot B retiré, UDR-0112 abandonnée | Lot B (UDR-0112). Si « non » : Lot B sort, CL-14 reste à `rapports-de-classe` |
| **Q7. Fin d'année et rentrée** (Q8 de la feuille de route) | **Hors de ce chantier.** Ouvrir `rentree-scolaire` avant juin 2027 : le 1er septembre 2027, l'année courante change, et les classes 2026-2027 sortent de la cascade, de l'accueil de l'enseignant et des gestes de structure. La génération des classes manquantes recrée les classes ; restent l'archivage de l'année écoulée et le passage des élèves. | Laissées pour le moment ; aucun chantier ouvert | Ligne ajoutée à la dette de la feuille de route à la clôture |
| Q8. La dette des sous-pages d'une classe archivée entre-t-elle ici ? | **Oui** : c'est la fin de la vie d'une classe, et le correctif tient en un contrôle par contrôleur. | Oui, en correctif séparé (`fix/classe-archivee-sous-pages`) | Lot C, sans vue nouvelle |

## Cas limites identifiés

- Deux gestes concurrents sur la même classe : un élève qui entre pendant qu'on baisse le plafond. Le verrou de ligne les ordonne ; le plafond se juge sur l'effectif lu sous verrou.
- Deux renommages concurrents vers le même nom : l'index unique `(school_id, school_year, name)` refuse le second (`name_taken`).
- Renommer vers le nom d'une classe **archivée** de la même année : refusé, l'index couvre les archivées. Message : « Ce nom est déjà pris dans l'établissement cette année (classes archivées comprises). »
- Classe archivée : pas d'entrée « Modifier » dans son menu ; une requête directe reçoit `:conflict` (`archived`). On restaure d'abord.
- Classe d'une année passée : `:not_found`, comme l'archivage.
- Enregistrer sans rien changer : succès, sans ligne d'audit.
- Nom saisi avec des espaces en trop : compacté avant contrôle (`squish`).
- Classe pleine dont le plafond est relevé : elle ne s'affiche plus « Complète » dans la cascade de l'élève, sans autre geste.
- Établissement désactivé ou en brouillon : la direction n'y a aucun geste (policy) ; l'équipe peut corriger (comme l'archivage).

## Questions encore ouvertes

- Aucune : le porteur a répondu le 2026-10-16 (ci-dessous).

## Réponses du porteur (2026-10-16)

- Recommandations acceptées, **sauf Q6** : pas de chiffres de classe sur la page (le porteur : « pas de moyenne de classe »). Le Lot B sort du chantier, l'UDR-0112 est abandonnée.
- Q7 : la fin d'année et la rentrée sont laissées pour le moment ; aucun chantier `rentree-scolaire` n'est ouvert.
- Le Lot C (classe archivée) part tout de suite en correctif séparé.
