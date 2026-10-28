# Memo — Refonte de la page de la leçon : fiche de révision, « Prépare interros » et exercices sur feuille

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-28 |
| **Branche** | `feature/refonte-page-lecon` (le cadrage, documentation seule, est commité sur `Develop`) |
| **Programme** | — |

---

## Le problème

Relevé le 2026-10-28 sur la leçon « Propriétés de Thalès dans un triangle » (3ème), en enseignant et en élève, à 390 px et sur ordinateur.

- **La page de la leçon cache sa meilleure partie.** La fiche à l'identique des maquettes (cahier Seyès, figure interactive, lexique) n'est qu'un petit bouton secondaire en tête de page. La page montre surtout une liste de 3 à 5 fiches de révision.
- **Assigner demande quatre écrans.** L'enseignant va du catalogue à la leçon, puis à une fiche de révision, puis à l'un de ses 3 exercices. Une leçon de 4 notions porte 12 exercices et 12 boutons « Assigner », répartis sur 4 pages.
- **Le même contenu existe deux fois.** La fiche des maquettes et les fiches de révision disent la même chose (énoncé, méthode, réciproque, exemple). Deux familles d'exercices coexistent : ceux de la fiche se corrigent dans la page, sans note ; ceux des fiches de révision sont notés et assignables. Rien n'explique la différence à l'écran.
- **Un exercice n'a pas de sujet.** Aucun des 2 206 exercices n'a d'énoncé commun : chaque question porte tout son contexte. On ne peut pas donner un problème (« Le mât, le bâton et les ombres ») suivi de ses questions, comme sur une feuille.
- **L'élève répond une question à la fois**, sans voir l'ensemble. La page de l'exercice montre déjà toutes les questions et leurs propositions, mais en simple aperçu.

Données mesurées le 2026-10-28 sur les 216 leçons semées : 133 leçons ont 3 notions, 79 en ont 4, 4 en ont 5 ; chaque notion a exactement 3 exercices (Comprendre, Appliquer, S'évaluer) de 5 ou 6 questions. Une seule leçon a sa fiche à l'identique des maquettes (Thalès).

## Pour qui

- **L'élève**, sur téléphone, qui révise une leçon puis traite les exercices que son enseignant lui a donnés.
- **L'enseignant**, qui ouvre une leçon pour préparer sa séance et assigne des exercices à sa classe.
- **L'équipe**, qui écrit et importe les fiches et les exercices.

## Pourquoi maintenant

Le pilote enseignants-élèves a démarré le 27 octobre (chantier `mvp-teacher-student`) : la page de la leçon est l'écran le plus ouvert par les deux rôles. La fiche Thalès vient d'être validée en phase 1 du chantier `contenu-en-blocs` ; tant que la page de la leçon ne la met pas en avant, ce travail reste invisible.

## Décisions du porteur (2026-10-28)

Prises avant le grill, à la lecture des captures de l'existant.

1. **La fiche à l'identique des maquettes s'appelle « Fiche de révision »** à l'écran (elle s'appelait « Fiche de cours » en attendant le porteur).
2. **Elle est visible dans la page de la leçon** : ses 150 premiers mots s'affichent, puis « Voir plus » déplie le reste sur place (composant Stimulus « Read More » proposé par le porteur).
3. **Les exercices de la fiche de révision ne s'assignent pas.** Ils servent à s'entraîner, contrairement à ceux de « Prépare interros ».
4. **La section « Révisions de la leçon » s'appelle « Prépare interros ».**
5. **« Prépare interros » contient les exercices de la leçon, avec « Assigner » pour l'enseignant** : un par notion, puis quatre sur la leçon complète *(précisé par Q3 et Q10 : la décision initiale disait « 8 au minimum, 4 + 4 » dans une section « Exercices »)*.
6. **Un exercice se présente comme une feuille** : d'abord une partie « sujet » (l'énoncé, puis les questions numérotées), ensuite les mêmes questions en mode interactif (choix, nombre, texte à trous…) pour que l'élève les traite sur son téléphone.
7. **Les lots qui touchent la fiche de révision** (ex-fiche de cours du chantier `contenu-en-blocs`) sont confiés à Touré, son pilote.

**Ce que le chantier livre, après le grill** : une page de leçon en deux sections, « Fiche de révision » puis « Prépare interros » ; plus de page ni de liste de notions à l'écran ; un exercice « sur feuille » (sujet, puis copie à rendre) ; le format d'import qui porte tout cela ; la leçon Thalès complète comme exemple.

## Hors périmètre

- **L'écriture des exercices sur feuille et des fiches de révision des 215 autres leçons** : chantier de contenu à part, suivi du réimport de toutes les leçons (Q4, Q5).
- **La reprise des données existantes** : Lnclass n'a pas d'utilisateurs réels ; assignations, sessions, lacunes et badges actuels ne sont pas migrés (Q5).
- **Un éditeur de notion ou d'exercice dans l'interface de l'équipe** : tout arrive par l'import (Q9).
- **Assigner un exercice de la fiche de révision** (exercices d'application, « Je m'entraîne ») : ils restent de l'entraînement sans note (décision 3).
- **De nouveaux types de questions** : les cinq existants (choix, nombre, texte à trous, associer, ordonner) suffisent ; l'« indice » des maquettes n'entre pas.
- **Le chantier `contenu-en-blocs`** garde ses lots ouverts (fiches Lentilles et Texte argumentatif) ; seul le nom à l'écran et l'emplacement de la fiche changent ici.
- **Parent** (n'existe pas) et **direction d'établissement** (ne lit pas les leçons) : rien ne change pour eux.
- **Impression ou PDF** de la feuille d'exercice.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Les 3 à 5 fiches par notion (« La propriété de Thalès », « La réciproque »…) s'appellent déjà « Fiche de révision » : que deviennent-elles ? | La fiche essentielle disparaît. Son contenu est dans la grande fiche de révision ; ses exercices sont gardés. | Une seule « Fiche de révision » par leçon. La page d'une notion et sa liste disparaissent ; ses exercices restent et s'affichent dans la page de la leçon. Toute entrée qui menait à une notion (« Fiche à revoir », remédiation, historique de l'élève, accueil) doit mener ailleurs. Les leçons sans fiche cahier (215 sur 216) ont besoin d'une fiche de révision faite du texte de leurs notions. Garder ou non la notion comme donnée (elle porte les exercices et les lacunes) se tranche dans l'ADR. |
| Q2. Où s'affichent les 9 à 15 exercices déjà écrits (Comprendre, Appliquer, S'évaluer de chaque notion) ? *(revu en Q10 et Q11)* | Dans « Prépare interros », rangés par notion. | Deux familles d'exercices sur la page : « Prépare interros » (entraînement libre de l'élève, note et badge, pas d'« Assigner ») et « Exercices » (les 8 à assigner). L'enseignant perd le droit d'assigner les exercices existants : les assignations déjà faites doivent rester lisibles et faisables. Le titre d'une notion devient un intertitre dans « Prépare interros ». |
| Q3. « 4 exercices de notion + 4 de leçon », alors que 133 leçons ont 3 notions et 4 en ont 5 ? | Un exercice par notion, puis 4 sur la leçon complète. | 7 à 9 exercices par leçon (3 à 5 de notion + 4 de leçon). Un exercice de la section « Exercices » est rattaché soit à une notion, soit à la leçon entière : un exercice « leçon complète » n'existe pas aujourd'hui (tout exercice appartient à une notion), c'est un changement de contrat (ADR). La règle « 1 par notion et 4 sur la leçon » est vérifiée à l'import. |
| Q4. Les ~1 700 exercices « sur feuille » des 216 leçons sont-ils écrits par ce chantier ? | Non : le format, l'écran, l'import et les exercices de la leçon Thalès seulement. | L'écriture des autres leçons est un chantier de contenu à part (hors périmètre). Pendant des semaines, presque toutes les leçons ont une section « Exercices » vide : son état vide est un état nominal, pas un cas limite, et l'enseignant ne doit pas croire la leçon cassée. |
| Q5. Que montre la fiche de révision des 215 leçons sans fiche cahier ? | Le texte de leurs notions mis bout à bout, chaque titre de notion en intertitre, au style actuel ; même affichage (150 mots, « Voir plus »). Lnclass n'a pas encore d'utilisateurs réels : toutes les leçons seront réimportées avec leurs contenus après le chantier de contenu, et une section peut rester vide d'ici là. | Deux rendus de la fiche de révision coexistent (cahier ou texte des notions), derrière le même « 150 mots + Voir plus ». **Pas d'utilisateurs réels** : aucune reprise de données à prévoir (assignations, sessions, lacunes et badges existants n'ont pas à être préservés à l'identique) ; les données de démo sont resemées. Chaque section a un état vide propre. |
| Q6. Les pages de notion disparaissent : où mène « Fiche à revoir » ? | Vers « Prépare interros » : la page de la leçon s'ouvre sur les exercices de la notion à revoir, le premier à refaire mis en avant. | La lacune reste attachée à la notion (la notion reste une donnée). « Fiche à revoir » devient « Notion à revoir » à l'écran (vocabulaire à amender, UDR-0130). Chaque entrée (accueil de l'élève, fiche de l'élève dans sa classe, liste de la classe pour l'enseignant, résultat d'une session) pointe vers une ancre de la page de la leçon. Une lacune ne s'ouvre que sur les exercices de « Prépare interros » ; un exercice de la section « Exercices » en ouvre-t-il une ? → Q8. |
| Q7. Comment l'élève traite-t-il un exercice « sur feuille » ? | Toutes les questions sur la page, sous le sujet ; il répond dans l'ordre qu'il veut, puis « Rendre ma copie » : note sur 20 et correction question par question. | Un deuxième mode de session à côté du mode « une question à la fois » (gardé pour « Prépare interros ») : les réponses sont envoyées ensemble, corrigées par le serveur (jamais de réponse dans la page avant le rendu). Une copie à moitié remplie doit survivre à une coupure de réseau ou à un rechargement sur téléphone d'entrée de gamme. Une question sans réponse au rendu compte faux, après confirmation. |
| Q8. Après une mauvaise note sur un exercice de la section « Exercices » ? | Un exercice de notion raté ouvre « Notion à revoir » ; un exercice de leçon complète n'en ouvre pas. L'élève peut refaire ; l'enseignant voit la première copie rendue et la meilleure note. | Les règles actuelles de clôture et de lacune s'appliquent aux exercices de notion ; un exercice de leçon complète n'a pas de notion, donc pas de lacune (règle écrite dans l'ADR). La lecture enseignant d'un exercice assigné affiche deux chiffres (première copie, meilleure note), comme la lecture de la compréhension actuelle. |
| Q9. Les pages de notion de l'équipe (modifier, nouvel exercice, importer, publier) disparaissent : comment l'équipe gère-t-elle notions et exercices ? | Par l'import. Dans la page de la leçon, l'équipe garde le statut et « Publier ». | Le format d'import de la leçon s'étend : sujet d'exercice, exercices de leçon complète, rattachement de chaque exercice à une notion ou à la leçon entière. Les écrans d'édition de notion et d'exercice de l'équipe sortent de l'interface (retirés ou laissés sans lien : se tranche au PRD). Publier une leçon publie sa fiche, ses notions et ses exercices (cascade existante). |
| Q10. Ordre des sections de la page de la leçon ? *(revoit Q2 et la décision 5)* | Deux sections seulement : la fiche de révision, puis « Prépare interros », qui contient les exercices avec « Assigner ». | Il n'y a pas de section « Exercices » distincte : « Prépare interros » **est** la section des exercices assignables (1 par notion + 4 sur la leçon). La place des 9 à 15 exercices déjà écrits est à reposer → Q11. |
| Q11. Que deviennent les 9 à 15 exercices déjà écrits par leçon ? | Ils sont tous remplacés au réimport et ne s'affichent plus. Les rôles Comprendre, Appliquer, S'évaluer aident l'élève à préparer les interrogations : chaque nouvel exercice porte le bon type (fixation ou évaluation) selon ce qu'il travaille. | « Prépare interros » ne montre que les exercices sur feuille ; il est vide pour toutes les leçons sauf Thalès jusqu'au réimport. Pas de nouveau champ : le type fixation ou évaluation existant suffit, il est obligatoire à l'import et s'affiche en étiquette. Le mode « une question à la fois » n'est plus atteint par aucun exercice affiché (voir Questions encore ouvertes). |

## Cas limites identifiés

- Une leçon sans fiche cahier et sans notion rédigée : la section « Fiche de révision » affiche son état vide, la page reste utilisable.
- Une fiche de révision de moins de 150 mots : pas de « Voir plus ».
- JavaScript coupé : la fiche de révision s'affiche en entier, sans « Voir plus ».
- « Voir plus » qui coupe au milieu d'un encadré, d'une formule ou d'une figure interactive : la coupe ne casse ni KaTeX ni la figure.
- Une leçon sans aucun exercice (cas de 215 leçons jusqu'au réimport) : « Prépare interros » affiche un état vide qui dit que les exercices arrivent, pour l'élève comme pour l'enseignant.
- Une leçon dont l'import n'a pas un exercice par notion ou pas quatre exercices de leçon complète : le fichier est refusé avec la raison.
- Un enseignant sans classe du niveau de la leçon : pas d'« Assigner », la phrase actuelle « aucune classe de … » s'affiche.
- Un enseignant dans deux établissements : « Assigner » propose ses classes du niveau dans les deux, comme aujourd'hui.
- Un élève de deux classes à qui le même exercice est assigné deux fois : une seule ligne « à rendre », la plus proche échéance fait foi ; sa copie compte pour les deux.
- Une copie à moitié remplie, puis réseau coupé ou page rechargée : les réponses déjà saisies sont retrouvées.
- « Rendre ma copie » avec des questions sans réponse : confirmation, puis ces questions comptent faux.
- Double clic ou double envoi de « Rendre ma copie » : une seule copie enregistrée.
- Un exercice dépublié ou archivé alors qu'il est assigné ou qu'une copie est en cours : la copie en cours ne se perd pas sans message.
- Une lacune ouverte sur une notion dont l'exercice a été remplacé au réimport : « Notion à revoir » mène à la page de la leçon sans erreur.
- Un exercice de leçon complète raté : aucune « Notion à revoir » ne s'ouvre.
- Un sujet très long (texte + figure) sur un téléphone de 390 px : les questions interactives restent atteignables sans perdre le sujet (repère « Revoir le sujet »).

## Questions encore ouvertes

- **Le mode « une question à la fois »** : plus aucun exercice affiché ne l'utilise après Q11. On le retire du code dans ce chantier (proposition : oui, l'exercice du jour et l'exercice proposé par la remédiation passent eux aussi en copie à rendre), ou on le garde en dette ?
- **La notion reste-t-elle une donnée ?** Elle porte les lacunes et le rattachement d'un exercice. Proposition : oui, sans page ni nom à l'écran ; se tranche dans l'ADR.
- **« 150 mots »** : compte-t-on les mots du texte seulement (titres, formules et légendes exclus) ? Proposition : oui, et la coupe tombe en fin de bloc, jamais au milieu d'un encadré.
- **L'ancienne adresse d'une notion** (`/courses/…/essentials/…`) : redirection vers la page de la leçon (proposition) ou page introuvable ?
