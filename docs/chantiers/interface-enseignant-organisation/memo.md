# Memo — Organisation des écrans enseignant : accueil, catalogue, fiche et page d'une classe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré (PR vers `Develop`) |
| **Ouvert le** | 2026-10-05 |
| **Branche** | `feature/interface-enseignant-organisation` |
| **Programme** | — |

---

## Le problème

Le porteur a fixé le 2026-10-05 l'organisation des écrans de l'enseignant, sur le modèle de celle de l'élève (`interface-eleve-organisation`).

- **L'accueil** montre « Mes classes » en grille : sur téléphone, trois classes repoussent tout le reste sous le pli. Les annonces destinées aux enseignants n'y apparaissent pas. La section « Activités » affiche « Bientôt » depuis sa création : elle ne sert à rien.
- **Le catalogue** montre à l'enseignant tous les cours de toutes les matières et de tous les niveaux. Sur téléphone, le bloc de recherche et de filtres occupe tout le premier écran, y compris quand l'enseignant arrive depuis une bulle de niveau, déjà filtré.
- **La fiche essentielle** : sous chaque exercice, chaque classe aligne nom, « Assigné », échéance et « Retirer » ; sur téléphone ces informations passent à la ligne au hasard et ne se lisent plus.
- **La page d'une classe** commence par les exercices assignés en liste complète, puis les cours en grille ; le bouton « Code de récupération » de chaque élève pèse autant que son nom.

## Pour qui

L'enseignant (`Teacher`), sur téléphone le plus souvent :
- à chaque connexion (accueil) ;
- quand il cherche quoi assigner (catalogue, fiche) ;
- quand il suit une classe (page de la classe).

## Pourquoi maintenant

L'organisation de l'élève vient d'être fixée et livrée ; l'enseignant doit suivre la même logique : un écran = des sections dans un ordre fixe, des bandes qui défilent plutôt que des grilles, 3 lignes puis « Voir plus ».

## Hors périmètre

- Le contenu et le fonctionnement des annonces : seule leur place sur l'accueil enseignant est nouvelle (le carrousel existe, UDR-0071).
- Masquer une annonce depuis l'accueil enseignant : le masquage est réservé à l'élève (ADR-0078 §4.2) ; l'enseignant lit le carrousel sans croix, comme la direction (UDR-0074 §3.10).
- L'accès direct par URL à un cours, une fiche ou un exercice hors de sa matière ou de ses niveaux : la règle de niveau n'est pas étendue à l'enseignant ; seul le catalogue se restreint.
- Les écrans de l'élève, de la direction et de l'équipe. L'équipe garde son catalogue complet et ses filtres sur ordinateur.
- La page de suivi d'un exercice assigné (`/classrooms/:id/assignments/:id`), inchangée.
- Parent : rôle absent de l'application. SchoolStaff : aucun des écrans touchés ne lui est ouvert.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que montre « Activités », aujourd'hui « Bientôt » ? | Le porteur : les **exercices à suivre**. | Les exercices assignés de ses classes, dans sa matière, dont l'échéance approche ou est passée et qu'au moins un élève présent n'a pas fait. Une lecture nouvelle, sans table ni port. |
| Masquer la recherche du catalogue sur téléphone : pour qui ? | Le porteur : **tous les rôles**. | Le formulaire est caché sous 640 px pour l'élève, l'enseignant et l'équipe. Une liste filtrée garde sur téléphone un lien « Tout voir » à côté du total, sinon le filtre d'une bulle ne se quitte plus. |
| Comment présenter les classes sous un exercice de la fiche ? | Le porteur : **ligne compacte** — nom de la classe, échéance en petit dessous ; à droite « Assigner », ou « Assigné ✓ » et une croix pour retirer. | La bascule d'assignation prend une forme compacte, partagée par toutes ses réponses en Turbo Stream ; « Ouvrir » disparaît sur téléphone (le titre est déjà un lien). |
| Branche et forme du chantier ? | Le porteur : `feature/…` et PR vers `Develop`. | Chantier condensé à partir des consignes, comme `interface-eleve-organisation` : les réponses ci-dessus tiennent lieu de grill question par question. |
| Les annonces existent-elles ? | Oui : la copie locale de `Develop` était en retard (même piège que le chantier élève). | `Develop` remis à jour avant tout travail ; le carrousel existant est réutilisé. |
| Quels cours au catalogue pour un enseignant sans classe ? | Décision de l'auteur, révisable : aucun, avec l'invitation à déclarer ses classes. | Même règle que l'élève sans classe (UDR-0013, amendement du 2026-10-01). |
| « Exercices à suivre » : quelle fenêtre ? | Décision de l'auteur, révisable : échéance dans les 7 prochains jours, ou passée depuis 14 jours au plus. | Une liste courte, qui ne grossit pas sans fin avec les retards anciens ; sans échéance, un exercice n'y est jamais. |
| Page d'une classe : où vont les jours de séance, non cités par le porteur ? | Décision de l'auteur, révisable : ils restent sous l'en-tête. | Ils décrivent la classe, comme l'en-tête ; l'ordre demandé (cours, exercices, élèves) commence après. |

## Cas limites identifiés

- Enseignant sans classe de l'année : bande vide (état vide existant), catalogue vide avec l'invitation, aucune activité.
- Une seule classe : la bande montre une carte, sans points.
- Classe sans élève présent : aucun exercice n'y est « à suivre » (personne n'a rien à faire).
- Exercice fait par tous les élèves présents : il quitte « Activités ».
- Exercice assigné par un collègue d'une autre matière dans la même classe : absent d'« Activités » (sa matière seule).
- Aucune annonce lisible : pas de section annonces (comme l'élève).
- Catalogue filtré par une bulle sur téléphone : le lien « Tout voir » ramène au catalogue de ses niveaux.
- Classe archivée : pas de menu « Code de récupération » (inchangé : pas de bouton aujourd'hui).
- Sans JavaScript : la bande défile au doigt, sans points ; « Voir plus » suit le comportement existant du contrôleur `reveal` (UDR-0057 R3).

## Questions encore ouvertes

Aucune. Le porteur a validé le 2026-10-05 les trois décisions de l'auteur :
- fenêtre des « Exercices à suivre » : échéance dans les 7 prochains jours, ou passée depuis 14 jours au plus ;
- enseignant sans classe de l'année : catalogue vide, avec l'invitation à déclarer ses classes ;
- jours de séance sous l'en-tête de la classe, « Modifier les jours » dans leur menu ⋮ (demande du porteur).
