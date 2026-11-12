# Memo — L'élève sans enseignant a quelque chose à faire dès l'accueil

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR vers `Develop`) |
| **Ouvert le** | 2026-11-12 |
| **Branche** | `feature/eleve-sans-prof` |
| **Programme** | — |

---

## Le problème

Constat du porteur : un élève sans enseignant sur Lnclass arrive sur son accueil et ne voit ni matière ni exercice. Il n'a rien à faire, donc il n'essaie pas l'application et n'atteint jamais le « Ah ah moment » : un premier exercice fait et corrigé.

### Cause, reproduite sur le jeu standard (2026-11-12)

L'absence d'enseignant n'est **pas** la cause. Un élève de Tle A1, classe sans devoir ni enseignant actif, voit déjà ses 5 matières et un exercice du jour. Tout dépend du **niveau de l'élève**, tiré de ses classes actives de l'année. Deux situations vident l'accueil :

1. **L'élève n'a plus de classe active** : il a été retiré, sa classe est archivée ou elle est d'une année passée. Son niveau est alors vide. L'accueil ne montre que la carte « Choisis ta classe ». La grille est masquée par décision d'interface, l'exercice du jour n'est pas calculé, et le catalogue lui est fermé, car la règle de lecture par niveau ne lui laisse aucun cours.
2. **Son niveau n'a aucune leçon publiée** : la grille ne garde que « Inviter », avec « Aucune matière pour l'instant », et la carte dit « Rien à te proposer aujourd'hui ». Le 2026-11-12, les pages publiques des niveaux listent seulement 3e, 1ère et Tle en production, et 3e et Tle sur Develop et Staging. Un élève de 6e, 5e, 4e ou 2nde n'a donc rien, enseignant ou pas.

Le cas 2 est probablement celui du porteur (capture « avant » d'un élève de 2nde A). Ce chantier ne peut pas créer de leçons : il traite le cas 1 et rend le message du cas 2 honnête.

## Pour qui

L'élève (Student), à sa première visite ou à son retour sur l'accueil, quand il n'a plus de classe active.

## Pourquoi maintenant

Le porteur fait tester l'application à des élèves sans enseignant (bêta) : un accueil vide les perd dès le premier écran.

## Hors périmètre

- Créer des leçons pour les niveaux qui n'en ont pas (6e à 4e, 2nde) : c'est du contenu, chantiers `contenus-*`.
- Proposer les leçons d'un autre niveau quand le sien n'en a pas : écrit dans `À trancher`.
- Le bandeau d'abonnement de l'accueil : la session `acces-beta` le retire en parallèle.
- Parent, direction (SchoolStaff), équipe (Team) : rien ne change pour eux. L'enseignant n'est pas concerné, puisque l'élève n'est dans aucune de ses classes.
- Les devoirs : un élève sans classe n'en reçoit pas.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Est-ce vraiment l'absence d'enseignant qui vide l'accueil ? | Non : un élève sans enseignant mais dans une classe de Tle voit déjà ses matières et l'exercice du jour. | Le chantier porte sur l'élève sans classe active, pas sur la classe sans enseignant. La cause est écrite plus haut. |
| Les matières du dernier niveau mènent-elles quelque part ? | Non : le catalogue répond « introuvable » à un élève sans classe. | La règle de lecture par niveau prend le dernier niveau connu (amendement de l'ADR-0035). Sinon la grille mènerait à des pages vides. |
| Qu'est-ce que le « dernier niveau connu » ? | Le niveau et la série de sa dernière classe principale : celle encore ouverte, puis la plus récemment quittée. C'est la classe qui préremplit déjà « Choisis ta classe ». | Une seule règle, aussi pour l'exercice du jour et le catalogue. |
| Multi-appartenance : un élève dans deux classes de l'année ? | Rien ne change : l'union des niveaux de ses classes de l'année. Le repli ne joue que s'il n'en a aucune. | Le repli ne prend qu'une classe, et seulement les classes principales. |
| Un élève retiré par son enseignant garde-t-il l'accès à son ancien niveau ? | Oui : c'est la décision du porteur (« prends le dernier niveau connu »). Il ne voit ni la classe, ni ses camarades, ni ses devoirs, seulement le catalogue public de ce niveau. | Écrit dans l'ADR-0035 (amendement). Le devoir d'une classe archivée peut revenir comme exercice du jour, ce que la règle du jour permettait déjà pour une classe archivée. |
| L'élève sans aucune classe passée ? | Il ne peut pas exister par l'inscription (l'élève entre toujours dans une classe), mais un compte importé peut l'être. | Option prudente : rien ne change, seulement « Choisis ta classe ». Écrit dans `À trancher`. |
| « Inviter » dans la grille, sans classe ? | Le message WhatsApp nomme la classe et l'établissement : sans classe, il dirait « Je suis en  à . ». | Pas de case « Inviter » sans classe. |
| Deux boutons principaux dans la carte ? | Non (un écran = une tâche principale) : « Rejoindre » reste le bouton principal. | L'exercice du jour est un bloc secondaire sous le code, comme dans l'état « Tout est fait ». |

## Cas limites identifiés

- Classe archivée, élève retiré, classe d'une année passée : les trois prennent le niveau de cette dernière classe.
- Dernier niveau sans leçon publiée : ni grille ni exercice du jour, comme aujourd'hui.
- Aucune classe passée : seulement « Choisis ta classe ».
- Exercice du jour déjà fait : « Exercice du jour fait. Reviens demain ! », sans bouton.
- Un autre niveau reste fermé (introuvable).

## Questions encore ouvertes

Voir `journal.md`, section `À trancher`.
