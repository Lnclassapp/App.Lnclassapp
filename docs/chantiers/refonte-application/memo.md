# Memo — Refonte de l'application dans un nouveau projet Rails

| | |
|---|---|
| **Type de cycle** | **programme** — voir [`docs/workflows/programme.md`](../../workflows/programme.md) |
| **Statut** | décision — cadrage clos le 2026-09-22, registre des décisions de fondation ouvert |
| **Ouvert le** | 2026-09-18 |
| **Branche** | nouveau dépôt, pas une branche de celui-ci |
| **Gravité** | — décision structurante |

---

## Le problème

L'application actuelle fonctionne pour un rôle sur trois. Ce n'est pas une formule : **aucun élève et aucun enseignant ne peut se connecter** aujourd'hui, seul le rôle `team` dispose d'un espace connecté. Le constat vient de tests système réels écrits le 2026-09-18, pas d'une lecture de code.

Ce symptôme n'est pas isolé, il est la partie visible d'un état plus général, mesuré le même jour :

| Mesure | Valeur |
|---|---|
| Couverture de tests | 45,8 % lignes · 29,5 % branches |
| Fichiers Ruby qu'aucun test ne charge | **114 sur 275** |
| Couverture de la couche delivery | 16,5 % lignes · 8,0 % branches |
| Bugs réels identifiés, non corrigés | ~20, groupés en 8 chantiers |
| Entités et repositories dupliqués racine/contexte | ~13 + 5 |

La suite de tests ne se chargeait plus du tout — une seule `NameError` interrompait les 60 fichiers, et personne ne l'avait vu. Du code mort appelant des constantes inexistantes (`Orm::ClassroomExercise`, `Orm::ClassroomEssential`) a survécu des mois en production parce que rien ne l'exécutait.

## La question à trancher, honnêtement

**Réécrire une application qui marche à moitié est une décision risquée.** Le risque classique est connu : on recommence, on redécouvre les règles métier une par une, on réintroduit les bugs qu'on avait corrigés, et on livre dans un an quelque chose de moins complet que ce qu'on avait.

Ce qui rend la réécriture défendable **ici** et pas ailleurs :

1. **Le métier est documenté et va l'être davantage.** 24 ADR décrivent les décisions structurantes. Ce chantier produit en plus un inventaire exhaustif des features avec leurs règles métier — c'est le vrai livrable de la phase 1, et c'est lui qui protège contre la perte de savoir.
2. **97 % du code est écrit par des agents.** Le coût de réécriture n'est pas le coût habituel d'une réécriture. Ce qui coûte, c'est de décider — pas de taper.
3. **Le passif est architectural, pas cosmétique.** Namespaces dupliqués, contrat de retour des use cases jamais figé (`OpenStruct` partout contre un `Shared::Result` documenté mais inexistant), ports qui ne déclarent pas ce que leurs adaptateurs exposent. Corriger cela dans l'existant revient à réécrire, sans le bénéfice d'un départ propre.
4. **La fenêtre de couverture ne se représentera pas.** [ADR-0024](../../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md) fixe 100 % de couverture, bloquant dès le premier commit. Ce coût est marginal sur un projet neuf et prohibitif en rattrapage — c'est l'argument le plus fort en faveur du nouveau projet.

**Ce qui doit donc être vrai pour que ce programme réussisse** : l'inventaire des features doit être complet **avant** la première ligne de code. Une feature oubliée ici est une feature perdue.

## Pour qui

- **Les élèves et les enseignants ivoiriens**, qui sont aujourd'hui bloqués à la porte.
- **L'équipe**, qui passe de 3 à 13 développeurs sous 6 mois et ne peut pas absorber cette dette en même temps que la croissance.
- **Les agents**, qui écrivent l'essentiel du code et à qui `docs/` doit pouvoir servir de contrat exécutable plutôt que de prose.

## Pourquoi maintenant

Le processus v2 vient d'être livré : workflows, conventions gelées, ADR/UDR normalisés, garde-fous bloquants prouvés, suite de tests réparée. **Le nouveau projet naît donc avec son processus**, au lieu de le recevoir après coup — ce qui était précisément le problème de v1.

## Périmètre

### Dans le périmètre

- **Toutes** les features des 6 contextes bornés — l'inventaire en cours est exhaustif par construction.
- Le **design system** et la **bibliothèque de composants UI**, construits *avant* les écrans.
- Le processus `docs/` appliqué dès le premier commit : conventions, workflows, ADR/UDR, couverture 100 %, garde-fous.

### Hors périmètre

- Le profil **Parent** : déclaré dans l'enum de `Orm::User`, sans table ni modèle. Décision produit déjà prise — non implémenté.
- **ExamSubject** : reporté à la période de préparation aux examens.
- **Retirés du plan le 2026-09-22** (décision du porteur produit) : examens et Prepa BAC, élèves de démonstration, messagerie de classe, rôle Parent, LnclassAI — [`feuille-de-route.md` §5](feuille-de-route.md#retiré-du-plan-2026-09-22).
- La migration des **données de production**, qui est un chantier à part entière et ne doit pas être mélangée au recodage.

## État actuel — la matière à reprendre

| | Nombre |
|---|---:|
| Use cases | 47 |
| Entités | 37 |
| Ports | 31 |
| Repositories | 26 |
| Queries (lecture) | 17 |
| Modèles ORM | 27 |
| Contrôleurs | 53 |
| Vues ERB | 315 (16 383 lignes) |
| Contrôleurs Stimulus | 29 |
| Tables | 45, dont **27 métier** |
| Routes | 235 |

## Ce que le grill a révélé

> Reporté le 2026-09-22 depuis le [journal](journal.md) et l'[inventaire](inventaire/), où les réponses avaient été consignées sans remonter ici.

| Question posée | Réponse | Conséquence sur le programme |
|---|---|---|
| Quelle architecture cible ? | **Hexagonale conservée**, corrigée : un contexte par dossier, ports alignés sur leurs adaptateurs, contrat de retour figé | Décisions de fondation F-01 à F-04 de la [feuille de route](feuille-de-route.md#3-registre-des-décisions-de-fondation), à accepter avant le premier Lot 0 |
| Les features « acquises » tournent-elles vraiment ? | **Non pour trois d'entre elles** : remédiation/lacunes, création d'exercice, « messagerie » (qui n'est qu'un système d'annonces) | Elles sont à **concevoir**, pas à porter : chantier feature complet, grill compris |
| L'autorisation est-elle portée par le domaine ? | **Non** : authentification partout, autorisation presque nulle part. `/team-signup` public crée le rôle le plus privilégié | Règle d'ouverture : chaque use case déclare sa policy, chaque policy a son test ([`securite.md`](securite.md)) |
| Le PIN à 4 chiffres est-il tenable ? | **Oui, sous six compensations indissociables** | [ADR-0025](../../decisions/adr/0025-pin-a-4-chiffres-comme-secret-d-authentification.md) ; le second facteur `team` et la récupération restent à concevoir (F-07, F-08) |
| Le multi-établissements enseignant et le multi-classes élève sont-ils utilisés ? | **Non** : l'interface ne lit que `schools.first` et la classe `primary` | V1 : une école par enseignant, une classe visible par élève. ⚠️ Contredit l'ADR-0004 et l'esprit de l'ADR-0003 → ADR de remplacement (F-06) |
| Quel ordre de livraison ? | **Par parcours complets**, pas par couche : d'abord la boucle équipe → enseignant → élève | Vague 1 = cette boucle ; les autres rôles et features suivent par vagues |
| Le design system avant ou après le premier écran ? | **Avant** — baseline de tokens et quelques composants substantiels, dans le Lot 0 | 0 usage conforme sur 927 rayons dans l'ancien : l'interdiction des valeurs arbitraires est un test, pas une consigne (F-09) |
| Que devient le dépôt actuel ? | **Référence fonctionnelle, jamais mise en ligne** ; ses 8 chantiers de bugs sont à relire, pas à corriger | Les memos de bugs deviennent des cas de test du nouveau projet |
| Que fait-on des données ? | L'ancienne application **n'est pas en ligne** et sa base de développement est vide : il n'y a pas de données utilisateurs à migrer | Reste à reprendre : le **référentiel** (niveaux, séries, matières, DRENA, écoles) et le **contenu** (cours, fiches, exercices) — chantier d'import dédié (F-12) |

## Cas limites identifiés

- Un enseignant réellement multi-établissements s'inscrit en V1 : il ne voit qu'une école — à expliquer dans l'interface, pas à contourner en base.
- Un PIN oublié le premier jour, en nombre : le parcours de récupération est dans le périmètre de la vague 1.
- Des élèves partagent leur PIN (geste de l'argent mobile) : toute feature où l'identité engage une note doit en tenir compte.
- Un nom composé (« Kouassi Jean Baptiste ») : la règle « dernier mot = prénom » de l'ancien est **fausse**, à ne pas reproduire.

## Questions encore ouvertes

Elles sont désormais tenues dans le [registre des décisions de fondation](feuille-de-route.md#3-registre-des-décisions-de-fondation), avec pour chacune la vague qu'elle bloque.
