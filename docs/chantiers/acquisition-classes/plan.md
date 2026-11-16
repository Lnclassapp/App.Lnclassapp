# Plan d'exécution — Faire entrer des classes entières

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — MESURE (seul, inconditionnel ; pas de Lot 0 : aucun contrat partagé, aucune route, aucune locale)
  ↓
Porte V — lecture en production par le porteur, sortie collée au journal, goulot désigné
  ↓  un seul des lots suivants part ; chacun ouvre son UDR (et son ADR s'il touche aux droits) avant le code
  ├─► B1 « l'équipe fait entrer des enseignants »           si goulot 1
  ├─► B2 « l'enseignant n'est plus bloqué sans classe »      si goulot 2a / 2a′
  ├─► B3 « la classe vide reçoit ses élèves »                si goulot 2b / 3
  └─► (goulot 4 : rien dans le code ; plan de terrain hors chantier)
```

Les lots B sont **conditionnels et exclusifs**. Ils ne partent pas en parallèle : la mesure en désigne un seul. Leur contenu ci-dessous est une **esquisse**. Leurs fichiers seront gelés à l'ouverture, après la porte V.

---

## Lot A — Entonnoir des classes en lecture seule

- **Couche**       : domaine + infrastructure + tâche (pas d'UI)
- **Fichiers**     : `app/domain/entities/classroom/adoption_verdict.rb`
                     `app/infrastructure/queries/classroom/class_adoption_query.rb`
                     `lib/tasks/entonnoir_classes.rake`
                     `test/domain/entities/classroom/adoption_verdict_test.rb`
                     `test/infrastructure/queries/classroom/class_adoption_query_test.rb`
                     `test/tasks/entonnoir_classes_task_test.rb`
                     `docs/decisions/adr/XXXX-adoption-par-les-classes-lue-sur-les-tables.md` *(statut Proposé → Accepté)*
                     `docs/chantiers/acquisition-classes/journal.md`
- **Dépend de**    : fusion du train #653 vers `Staging` (rien n'entre dans `Develop` avant)
- **Test associé** : les 9 scénarios du PRD §6, plus un test par branche de la règle de verdict (§3.2). Couverture 100 % lignes et branches (ADR-0024).
- **Done quand**   : sur le jeu standard, `bin/rails entonnoir:classes` imprime les quatre blocs, la ligne « Goulot désigné » et les limites. Une écriture tentée est refusée. Aucun nom ni identifiant n'apparaît dans la sortie. `bin/ci-quiet` est vert (niveau pr).

Le lot ne touche ni `app/views/pwa/**`, ni `app/javascript/pwa.js`, ni le profil de l'élève, ni `lib/tasks/entonnoir.rake`.

---

## Porte V — Verdict

- Le porteur lance la tâche en production (console Railway) et colle la sortie dans `journal.md` § « Mesure en production ».
- L'orchestrateur coche le goulot dans `## À trancher` et ouvre le lot B correspondant, avec son UDR.
- Si la sortie contredit la règle (petits nombres, comptes de recette), le porteur tranche à la main. La règle n'est qu'une valeur par défaut.

---

## Lot B1 — L'équipe fait entrer des enseignants *(si goulot 1, esquisse)*

- **Couche**       : domaine + infrastructure + delivery + ui (contexte `crm`)
- **Fichiers**     : à geler à l'ouverture. Pressentis : le brouillon WhatsApp du CRM (prompt et vue), le bloc « Usage » de la fiche CRM, et leurs locales.
- **Dépend de**    : porte V
- **Test associé** : (1) le brouillon contient le lien d'inscription enseignant de l'établissement (`/i/<jeton équipe>`), sans nom ni numéro ; (2) le bloc Usage sépare enseignants, classes ouvertes, classes peuplées et élèves.
- **Done quand**   : un membre du terrain envoie, depuis une relance, un message qui contient le lien d'inscription de l'école. La fiche montre combien d'enseignants de l'école sont entrés.
- **Décisions**    : une UDR (brouillon et Usage). L'ADR-0128 est amendée : le prompt reçoit un lien, toujours sans donnée personnelle.

## Lot B2 — L'enseignant n'est plus bloqué sans classe *(si goulot 2a / 2a′, esquisse)*

- **Couche**       : domaine + infrastructure + delivery + ui (contexte `classroom`)
- **Fichiers**     : à geler à l'ouverture. Pressentis : l'écran « Quelles classes enseignez-vous ? » (état vide) et la policy d'ajout d'une classe de niveau.
- **Dépend de**    : porte V, **et la décision de droits ci-dessous**
- **Test associé** : un enseignant dont l'établissement n'a aucune classe ouverte ouvre la sienne (niveau, nom), la coche, et obtient son code en un écran.
- **Done quand**   : l'écran « Aucune classe ouverte » n'est plus une impasse.
- **Décisions**    : un ADR, parce qu'**un enseignant obtient le droit d'ouvrir une classe** : c'est une décision de droits, non réversible au sens du contrat de session. Elle est posée au porteur avant le lot. Une UDR pour l'état vide.

## Lot B3 — La classe vide reçoit ses élèves *(si goulot 2b / 3, esquisse)*

- **Couche**       : delivery + ui (contexte `classroom`)
- **Fichiers**     : à geler à l'ouverture. Pressentis : la carte de classe de l'accueil enseignant (état « sans élève ») et une page imprimable du code et du lien de la classe.
- **Dépend de**    : porte V
- **Test associé** : sur une classe sans élève, l'accueil propose « Partager sur WhatsApp » (lien de la classe) **et** « Imprimer pour le tableau », sans ouvrir la classe. La page imprimable porte le code en grand, le lien court et la marche à suivre en trois lignes.
- **Done quand**   : l'enseignant donne le code en un geste depuis son accueil, sur téléphone ou au tableau.
- **Décisions**    : une UDR (carte vide et page imprimable). Pas d'ADR : aucun contrat ne change.

---

## Décisions ouvertes

- [ ] Seuils de la règle de verdict (PRD §3.2) — options : par défaut (10 enseignants, 30 %, 50 %, 50 %, 10 élèves) ; seuils du porteur. Recommandé : par défaut, révisés après la première lecture.
- [ ] Lot B2 : l'enseignant peut-il ouvrir une classe lui-même ? — options : oui, dans son établissement principal, niveau existant ; non, il prévient l'équipe en un geste. Recommandé : décider seulement si la mesure désigne 2a. **Décision de droits : arrêt jusqu'à réponse.**
- [ ] Une section « Enseignants et classes » sur la page Croissance, pour lire l'entonnoir sans console — options : après le verdict ; jamais. Recommandé : après le verdict (UDR à ce moment-là).

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/entities/classroom/adoption_verdict.rb` | Lot A |
| `app/infrastructure/queries/classroom/class_adoption_query.rb` | Lot A |
| `lib/tasks/entonnoir_classes.rake` | Lot A |
| `lib/tasks/entonnoir.rake` | personne (non touché) |
| `app/views/pwa/**`, `app/javascript/pwa.js`, profil de l'élève | chantier `notifications-push` (interdit ici) |

Pas de lots parallèles : la collision ne peut naître qu'entre un lot B et `notifications-push`. B1 à B3 ne visent ni le profil de l'élève ni le service worker.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
