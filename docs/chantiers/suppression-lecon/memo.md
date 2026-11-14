# Memo — Supprimer une leçon qui n'a jamais servi à un élève

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-11-14 |
| **Branche** | `feature/suppression-lecon` |
| **Programme** | — |

---

## Le problème

L'équipe Lnclass ne peut qu'archiver une leçon. Une leçon publiée avec une erreur de fond (mauvais niveau, mauvais découpage en notions, exercices à refaire) ne peut pas être réimportée : l'import refuse toute leçon déjà présente qui n'est plus entièrement en brouillon, même archivée (« leçon déjà publiée »). L'équipe reste bloquée : la seule issue est de renommer la leçon pour en importer une copie, ce qui laisse un doublon archivé dans le catalogue.

## Pour qui

L'équipe Lnclass (rôles qui gèrent le contenu), sur la page d'une leçon, au moment où elle constate qu'il faut la refaire.

## Pourquoi maintenant

Les leçons de 6ème et 5ème viennent d'être importées en série (60 leçons). Les premières relectures trouvent des leçons à refaire avant que les élèves ne s'en servent : c'est la fenêtre où la suppression ne coûte rien.

## Hors périmètre

- Supprimer une leçon qui a déjà servi à un élève, de quelque façon que ce soit : jamais. On propose de la modifier.
- Supprimer une notion, un exercice ou un sujet seul : la leçon se réimporte entière.
- Corbeille, restauration après suppression : la suppression est définitive, la réimport est la restauration.
- Suppression en masse (plusieurs leçons d'un coup).
- Enseignants, direction, parents, élèves : ils ne voient ni l'entrée ni la confirmation.
- Changer la règle de l'import (« leçon déjà publiée ») : elle reste ; c'est la suppression qui libère la place.
- Effacer les traces d'audit ou les rapports d'import qui citent la leçon : ils restent, en texte.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Qu'appelle-t-on « activité d'élève » ? | Toute trace laissée par un élève ou pour un élève : séance d'exercice (même commencée), réponse, badge, lecture de notion, lacune, pack hors ligne livré, devoir envoyé à une classe (actif ou archivé). « Je m'entraîne » n'écrit rien, il ne compte pas. | Sept sources, chacune testée seule. |
| Une lecture de notion est-elle protégée par la base comme le reste ? | Non : c'est la seule trace effacée en cascade avec la notion. Une suppression naïve l'effacerait sans erreur. | La vérification de l'activité ne peut pas compter sur la base : elle lit chaque source explicitement. |
| Un devoir envoyé puis archivé par l'enseignant compte-t-il ? | Oui : il a été vu par une classe et figure dans ses suivis. | Refus, comme un devoir actif. |
| Un élève commence un exercice pendant la suppression ? | La leçon et tout son contenu sont verrouillés avant la vérification ; la séance attend la fin de la suppression puis échoue proprement (l'exercice n'existe plus), ou bien elle est déjà là et la suppression est refusée. | Verrou de la leçon et de son contenu, vérification après le verrou. |
| Un enseignant envoie un exercice de la leçon à sa classe pendant la suppression ? | Le devoir n'est pas protégé par la base comme une séance (lien générique). Sans précaution, il pourrait viser un exercice disparu. | L'envoi d'un devoir prend lui aussi un verrou sur l'exercice ; un exercice disparu refuse le devoir. |
| Parent, direction, enseignant : que voient-ils ? | Rien de nouveau. Une leçon supprimée disparaît du catalogue ; personne ne l'avait utilisée. | Écrit dans Hors périmètre. |
| Multi-appartenance élève, inter-établissements ? | Sans objet : le contenu appartient à la plateforme ; une trace de n'importe quel élève, de n'importe quelle école, suffit à refuser. | Pas de filtre par école dans la vérification. |
| Que devient la page de la leçon après suppression ? | Elle n'existe plus : retour au catalogue avec un message qui rappelle qu'on peut réimporter. | Redirection vers le catalogue, pas de mise à jour en place. |
| Que dit le refus ? | Que la leçon a servi à des élèves et ne peut pas être supprimée, et propose de la modifier, avec le bouton. | Le refus est montré dès l'ouverture de la confirmation, sans faux bouton « Supprimer ». |
| Les images et le texte du cours ? | Supprimés avec la leçon ; les fichiers stockés sont purgés. | Destruction par l'outil de stockage, pas une simple suppression de ligne. |

## Cas limites identifiés

- Leçon en brouillon, publiée ou archivée sans activité : suppression permise.
- Leçon avec des notions sans exercices, ou des sujets sans exercices, ou des problèmes de toute la leçon : tout part.
- Double clic sur « Supprimer » : la seconde demande trouve la leçon absente (page introuvable).
- Deux leçons voisines (même matière, même niveau) : rien ne bouge chez la voisine.
- Leçon réimportée après suppression : elle est acceptée (plus de doublon) et recrée sa page.
- Un élève qui commence une séance au même instant : soit refus de la suppression, soit séance refusée ; jamais une séance orpheline.

## Questions encore ouvertes

- Aucune bloquante. Les choix réversibles pris par défaut sont dans `journal.md` (`## À trancher`).
