# Journal — Faire entrer des classes entières

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-16 | Mesurer avant d'agir : le lot A seul, puis un unique lot B désigné par la mesure | Sept élèves excluent qu'une classe ait adopté l'app, mais ne départagent pas les goulots 1, 2, 3 et 4, dont les remèdes n'ont rien en commun | ADR-XXXX-adoption-par-les-classes-lue-sur-les-tables |
| 2026-11-16 | Pas de Lot 0 | Aucun contrat partagé, aucune route, aucune locale, aucune migration | Non |
| 2026-11-16 | Pas d'UDR ni d'ADR pour les lots B avant le verdict | Écrire quatre interfaces dont trois ne seront pas construites | Non |
| 2026-11-16 | Lot A : la médiane d'élèves (règle §3.2, étape 5) porte sur les classes ouvertes **cochées** par un enseignant non anonymisé et comptant au moins 1 élève ; le PRD disait seulement « classe peuplée » | La règle juge l'adoption par les enseignants, pas les classes que l'équipe a ouvertes sans eux | Non |
| 2026-11-16 | Lot A : le bloc CRM ne compte que les établissements `status = 'active'` ; l'indice 2b / 3 compte un enseignant « avec devoir » s'il a donné un devoir à l'une de ses classes cochées vides | Un établissement brouillon ou inactif gonflerait « prospect » ; un devoir donné ailleurs ne dit rien de la classe vide | Non |
| 2026-11-16 | Lot A : la sortie imprime E1..E6 puis « Bloqués » en dernière colonne, et les voies d'arrivée élèves à zéro sont omises | Les scénarios PRD §6 lisent « sans enseignant : standard 1 » et « avec enseignant : code 1 » | Non |
| 2026-11-16 | Lot A, retours de revue : E2 inclut l'enseignant qui coche une classe ouverte ailleurs ; E6 ne compte que les exercices commencés depuis le 1er septembre de l'année en cours ; le CRM compte les non-inactifs (brouillons compris) ; « avec enseignant » exige un `role = 'teacher'` non anonymisé ; échanges 30 j bornés à maintenant ; la valeur déclencheuse s'imprime à côté du goulot. Corrige la ligne « actifs » de l'entrée précédente | Cohérence avec E1/E3 et lecture directe du verdict | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-16 · acquisition-classes · Seuils de la règle de verdict (PRD §3.2) — appliqué : par défaut (10 enseignants, 30 % bloqués, 50 %, 50 %, médiane 10 élèves) ; autres : seuils du porteur ; recommandé : par défaut, révisés après la première lecture.
- [ ] 2026-11-16 · acquisition-classes · Ordre d'exécution — appliqué : lot A seul, PR prête vers `Develop`, fusion après le train #653 ; autres : lancer un lot B sans mesure ; recommandé : lot A seul.
- [ ] 2026-11-16 · acquisition-classes · Goulot désigné — appliqué : aucun avant la lecture en production ; à cocher avec la sortie de `bin/rails entonnoir:classes`.
- [ ] 2026-11-16 · acquisition-classes · **Droits (non réversible)** : un enseignant peut-il ouvrir lui-même une classe quand son établissement n'en a aucune (lot B2) ? — appliqué : rien, arrêt sur ce point ; autres : oui, établissement principal et niveau existant ; non, il prévient l'équipe en un geste ; recommandé : ne trancher que si la mesure désigne 2a.
- [ ] 2026-11-16 · acquisition-classes · Section « Enseignants et classes » de la page Croissance — appliqué : reportée après le verdict ; autres : dans le lot A ; recommandé : après le verdict.

## Mesure en production

> Sortie de `bin/rails entonnoir:classes`, collée ici par le porteur après la fusion du lot A.

- …

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Lot A : la base de test porte déjà 4 établissements et 181 classes du jeu de référence (hors fixtures). Les trois fichiers de test les retirent dans leur transaction (`delete_all`) ; sans cela, « prospect » et « classe ouverte » comptent des lignes qui ne viennent pas du test. PostgreSQL n'était pas démarré en début de session : relancé avec `service postgresql start`.

## Ce qu'on a appris sur la codebase

- L'enseignant ne crée pas de classe : il coche une classe ouverte par l'équipe ou la direction. Le code de 6 caractères est posé par la base à la création de la classe, avant tout enseignant.
- L'inscription de l'élève propose la cascade en premier. Le code est un second choix (ADR-0085).
- Depuis ADR-0073 et ADR-0083, plus rien n'écrit de demande d'adhésion en attente : la carte « Demandes en attente » de la page Croissance vaut toujours 0.
- Sur la page Croissance, « enseignant actif » désigne tout enseignant rattaché à un établissement principal, depuis toujours : ni actif, ni borné à la période.
- La page d'invitation complète des enseignants n'a plus aucun lien qui y mène. Seule la bulle WhatsApp de l'accueil (collègue du même établissement) est branchée.
- La bannière « Ton enseignant n'est pas encore sur Lnclass ? » s'affiche même quand la classe a un enseignant. Son lien mène à l'inscription enseignant sans jeton : ni établissement prérempli, ni attribution, ni comptage.
- Le brouillon WhatsApp du CRM ne contient aucun lien d'inscription, alors que la fiche de l'école en porte deux (lien équipe, code de l'école).
- La légende de `entonnoir:brut` dit « 10/20 » à côté de 48 %, ce qui est juste au sens de `Grading.reaches?` mais se lit mal.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Carte « Demandes en attente » toujours à 0 sur la page Croissance | Hors du goulot | retouche |
| Libellé « Élèves arrivés par enseignant actif » trompeur | Touche une vue de la page Croissance (UDR-0050) | avec la section « Enseignants et classes », après le verdict |
| Page d'invitation enseignant orpheline | Le parrainage n'est pas le goulot tant que E1 est petit | à rouvrir si le goulot est 1 |
| Bannière élève → enseignant : affichée même avec un enseignant, sans établissement prérempli ni attribution | Elle touche l'accueil de l'élève, et l'attribution demande une voie d'inscription nouvelle (contrat) | à rouvrir si le goulot est 1 |
| Brouillon partiel « prochaine étape, non affecté » jamais rendu | Code mort, hors du goulot | retouche |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
