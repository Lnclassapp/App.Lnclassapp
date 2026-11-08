# UDR-XXXX : Décisions produit de l'audit du 8 novembre — fiche élève de la direction, leçon par adresse, jours de séance, « Voir plus » des leçons
<!-- index
titre: Décisions produit de l'audit : fiche élève lue par la direction, leçon limitée aux matières de l'enseignant, jours de séance non vides, « Afficher plus » des leçons
statut: Accepté *(porteur, 2026-11-08)*
adr-lie: [0028](../adr/0028-policies-de-domaine-par-use-case.md)
problematique: Quatre points d'interface laissés « à confirmer » par l'audit du 8/11 : qui ouvre la fiche d'un élève, qui lit une leçon par son adresse, tout décocher dans les jours de séance, les leçons au-delà de 24. Amende UDR-0077 §4
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-11-08)* |
| **Date** | 2026-11-08 |
| **Chantier** | `docs/chantiers/audit-decisions-produit` |
| **Remplacé par** | — |

Amende : UDR-0077 §4 (« un lien direct vers un cours d'une autre matière reste ouvert »).

---

## 1. Contexte

L'audit du 8/11 a relevé quatre écarts entre écran et règle ; le porteur a tranché chacun.

## 2. Décision

1. **Fiche élève, direction (B-011)** : la direction d'une école ouvre la fiche d'un élève de SES classes, en lecture seule.
2. **Leçon par adresse, enseignant (B-046)** : un enseignant ne lit une leçon que dans ses matières (celles de son établissement courant), comme le catalogue. Hors de ses matières : 404, rien n'est révélé. Direction, équipe et élève sont inchangés.
3. **Jours de séance (B-012)** : tout décocher est refusé, comme à l'assignation.
4. **Leçons de l'élève sur ordinateur (O-C02)** : au-delà de 24, « Afficher plus de fiches de cours ».

## 3. Règles d'implémentation

- **Fiche élève de la direction** : le nom de l'élève, dans la liste de `school_admin/classrooms/show`, est un lien vers `classroom_student_path`. La fiche (`classroom/classroom_students/show`) pour la direction : lien de retour vers `school_admin_classroom_path`, pas de bloc « Gérer », titres d'exercices et « Voir la séance » sans lien (leurs pages sont celles de l'enseignant). Direction d'une autre école ou sans école : 403.
- **Leçon par adresse** : `Policies::Catalog::ReadOwnMaterialPolicy`, appelée par `ReadsOwnLevel#refuse_out_of_material` sur la page de la leçon, son ancienne fiche (301), les feuilles et l'ancienne adresse d'une notion. Un enseignant sans matière dans l'établissement courant reçoit 404.
- **Jours de séance** : message `classroom.session_days.edit.blank` = « Cochez au moins un jour. », sous les pilules, en `text-error`, en 422 ; les jours déjà donnés restent.
- **Leçons** : bloc `#lessons_list` de 24 cartes ; au bas, `turbo-frame#lessons_page_<n>` (`loading=lazy`, `target=_top`) dont le bouton secondaire « Afficher plus de fiches de cours » ouvre la même page sans JavaScript ; la page n reprend la matière et la recherche.

## 4. Conséquences

- Le catalogue de l'enseignant n'est plus une simple lecture : la leçon par son adresse suit la même portée (matières).
- Interdit désormais : un lien vers la leçon d'une autre matière, sur un écran enseignant.
