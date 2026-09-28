# Memo — Barème des classes modifiable par l'équipe

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-09-28 |
| **Branche** | `feature/bareme-classes` |
| **Programme** | — |

---

## Le problème

Le nombre de classes qu'un établissement reçoit à sa création (import) ou par la génération des classes manquantes est un **barème figé dans le code** : 4 classes de 6ème dans un établissement public, 6 classes de 2nde par série liée, 2 Tle C… (ADR-0030). L'équipe connaît le terrain mieux que le code : quand un lycée public ouvre plutôt 8 classes de 6ème, ou quand une nouvelle série arrive en 1ère, elle doit demander une livraison. D'ici là, chaque établissement importé reçoit le mauvais nombre de classes, corrigé ensuite à la main, classe par classe.

Demande du porteur (2026-09-28) : « rends le barème modifiable par l'équipe depuis l'écran ».

## Pour qui

L'équipe (Team, tout sous-rôle), dans son référentiel, à côté des niveaux, des séries et des matières, **avant** d'importer des établissements ou de lancer la génération des classes manquantes.

Indirectement : les enseignants et les élèves des établissements importés ensuite, qui trouvent le bon nombre de classes.

## Pourquoi maintenant

La production est ouverte depuis le 2026-09-27 ; l'équipe importe et génère maintenant les classes de près de 3 900 établissements. Chaque import fait avec un barème inadapté produit des classes à corriger à la main.

## Hors périmètre

- **Modifier les classes déjà créées** : un changement du barème ne touche aucune classe existante, ni en nombre, ni en nom. Il vaut pour les prochains imports et les prochaines générations.
- Un barème **par établissement**, par DRENA ou par année scolaire : un seul barème, public d'un côté, privé (et mixte) de l'autre.
- Un barème distinct pour les établissements **mixtes** : ils suivent toujours le privé (ADR-0030).
- Un barème distinct pour les **collèges** : un collège prend les lignes du premier cycle du barème de son type.
- Changer le **nom** des classes générées (« 6ème 1 », « Tle D 3 ») ou leur effectif maximal.
- Historique consultable à l'écran des changements du barème : le journal d'audit les garde, sans écran.
- Revenir au barème d'origine d'un clic.
- Toute régénération ou complétion d'établissements déjà dotés (ADR-0056 : hors périmètre, inchangé).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que devient la production au déploiement : un barème vide ne génère plus rien ? | Non : le barème actuel est **repris** tel quel sur le référentiel existant, par code de niveau et de série. « Par série liée » devient une ligne par série liée **au moment de la reprise**. | Reprise de données au déploiement ; le test prouve le même résultat que l'ancien barème (lycée public 89, lycée privé 44, collège public 28, collège privé 12 avec les séries A1, A2, C, D). |
| Une série liée à la 2nde **après** le déploiement reçoit-elle 6 classes, comme avant ? | Oui, depuis la décision du porteur (D1) : le lien remplit le barème avec les défauts ; le « par série » implicite disparaît pourtant du calcul : chaque couple niveau × série a son propre nombre. Un couple sans nombre vaut **0** et apparaît « Non défini » à l'écran, à renseigner. | Décision par défaut à confirmer (D1). Le rapport d'import et de génération compte ces lignes comme sautées, pour que l'oubli se voie. |
| Et un nouveau niveau du premier cycle ? | 4/2 ou 10/4 s'il porte un code de l'ancien barème, sinon « Non défini », 0 classe, compté comme niveau sauté. | D1. |
| Une ligne à 0 et une ligne non définie, c'est pareil ? | Même effet (aucune classe), sens différent : 0 est un choix de l'équipe, « non défini » un oubli. Le rapport ne compte que l'oubli. | Distinction gardée en base (absence de ligne) et à l'écran (badge d'alerte). |
| Quelles lignes montre l'écran ? | Celles que le référentiel rend possibles : un niveau du premier cycle = une ligne ; un niveau du second cycle = une ligne par série liée. Un niveau du second cycle sans série est affiché « aucune série liée », sans nombre. | Les lignes suivent le référentiel ; aucune saisie libre de niveau ou de série. |
| Un couple délié garde-t-il son nombre ? | Oui, en base, sans effet : il n'apparaît plus et ne génère rien. Relié, il retrouve son nombre. Un niveau ou une série supprimé emporte ses lignes. | Les lignes partent avec leur niveau ou leur série, sans jamais retenir leur suppression ; aucune règle de plus sur « délier ». |
| Qui peut modifier ? Tout membre de l'équipe ? | Oui, comme le référentiel (niveaux, séries, matières). | Politique « équipe », sans sous-rôle. |
| Faut-il tracer les changements ? | Oui, chaque nombre changé : qui, quand, quelle ligne, quel type, avant et après. | Une entrée du journal d'audit par nombre changé ; rien si la valeur ne change pas. |
| Un changement pendant une génération en cours ? | La génération lit le barème une fois, au démarrage : elle finit avec l'ancien. L'import aussi (lecture à la préparation). | Dit dans l'ADR ; aucun verrou. |
| Borne des nombres ? | 0 à 30 : au-delà, c'est une erreur de frappe (le plus gros barème actuel est 10). | Saisie refusée hors de 0–30, entier seulement. |
| Modifier public et privé d'une même ligne en deux gestes ? | Non : une modale par ligne, avec les deux nombres. | « Modifier » dans le menu ⋮ de la ligne ; la modale porte public et privé. |
| L'équipe comprend-elle que les classes existantes ne bougent pas ? | À dire en toutes lettres, sur l'écran et dans la modale. | Bandeau d'information permanent + rappel dans la modale. |
| Les totaux par établissement (lycée public 89…) servent-ils ? | Oui : c'est ce que l'équipe vérifie avant d'importer. | Quatre totaux en tête : collège / lycée × public / privé et mixte, recalculés à chaque modification. |
| L'écran Niveaux affiche un badge « Hors génération des classes » pour un code inconnu du plan. Il reste juste ? | Non : n'importe quel niveau peut maintenant avoir des classes, s'il a un nombre au barème. | Le badge dit désormais « Hors barème » : aucun nombre positif au barème. Amendement UDR-0032. |

## Décisions par défaut, toutes décidées par le porteur le 2026-09-28

| # | Décision prise par défaut | Alternative écartée |
|---|---|---|
| D1 | **Décidé par le porteur le 2026-09-28** : « renseigner ces valeurs automatiquement à chaque nouvelle série liée ». Un couple niveau × série lié par l'équipe reçoit ses nombres par défaut — 2nde, 1ère et tout autre niveau du second cycle : public 6 / privé 3 ; Tle : C 2/1, D 6/3, A1 3/2, A2 2/2, autre série 6/3. Un niveau du premier cycle créé ensuite reçoit 4/2 (codes `6eme`, `5eme`) ou 10/4 (`4eme`, `3eme`) ; tout autre niveau du premier cycle n'a pas de règle sûre et reste « Non défini ». Une ligne existante n'est jamais écrasée ; délier garde les lignes (relier retrouve le nombre). Chaque remplissage est tracé (`classroom_plan.changed`, source `auto`). Reste « Non défini » : un couple lié avant le déploiement et absent de l'ancien barème, ou un niveau sans règle. | Ligne manquante à 0 sans défaut (proposition initiale) : refusée par le porteur. |
| D2 | **Décidé par le porteur le 2026-09-28**, tel que proposé : Les mixtes suivent le barème privé ; pas de colonne « mixte ». | Troisième colonne : aucun besoin exprimé, et ADR-0030 le tranche. |
| D3 | **Décidé par le porteur le 2026-09-28**, tel que proposé : Bornes 0 à 30 classes par ligne. | Aucune borne : une faute de frappe (300) créerait des centaines de classes à l'import suivant. |
| D4 | **Décidé par le porteur le 2026-09-28**, tel que proposé : Une modale par ligne (public et privé ensemble), ouverte depuis le menu ⋮. | Saisie en ligne dans le tableau : deux champs par ligne × 15 lignes, et le téléphone la rend illisible. |
| D5 | **Décidé par le porteur le 2026-09-28**, tel que proposé : Aucun historique à l'écran ; le journal d'audit suffit. | Onglet d'historique : pas demandé. |

## Cas limites identifiés

- Référentiel vide : l'écran le dit et renvoie vers Niveaux ; totaux à 0.
- Niveau du second cycle sans série liée : ligne affichée sans nombre, renvoi vers Séries ; à l'import, le niveau est sauté et compté (comme avant).
- Saisie « 3,5 », « -1 », « 31 », vide : refusée dans la modale, 422, valeurs gardées.
- Même valeur ressaisie : succès, aucune écriture ni audit.
- Ligne déliée entre l'ouverture de la modale et l'envoi : 404.
- Un non-membre de l'équipe : 403 (écran et modification).

## Questions encore ouvertes

- Aucune : D1 à D5 sont décidées par le porteur (2026-09-28).
