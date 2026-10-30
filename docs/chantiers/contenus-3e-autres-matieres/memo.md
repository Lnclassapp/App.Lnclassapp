# Memo — Leçons de 3ème en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC, et leurs figures

| | |
|---|---|
| **Type de cycle** | programme |
| **Statut** | en cours (vague 1 et vague 2 lancées) |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/contenus-3e-autres-matieres` |
| **Programme** | — *(ce dossier est le programme `contenus-3e-autres-matieres`)* |

---

## Le problème

En 3ème, seules les mathématiques ont des leçons complètes au format en vigueur : fiche de révision en quatre blocs par notion, un exercice par notion, quatre problèmes, figures qu'on peut manipuler. Les 10 premières leçons de la progression en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC sont des fiches de cours vides ; les anciennes leçons rédigées pour ces matières (3 par matière) sont dans un format retiré et ne s'importent plus. Un élève de 3ème qui prépare une interrogation ou le BEPC n'a donc rien à réviser hors des maths.

Les figures disponibles ont été pensées pour les maths : rien ne dessine une frise, une carte, un schéma d'organe ou une marche de rayons à travers une lentille.

## Pour qui

- **Student** de 3ème, qui révise une leçon avant une interrogation, un devoir ou le BEPC.
- **Teacher**, qui donne les exercices de la leçon à sa classe.
- **Team**, qui importe les fichiers en brouillon, relit et publie.

## Pourquoi maintenant

Les maths de 3ème sont en production au nouveau format. L'année scolaire 2026-2027 a commencé : chaque semaine sans leçon dans les autres matières est une semaine où l'élève de 3ème n'a rien d'autre que les maths.

## Hors périmètre

- Les autres niveaux (4ème, 2nde, Tle…) : ils viendront avec leurs propres chantiers.
- Les leçons au-delà des 10 premières de la progression.
- Un téléchargement dans l'application (PDF, impression) : « téléchargeable » veut dire **fichiers prêts à importer**, rangés dans les contenus et envoyés au porteur.
- L'import lui-même, la relecture par l'équipe et la publication : faits par l'équipe dans l'application.
- Des figures dessinées à la main ou des images importées : toute figure reste une figure paramétrée d'une sorte connue.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que veut dire « téléchargeable » ? | Les fichiers prêts à importer, pas un PDF dans l'application. | Aucune vue de téléchargement. Livrable : 50 fichiers rangés et envoyés au porteur. |
| Le gabarit des maths convient-il aux autres matières ? | Oui, mais avec des figures propres à ces matières. | Les sortes de figures nouvelles passent **avant** la rédaction : la rédaction attend leur livraison. |
| Quelles sortes de figures ajouter ? | Frise chronologique, carte de Côte d'Ivoire, schéma légendé, tracé optique — **et toute figure dont une leçon a besoin** : « nous constituons la base de figures ». | Le chantier commence par l'inventaire des figures de chacune des 50 leçons ; la liste des sortes en sort, pas d'un choix a priori. Elle reste fermée et bornée (une sorte = un amendement de décision). |
| Les 10 leçons de HG ont besoin de cartes au-delà de la Côte d'Ivoire : quels fonds livrer ? | « Les leçons doivent suivre la progression nationale. » | Les fonds de carte sont ceux que le programme demande : Côte d'Ivoire, Afrique, monde. Le contenu de chaque leçon (notions, habiletés) suit la progression nationale 2026-2027, pas un choix de rédaction. |
| Quelle part de questions corrigées automatiquement en Français, HG et EDHC ? | La moitié au moins. | Règle de rédaction contrôlée par le script : sur une leçon, ≥ 50 % des questions sont corrigées automatiquement ; les questions rédigées portent un corrigé modèle et un barème. Constat après le grill : l'import accepte déjà les questions rédigées (barème `points`, critères `criteria`), mais `valider.rb` et le prompt n'admettent que les 4 types à choix — écart de parité. La vague 1 aligne le script sur l'import avant de rédiger (petite PR, aucun changement en production). |
| Les fiches vides de la progression sont-elles déjà publiées en production ? | Non, rien n'est importé. | Aucune règle d'import nouvelle : nos fichiers créent les leçons, la progression complète l'année ensuite (ordre déjà documenté). |
| Comment livrer, sachant qu'une figure nouvelle est refusée tant que son code n'est pas en production, et qu'un chantier n'a qu'une PR ? | D'abord « matière par matière », puis, revu après le plan : **un chantier par matière**, dans l'ordre FR, HG, SVT, PC, EDHC. | Le chantier devient un **programme** de 5 vagues, une matière chacune, avec sa PR et sa mise en production. Chaque vague code les sortes de figures dont sa matière a besoin et que les vagues précédentes n'ont pas livrées. Le Français, sans code, part le premier. |
| « Étude de l'œuvre intégrale n°1 » dépend du roman choisi, et les extraits récents sont protégés. | D'abord « méthode, textes originaux », puis, revu : « une œuvre du programme ». Le programme DPFC n'en impose aucune (« une œuvre intégrale donnée ») ; réponse finale : **mélanger les œuvres**. | La leçon enseigne la démarche des 10 séances du programme (introduire, construire le sens, conclure) en s'appuyant sur plusieurs œuvres étudiées au collège en Côte d'Ivoire, par de **courtes citations** référencées (auteur, titre, date). Les textes longs (résumé, lecture méthodique) sont du domaine public ou écrits pour Lnclass. Règle valable pour toutes les leçons de Français. |

## Cas limites identifiés

- Une leçon qui cite une figure d'une sorte pas encore en production : refusée à l'import (sorte inconnue). D'où la livraison matière par matière.
- Une carte qui nomme une ville ou une région absente du fond : refusée au contrôle, jamais dessinée « à peu près ».
- Une leçon d'histoire sensible (génocide des Tutsi au Rwanda, crises sociopolitiques) : vocabulaire et chiffres de la progression nationale et des sources reconnues, sans opinion ; relecture IA dédiée aux faits et aux dates.
- Une question rédigée sans corrigé modèle ou sans barème : refusée au contrôle.
- Une citation d'œuvre protégée trop longue ou sans référence : refusée à la relecture ; une citation tient en quelques lignes, jamais une page.
- Une sorte de figure dont deux matières ont besoin (schéma fléché : HG, SVT, EDHC) : livrée par la première vague qui en a besoin, réutilisée telle quelle ensuite.
- Une figure qui se lit seulement à la couleur (zones d'une carte) : illisible pour un élève daltonien ou sur un écran de téléphone pâle ; il faut un second repère (motif, légende numérotée).
- Une figure sur un téléphone de 390 px : étiquettes d'une carte ou d'un schéma qui se chevauchent.
- Un élève sans JavaScript ou dont le module ne charge pas : la description de la figure suffit à faire l'exercice.

## Questions encore ouvertes

- Aucune qui bloque la décision. Le détail des sortes (planches de SVT, molécules) sort de l'inventaire des 50 leçons, écrit dans l'ADR.

