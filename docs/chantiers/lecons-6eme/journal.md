# Journal — Les 5 premières leçons de 6ème

> Contenu seul (pas de memo ni d'UDR). Demande du porteur, relayée par l'orchestrateur le 2026-11-13 : 5 leçons par matière.
> Méthode : celle des 60 leçons de 3ème (`docs/contenus/prompt-redaction-lot.md`, format v3 complet), au niveau 6ème.

## Périmètre

Rangs 1 à 5 de la progression DPFC 2026-2027 de 6ème, en Mathématiques, Français, Physique-Chimie, SVT,
Histoire-Géographie et EDHC : 30 leçons, rangées dans `docs/contenus/lecons-traitees/6eme/<matière>/`.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-13 | Les couples `6eme/<matière>` sont ajoutés à la fin de `lecons:` dans `db/seeds/standard/jeu.yml` | Sans eux, `StandardTestSet` refuse le manifeste (`couple_missing`) ; en fin de liste, les 27 premières leçons du test d'activité ne bougent pas | Non |
| 2026-11-14 | `PRD_COUPLES` du test du manifeste suit le nombre de couples (57 au lot A) | Le test compte les couples du jeu standard | Non |

## Ce qui a dérapé

## À trancher

À faire valider par un enseignant de la matière avant publication.

- PC L1 circuit : symboles pile/lampe/moteur décrits en mots (aucune sorte de figure « circuit ») ; moteur en leçon 1 ?; liste des conducteurs/isolants.
- Maths L4 segments : médiatrice non traitée ; report au compas sans « cercle » (leçon 7) ; hm/dam dans le tableau.
- Maths L5 pavés/cylindres : aucun calcul d'aire ni de volume du cylindre (disque = leçon 7) ; aire totale du pavé $2(Ll+Lh+lh)$ à confirmer en 6ème ; pas de 1 dm³ = 1 L.
- Maths L2 droites et points : perpendiculaires et parallèles traitées ici (peut-être leçon 8 « Angles ») ; notations [AB), ∈, ⊥, ∥ ; pas de figure de demi-droite (sorte geometry) ; figures à 9 points (lisibilité 390 px).
- Maths L3 relatifs : pas d'addition/soustraction (5ème ?) ; « distance à zéro » gardée légère ; vocabulaire « abscisse », « +3 = 3 ».
- Maths L1 entiers : division euclidienne, multiples, diviseurs non traités ; classes, « pas », « abscisse » ; droites graduées bornées à 100 (sorte number_line).
- Maths L3 relatifs : le signe de 0 n'est pas tranché (« 0 s'écrit sans signe ; il est son propre opposé ») : les manuels divergent (ni positif ni négatif / les deux). Confirmer la convention du manuel ivoirien.
- PC L2 commande : série/dérivation et va-et-vient non traités ; symbole de l'interrupteur décrit en mots, celui du bouton-poussoir non décrit.
- PC L3 court-circuit : surcharge de multiprise présentée comme règle de prudence ; disjoncteur près du compteur CIE ; gestes de sécurité écrits pour un enfant (à relire) ; prix illustratifs.
- PC L4 solides et liquides : volume d'un solide par déplacement d'eau inclus (notion 4) — à retirer s'il n'est pas dans cette leçon ; lecture au bas du ménisque (eau).
- PC L5 gaz : masse de l'air ≈ 1,3 g/L présentée comme approchée (à retirer si hors leçon) ; composition de l'air non traitée ; conduite à tenir en cas d'odeur de gaz.
- Pas de sorte de figure « schéma électrique » : les symboles (pile, lampe, moteur, interrupteur) sont décrits en mots, les figures sont des schémas fléchés (diagram). Une sorte « circuit » serait à demander.
- Les valeurs des exercices (prix, mesures, masses) sont illustratives ; les textes supports sont écrits pour Lnclass.
- `valider.rb` ne contrôle pas les sujets : un script hors dépôt les a passés un par un (dette à reprendre dans le script).
