# Journal — Supprimer une leçon qui n'a jamais servi à un élève

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | La modale vérifie l'activité dès l'ouverture et n'offre jamais « Supprimer » à une leçon utilisée ; la suppression revérifie sous verrou. | Pas de faux bouton ; la course reste couverte côté serveur. | UDR-XXXX §2 |
| 2026-11-14 | L'envoi d'un devoir verrouille l'exercice (FOR KEY SHARE) et refuse un exercice disparu. | Le lien des devoirs est polymorphe, sans clé étrangère : sans ce verrou, un devoir orphelin pouvait naître pendant la suppression. | ADR-XXXX §4.4 |
| 2026-11-14 | Purge propre à la suppression, distincte de celle de l'import hors production. | Celle de l'import efface aussi l'activité ; la suppression ne doit jamais pouvoir le faire. | ADR-XXXX §5 |

## À trancher

- [ ] 2026-11-14 · suppression-lecon · Après suppression, où renvoyer l'équipe ? — appliqué : le catalogue (« Cours ») avec un message qui cite Imports ; autres : l'écran Imports directement ; recommandé : le catalogue
- [ ] 2026-11-14 · suppression-lecon · Un devoir envoyé puis archivé par l'enseignant, sans qu'aucun élève l'ait ouvert, bloque-t-il la suppression ? — appliqué : oui (option prudente) ; autres : ne compter que les devoirs actifs ; recommandé : oui
- [ ] 2026-11-14 · suppression-lecon · Libellé : « leçon » dans la modale, alors que le menu dit encore « fiche de cours » ailleurs (« Actions sur la fiche de cours… », toasts d'archivage). — appliqué : « leçon » (le mot de l'import et du porteur) ; autres : « fiche de cours » ; recommandé : « leçon », et une retouche pour aligner le reste

## Retouches

- …

## Ce qui a dérapé

- La revue « échecs muets » a trouvé qu'un envoi groupé de devoirs croisant une suppression annonçait l'exercice disparu « Déjà assigné » : corrigé (envoi refusé entier, `unknown_exercise`).
- Deux suites de tests lancées en parallèle sur la même base de test se sont interbloquées : une suite à la fois.
- Rien de bloquant par ailleurs. Les tests de contrôleur ont d'abord échoué faute d'assets compilés (`yarn build`, `yarn build:css`) dans le conteneur neuf.

## Ce qu'on a appris sur la codebase

- `essential_reads → essentials` est en `ON DELETE CASCADE`, seule exception à la règle RESTRICT des traces d'élèves : toute suppression de notion doit lire les lectures avant.
- `classroom_assignments` est polymorphe sans clé étrangère : la base ne protège pas un exercice assigné.
- `ContentTreeWriter#delete_content` (import hors production) efface aussi l'activité d'élève : à ne jamais réutiliser pour une suppression demandée par l'équipe.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Une trace d'élève oubliée par la lecture donne une erreur 500 (la clé RESTRICT lève, rien n'est perdu) au lieu de la modale de refus. | Voulu (ADR §5) : une source oubliée est un défaut, pas un refus. | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-14 |
| **PR** | (à poser) |
| **ADR produits** | ADR-XXXX-suppression-d-une-lecon-sans-activite-eleve ; amendements ADR-0035, ADR-0036 |
| **UDR produits** | UDR-XXXX-supprimer-une-lecon-depuis-sa-fiche |
