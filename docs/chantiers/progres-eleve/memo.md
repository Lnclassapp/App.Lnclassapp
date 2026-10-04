# Memo — L'élève voit son propre progrès

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-10-04 |
| **Branche** | `feature/progres-eleve` |
| **Programme** | `refonte-application` — suite du chantier [`rapports-exercices`](../rapports-exercices/memo.md) (V3), à rattacher à une vague par le porteur |

---

## Le problème

Un élève refait un exercice : 30 %, puis 60 %, puis 90 %. Il voit chaque fois un résultat de session (UDR-0023), et son meilleur score avec son badge sur la fiche. Mais **personne ne lui dit qu'il a progressé**. Avec `rapports-exercices`, son enseignant le voit (« ↗ en progrès », ADR-0079). Lui ne le voit pas.

La mission de Lnclass est d'aider chaque acteur du système éducatif à progresser (porteur, 2026-10-04). Le premier acteur concerné par son progrès est l'élève lui-même.

## Pour qui

- **L'élève (Student)**, **sur la page de résultat** de la session qu'il vient de terminer, quand ce n'est pas son premier essai : c'est le moment où il se demande « est-ce que j'ai progressé ? ».
- **L'enseignant et l'équipe** : rien de nouveau ici. L'enseignant lit déjà le progrès de chaque élève sur la page de suivi (`rapports-exercices`).
- **La direction, le parent** : rien.

## Pourquoi maintenant

`rapports-exercices` fixe les règles du signe de progrès (ADR-0079 : premier, meilleur et dernier essai, marge de 10 points). Les montrer à l'élève réutilise ces règles sans en inventer. Le porteur a demandé l'ouverture du chantier le 2026-10-04.

## Hors périmètre

- La lecture de classe vue par l'enseignant : chantier `rapports-exercices`.
- Le progrès sur l'**accueil élève**, sur la **fiche** ou dans l'**historique** : un seul endroit d'abord (charte §1, « dire chaque chose une seule fois »), le résultat de session. À rouvrir après usage.
- Une **courbe** ou un **graphique** des essais.
- Le progrès d'un élève **comparé à sa classe** : jamais ; l'élève ne se mesure qu'à lui-même.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Faut-il montrer à l'élève son propre signe de progrès ? | **Oui, dans un chantier à part** (porteur, 2026-10-04, pendant `rapports-exercices`). | Ouverture de ce chantier. Les règles du signe viennent de l'ADR-0079 ; l'élève ne voit jamais celui d'un camarade. |
| Le porteur délègue toutes les décisions (2026-10-04) : « tes décisions doivent servir et aider à améliorer les users ». | Les lignes suivantes sont des décisions prises sous cette délégation, chacune au service du progrès de l'élève. | Aucune question au porteur dans ce chantier. |
| Où l'élève voit-il son progrès ? | **Sur la page de résultat de la session**, dans la carte, sous la note. C'est l'instant où il vient de recommencer ; ailleurs, l'information se répéterait (charte §1). | Une seule vue modifiée (UDR-0023), amendée par une UDR nouvelle. |
| Quelles sessions forment son historique ? | **Toutes ses sessions terminées sur cet exercice, standard et remédiation**, quelle que soit la classe ou l'assignation, **jusqu'à celle qu'il regarde** (incluse). C'est son progrès à lui, pas celui d'un devoir. Rouvrir un ancien résultat montre le progrès d'alors. La remédiation compte (2026-10-04, défaut D1 du challenger) : sous 50 %, chaque session suivante de la fiche en est une (ADR-0043), et c'est en elle que l'élève qui rate puis réussit progresse. | Différent de la lecture enseignant (sessions d'une assignation) : deux acteurs, deux questions. Les règles du signe restent celles de l'ADR-0079 (premier, meilleur, dernier = la session regardée, marge 10 points). |
| Comment dire « en baisse » ou « stagne » à un élève de 11 ans ? | **Jamais ces mots.** La charte (§5) interdit la sanction. Chaque cas dit **où il en est et quoi faire ensuite** : progrès → « Tu progresses : 6/20 à ta première session, 18/20 aujourd'hui. » ; stable → « Tu confirmes ta maîtrise : 16/20. » ; stagne → « Tu restes autour de 12/20. Relis la correction ci-dessous avant de recommencer. » ; baisse → « Ton meilleur résultat reste 18/20. Relis la correction, tu peux le retrouver. » | Libellés en tutoiement. La seule couleur est le vert « réussi » du progrès, jamais de rouge ni d'ambre. La correction, déjà sous la carte, devient le geste proposé. |
| En pourcentage ou sur 20 ? | **Sur 20**, la seule forme de note que l'élève lit (UDR-0023, 2026-10-02). Le calcul reste en pourcentage (ADR-0079). | `Grading.grade_on_20` pour chaque nombre affiché. |
| « Essai » ou « session » ? | **« Session »** : l'UDR-0007 (acceptée) interdit « Essai » à l'écran, et `locale_files_test` le vérifie. | « à ta première session » dans la phrase de progrès. |
| L'enseignant qui ouvre le résultat d'un élève voit-il la phrase ? | **Non** : elle parle à l'élève (tutoiement). L'enseignant a la page de suivi. | Phrase rendue pour le seul propriétaire de la session. |

## Cas limites identifiés

- **Premier essai** : aucune phrase (rien à comparer).
- **Deuxième essai identique au premier, sous 70 %** : « Tu restes autour de… » ; à 70 % ou plus : « Tu confirmes ta maîtrise ».
- **Ancien résultat rouvert** : le progrès est calculé jusqu'à cette session, pas jusqu'à la dernière.
- **Session commencée ou abandonnée** entre deux essais : ne compte pas.
- **Élève dans deux classes** : une seule histoire par exercice, toutes classes confondues.
- **Session de remédiation** sur l'exercice : compte, et son résultat porte la phrase (2026-10-04, défaut D1 du challenger).

## Questions encore ouvertes

- Après usage : faut-il aussi le progrès sur l'accueil ou la fiche ? À mesurer avant d'ajouter un second endroit.
