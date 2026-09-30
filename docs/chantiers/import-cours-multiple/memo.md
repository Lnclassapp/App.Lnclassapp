# Memo — Importer plusieurs fichiers de cours en une fois

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `feature/import-cours-multiple` |
| **Programme** | — |

---

## Le problème

Chaque leçon rédigée avec le prompt de rédaction donne **un fichier** : un cours complet, avec ses fiches essentielles et leurs exercices. L'équipe en produit par dizaines : 4 leçons de Tle D aujourd'hui, et une dizaine de leçons par matière et par niveau pour l'année.

L'écran d'import n'accepte qu'un fichier à la fois, et **un seul import de cours peut tourner à la fois** : un second envoi pendant qu'un import tourne est refusé avec « Un import de ce type est déjà en cours. ». Pour 10 fichiers, l'équipe doit donc ouvrir la modale, choisir le fichier, attendre la fin, et recommencer 10 fois. Le contournement actuel, qui consiste à fusionner les fichiers à la main en ligne de commande, n'est pas à la portée de toute l'équipe.

La durée compte aussi. Mesurée le 2026-09-29 sur la base de développement, avec la vraie chaîne d'import :

| Fichier | Cours | Durée totale | Dont écriture |
|---|---:|---:|---:|
| 4 leçons | 4 | 0,5 s | — (déjà présentes) |
| 40 leçons | 40 | 3,5 s | 2,6 s |
| 200 leçons | 200 | 16,5 s | 12,8 s |

Soit environ **80 ms par cours complet**. Pour 200 cours, l'écriture prend 78 % du temps. Elle se répartit entre le nettoyage du contenu HTML des fiches (3,1 s), l'insertion des propositions (4,3 s) et celle des questions (1,8 s). La validation du schéma prend 1,8 s, la validation métier 1,3 s. À cela s'ajoutent, pour l'utilisateur, jusqu'à 1 s avant que le travail ne soit pris et jusqu'à 3 s avant que l'écran ne se rafraîchisse.

## Pour qui

L'**équipe de contenu Lnclass** (Team), au moment où elle met en ligne les leçons rédigées : elle a un dossier de fichiers de cours et veut tous les importer d'un geste, puis relire un seul bilan.

## Pourquoi maintenant

La production de contenu démarre : la progression 2026-2027 compte 1 056 leçons à rédiger, et le prompt produit un fichier par leçon. Sans import multiple, chaque lot de leçons coûte autant d'allers-retours que de fichiers.

## Hors périmètre

- **Les autres types d'import** (établissements, DRENA, fiches essentielles seules, exercices seuls) : ils gardent un fichier par import.
- **La mise à jour d'un cours existant par import** : un cours déjà présent reste ignoré comme doublon, comme aujourd'hui.
- **L'import depuis une archive `.zip`** ou un dossier distant : on choisit des fichiers `.json` sur son poste.
- **Un nouveau format de fichier** : chaque fichier reste un `lnclass.course-tree` v1 tel que le prompt le produit.
- **Le traitement parallèle** (plusieurs processus pour valider ou nettoyer) : écarté au grill, il complique le moteur pour environ 5 s gagnées sur 500 cours.
- **Les acteurs hors équipe** (Teacher, Student, Parent, SchoolStaff) : ils n'ont pas accès aux imports et n'y gagnent rien.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quand l'équipe choisit 10 fichiers d'un coup, combien d'imports cela crée-t-il ? | **Un seul import, un seul bilan.** | La règle « un seul import de cours en cours à la fois » est conservée. Les fichiers sont traités en un seul passage, validés d'abord puis écrits. Chaque erreur du bilan nomme le fichier d'où elle vient. Le plafond de cours vaut pour l'ensemble des fichiers |
| Sur 10 fichiers, un n'est pas un cours complet (JSON illisible, autre format, autre version). Que fait l'import ? | **Seul ce fichier est refusé**, les autres sont importés. | Le « rejet en bloc » d'aujourd'hui devient un refus **par fichier**. L'import n'est « Rejeté » que si tous les fichiers le sont. Sinon il est « Terminé », et le bilan liste les fichiers refusés avec leur motif. Les cours d'un fichier refusé ne sont pas comptés, puisqu'ils n'ont pas été lus |
| Quelles limites pour un import multiple ? | **50 fichiers au plus, 50 Mo au total, 500 cours au total**, et toujours 20 Mo au plus par fichier. | Une matière entière passe en un envoi : une leçon rédigée pèse environ 85 Ko, donc 500 leçons font environ 42 Mo. Au-delà de 50 fichiers ou de 50 Mo, l'envoi est refusé dans la modale, avant tout traitement. Au-delà de 500 cours, l'import est rejeté. La durée cible a d'abord été fixée à 15 s pour 500 cours, puis revue après mesure (dernière ligne du tableau) |
| À la fin, que montre le bilan d'un import de 10 fichiers ? | **Les totaux d'aujourd'hui, puis une ligne par fichier** : nom, cours importés, ignorés, en erreur, ou « refusé » avec son motif. | Le rapport d'import doit garder, pour chaque fichier, son nom et ses compteurs, ce qu'il ne sait pas faire aujourd'hui. L'écran de suivi gagne cette liste, donc une vue change. Un import d'un seul fichier montre aussi sa ligne, pour que l'écran reste le même dans les deux cas |
| Dans un même envoi, deux fichiers contiennent le même cours (même nom, niveau, matière, série). Que fait l'import ? | **Aucun des deux n'est importé** : chacun est en erreur et nomme l'autre fichier. | Nouvelle règle, propre à l'envoi de plusieurs fichiers : deux fichiers qui portent le même cours sont sans doute deux versions de la même leçon. Trois règles restent **inchangées** : un cours déjà en base est ignoré, puisque le doublon avec la base est examiné d'abord ; un cours répété dans **un même** fichier est ignoré ; l'ordre des fichiers ne change rien au résultat |
| Pour 10 leçons, l'attente vient surtout de l'écran de suivi (3 s entre deux rafraîchissements) et d'au plus 1 s avant la prise en charge. Que fait-on de ce délai ? | **Rafraîchir toutes les 1 s** tant que l'import tourne, toujours sans connexion en direct. | L'optimisation porte sur **deux mesures** : la durée du traitement (cible : dernière ligne du tableau) et le délai entre l'envoi et le bilan à l'écran (cible : moins de 3 s pour 10 cours). Le choix de l'ADR-0039, sans connexion en direct, tient toujours. Tous les imports profitent du rafraîchissement, pas seulement celui des cours |
| Dans la modale, que voit l'équipe entre le choix des fichiers et l'envoi ? | **Le nombre de fichiers, leur taille totale et la liste des noms**, sans retrait possible. Au-delà de 50 fichiers ou de 50 Mo, un message s'affiche tout de suite et le bouton d'import se désactive. | La modale d'import des cours gagne un comportement côté navigateur. Le serveur refait **toujours** les mêmes contrôles, car le navigateur n'est pas une garantie. Pour corriger une sélection, on choisit de nouveau les fichiers |
| Après mesure : la cible de 15 s pour 500 cours ne tient pas sans paralléliser (contrôle du format 5 s, nettoyage du HTML 7 s, règles métier 3 s, incompressibles). Quelle cible fige-t-on ? | **20 s au plus pour 500 cours**, deux fois plus vite qu'aujourd'hui (environ 40 s), avec des gains sûrs et sans parallélisme. | Trois gains, mesurés un par un : le HTML n'est plus analysé deux fois ; les contenus riches s'écrivent sans conversion ligne par ligne (3,2 s pour 200 cours) ; propositions et questions s'écrivent par copie en masse (6 s pour 200 cours). La répartition entre plusieurs processus est **hors périmètre**. La mesure « avant » et « après » est rejouée par un script versionné, sur les mêmes fichiers |

Angles d'attaque sans objet, vérifiés : **multi-appartenance élève** et **permissions inter-établissements**. L'import de cours ne touche ni les élèves ni les établissements, et seule l'équipe y a accès, quel que soit son rôle interne. Un membre qui perd ce droit pendant l'import fait échouer l'import, comme aujourd'hui.

## Cas limites identifiés

- **Aucun fichier choisi** : l'envoi est impossible, et le serveur refuse une requête qui arriverait sans fichier.
- **Un seul fichier** : le comportement est celui d'aujourd'hui, et le bilan montre une ligne de fichier.
- **50 fichiers, 500 cours, 50 Mo** : l'import passe. **51 fichiers ou plus de 50 Mo** : l'envoi est refusé dans la modale, puis par le serveur. **501 cours au total** : l'import est rejeté et rien n'est écrit.
- **Un fichier de plus de 20 Mo** dans l'envoi : il est refusé à l'envoi, comme aujourd'hui.
- **Un fichier sans aucun cours** (`courses: []`) : il est accepté, sa ligne affiche 0.
- **Tous les fichiers refusés** (formats faux, JSON illisibles) : l'import est « Rejeté » et rien n'est écrit.
- **Deux fichiers qui portent le même nom** (choisis dans deux dossiers) : les lignes du bilan doivent rester distinctes.
- **Le même cours dans deux fichiers et déjà en base** : ignoré dans les deux fichiers, parce que le doublon avec la base passe avant la règle entre fichiers.
- **Un import interrompu** pendant l'écriture (redéploiement) : les cours déjà écrits restent, et l'import passe « Échoué » au bout de 10 min, comme aujourd'hui. Renvoyer les mêmes fichiers ignore les cours déjà écrits et importe le reste.
- **Un cours est entier ou absent** : jamais un cours sans une partie de ses fiches ou de ses exercices, même si l'écriture est accélérée.
- **Un nom de fichier avec des accents ou des espaces** (« Leçon 1 — Limites.json ») : il s'affiche tel quel dans le bilan.

## Questions encore ouvertes

- **Qui garde les fichiers envoyés, et combien de temps ?** Aujourd'hui, le fichier d'un import est conservé avec son rapport. À trancher en phase 2 : garder chaque fichier, ou seulement leurs noms, tailles et empreintes.
- **Les proxys de production acceptent-ils un envoi de 50 Mo ?** À vérifier en phase 2 sur l'hébergeur, avant de figer la limite dans le PRD.
- **Le rafraîchissement à 1 s tient-il avec plusieurs membres qui suivent un import en même temps ?** La requête est légère, et l'hypothèse retenue est que oui.
