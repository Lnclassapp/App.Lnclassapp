# UDR-0029 : Fiche essentielle dans la classe — ses exercices publiés, leur bascule d'assignation et la réussite de la classe

| | |
|---|---|
| **Statut** | Accepté (2026-09-27, porteur) |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot D6, critères CL-12, AS-20 |
| **ADR lié** | [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (active/archived) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (seul un contenu publié s'assigne) · [UDR-0028](0028-cours-dans-la-classe-et-bascule-d-assignation.md) (bascule d'assignation) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) (vocabulaire) |
| **Remplacé par** | — |

---

## 1. Contexte

Depuis le cours dans sa classe (UDR-0028), l'enseignant ouvre une fiche essentielle pour choisir les exercices à proposer à ses élèves. Dans l'ancienne application, cet écran levait `PG::UndefinedColumn` dès que la fiche avait un exercice (CL-12, AS-20) : l'assignation d'un exercice n'avait aucun point d'entrée qui fonctionne.

## 2. Décision

1. **Même page que le cours dans la classe, un niveau plus bas.** En-tête de la fiche avec sa propre bascule, puis la liste de ses exercices publiés, chacun avec la bascule de l'UDR-0028, rendue telle quelle.
2. **La réussite de la classe à côté de la bascule.** Pour chaque exercice : son nombre de questions, puis la part des élèves présents dans la classe qui l'ont réussi (meilleur score au moins égal au seuil de réussite, 50 %), avec le nombre d'élèves concernés. L'enseignant voit ce que sa classe maîtrise au moment où il choisit quoi assigner. Sans session terminée : « Pas encore de résultat dans la classe ».
3. **Aucun exercice non publié** n'est proposé : brouillons et archivés n'apparaissent pas.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- Écran `classroom/classroom_essentials/show`, `content_for :nav_key, "classrooms"` :
  - lien de retour « Retour à <cours> » vers `classroom_course_path` ;
  - `ui_card` : « <classe> · <établissement> », `h1` de la fiche, sous-titre ; à droite (dessous sur téléphone), la bascule de la fiche dans un `role="group"` nommé « Assignation de la fiche essentielle à la classe » ;
  - `section#classroom_essential_exercises` : titre « Exercices », aide « Assignez un exercice pour le proposer aux élèves de la classe. », puis une liste (`divide-y`, carte) d'une ligne par exercice publié, dans l'ordre de la fiche : titre, « N questions », « Réussite de la classe : 67 % des élèves (2 sur 3) » ou « Pas encore de résultat dans la classe », bascule.
- Bascule : `classroom/assignments/_toggle`, locaux stricts de l'UDR-0028 §3. Exercice : `assignable_type: "Exercise"`, `assignable_key:` son `public_id`, `assignable_name:` son titre. Fiche : `"Essential"`, son slug, son nom.

**Tokens**
- Composants `ui_*` et tokens `@theme` uniquement, comme l'UDR-0028 ; bandeau d'archive en `bg-warning-soft text-warning rounded-ln`.

**Comportement**
- Pas de stream propre : les streams `create` et `archive` de l'UDR-0028 remplacent les bascules de cette page et affichent le toast, sans rechargement.
- Réussite : pour chaque élève présent (`left_at` nul) qui a au moins une session `completed`, son meilleur `score_percent` ; la part arrondie de ceux qui atteignent `PASS_THRESHOLD`. Un élève parti ou hors de la classe ne compte pas (décision du porteur, 2026-09-27).
- Page réservée à l'enseignant de la classe et à l'équipe (`ReadClassroomPolicy`) : un élève ou un autre enseignant reçoit 403. Classe inconnue, cours ou fiche inconnus ou non publiés, fiche lue sous un autre cours : 404.

**États obligatoires**
- Vide : « Aucun exercice publié pour cette fiche. » (UDR-0007), icône `clipboard-document-list`.
- Classe archivée : bandeau « Cette classe est archivée : ses assignations ne changent plus. », badges « Assigné » sans bouton, sans l'aide.
- Succès et refus : ceux de l'UDR-0028.

**Accessibilité**
- Celle de la bascule (UDR-0028) : « Assigner » et « Retirer » nomment l'exercice.
- Sur téléphone, la page ne défile jamais en largeur ; la bascule passe sous le titre.

## 4. Conséquences

- La bascule reste unique : cette page ne la modifie pas et n'écrit aucun stream.
- La réussite affichée est une part d'élèves de la classe, pas un rapport : le détail par élève reste hors de cet écran.
