# Memo — Historique de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planification |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

« Mon historique » (`classroom/student_archives#show`) fonctionne, mais il ne ressemble pas encore aux écrans élève redessinés (`accueil-eleve`, `cours-eleve`, `ma-classe-eleve`, `exercice-eleve`, `profil-eleve`).

## Pour qui

L'élève (Student), avec ou sans classe active, le plus souvent sur un téléphone Android d'entrée de gamme.

## Hors périmètre

- Ce que contient l'historique : `StudentArchiveQuery` (classes rejointes, même quittées ; 200 derniers exercices terminés) ne change pas.
- Le lien vers le résultat d'un exercice : aucune ligne n'est cliquable (UDR-0013).

## Point de départ : la page actuelle

Relevée dans le code le 2026-10-15 (ADR-0036, ADR-0040, UDR-0057) : « Mon historique » avec « Accueil » ; carte « Mes classes » (nom, niveau · établissement, année scolaire) ; carte « Mes exercices terminés » (titre, matière, date, note sur 20, verte dès 10/20) ; 3 lignes puis « Voir plus » ; états vides. On l'atteint seulement depuis l'accueil sans classe et l'écran du compte en attente.

## Maquettes

Toile : https://claude.ai/artifact/V8DwH6oMQcHoxxtHji44B6 (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle page après le profil ? | L'historique (porteur, 2026-10-15). | Même en-tête et même menu de l'avatar ; carte bleue avec le nombre d'exercices terminés ; exercices rangés par mois, avec l'icône de leur matière. |

| Ajoute-t-on « Mon historique » au menu de l'avatar ? | Oui (porteur, 2026-10-15). | Un lien « Mon historique » sous « Mon profil » dans le menu de l'avatar, sur toutes les pages élève : le menu est un fichier partagé. |
| La note devient-elle verte dès 14/20 ou dès 10/20 (`PASS_THRESHOLD`) ? | Dès 14/20 (porteur, 2026-10-15), comme Ma classe. | Le seuil de couleur de la page ne suit plus `PASS_THRESHOLD` (50 %) : 70 %, soit 14/20. |
| Ajoute-t-on un filtre par matière ? | Non (porteur, 2026-10-15). | Aucun filtre. |

## Tablette

- Verticale (820 px) : une seule colonne centrée.
- Horizontale (1180 px) : le menu de gauche revient ; « Mes exercices terminés » à gauche, « Mes classes » à droite.

## Ordinateur

- Même mise en page que la tablette horizontale (1280 px) : menu de gauche, « Mes exercices terminés » à gauche en grand, « Mes classes » à droite.
- « Mon historique » dans le menu du compte, sous « Mon profil ».

## Suite

PRD, UDR-0090 et plan de lots écrits le 2026-10-15 (pas d’ADR). Le code se fait dans une PR, après celle d’`accueil-eleve`.
