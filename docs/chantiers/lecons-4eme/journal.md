# Journal — Les 5 premières leçons de 4ème

> Rempli **pendant** le chantier, pas reconstitué à la fin. Chantier de contenu : ni memo ni UDR.

Demande : les 5 premières leçons de la progression DPFC 2026-2027 de 4ème en Mathématiques, Français, Physique-Chimie, SVT, Histoire-Géographie et EDHC (30 leçons, format v3 complet comme la 3ème). Méthode : `docs/contenus/prompt-redaction-lot.md`, un rédacteur par leçon, puis un relecteur indépendant par leçon (sympy en Mathématiques et Physique-Chimie), `valider.rb` sur la leçon et sur chaque sujet.

Lots (une PR, trois commits) : A = rang 1 ; B = rangs 2 et 3 ; C = rangs 4 et 5 et README des contenus.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Lots redécoupés : A = rang 1 seul (au lieu des rangs 1 et 2) | Une limite de quota a coupé 7 agents et la machine a redémarré : on met à l'abri ce qui est relu | Non |
| 2026-11-14 | `db/seeds/standard/jeu.yml` reçoit la leçon 1 de chaque matière de 4ème (en fin de liste) et `PRD_COUPLES` passe de 55 à 61 | `StandardTestSet` refuse un couple v3 oublié : sans cela, le semis standard et `standard_manifest_test` échouent. En fin de liste, les 27 premières leçons du test d'activité ne changent pas | Non |

## Ce qui a dérapé

- **Limite de quota** à mi-parcours du rang 2 : 7 agents arrêtés, repris après la levée sans perte de fichier.
- **Corrections réduites à un squelette** (« Étape 1 — Lire. Étape 2 — … ») dans des sujets d'HG : 17 étoffées à la relecture ; consigne ajoutée aux rédacteurs suivants.
- **Références de rang** (« les deux premières propositions ») encore produites par les rédacteurs : retirées à chaque relecture.

## Ce qu'on a appris sur la codebase

- `valider.rb` ne contrôle toujours pas `subjects` : un script hors dépôt le relance avec chaque sujet à la place des 4 problèmes.
- `valider.rb` refuse la clé `blank` sur un `select` d'exercice (« clé inconnue ») alors que des leçons de 3ème en ont ; les rédacteurs écrivent des `select` à un seul trou.
- La 4ème n'avait aucune leçon : ni Develop ni le jeu standard ne la chargeaient. Le chargement de Develop prend tout `lecons-traitees/*/*/*.json` v3 ; le jeu standard exige qu'un couple v3 soit dans son manifeste.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `valider.rb` ne contrôle pas les sujets | Chantier de contenu | À ouvrir (déjà noté en 3ème, Tle C, 1ère) |
| Planche de l'appareil génital masculin absente (`plate`) | Nouvelle sorte de figure : du code | Demande de sorte |
| Leçons de rang 6 et plus en 4ème ; 6ème et 5ème vides | Demande limitée aux 5 premières | Chantiers suivants |

## À trancher

Options prudentes appliquées ; un enseignant de la matière relit avant publication. Données chiffrées des énoncés fictives sauf mention.

- **Manifeste du jeu standard** : la 4ème y est ajoutée (leçon 1 de chaque matière) et la constante du test passe à 61. Option prudente : sans cela la CI est rouge. À confirmer par l'orchestrateur, qui peut préférer un autre rang par matière.

### Rang 1

- HG L1 (peuples XVIe-XVIIIe) : Akan cités = Agni, Baoulé, Abron (lagunaires écartés, rattachement incertain) ; origine des Mandé du Sud mise en commun avec les Mandé du Nord (Mali, Guinée actuels), à vérifier ; Gour venus du « Burkina Faso actuel » (Lobi peut-être Ghana, Sénoufo peut-être Mali) ; villes repères Guiglo (Guéré), Bouaflé (Gouro), Divo (Dida), Kong (Dioula) ; causes des migrations en généralités de manuel, sans Abla Pokou ni dates ; textes et témoins fictifs.
- PC L1 (sources et récepteurs) : notions déduites de l'intitulé (source primaire/secondaire, récepteurs, chaîne source-objet-récepteur) ; récepteurs retenus œil, capteur photo, cellule photovoltaïque (photorésistance et plante écartées) ; nerf optique cité sans rétine ; distinction naturelle/artificielle ajoutée ; contexte du lampadaire solaire ; comptages d'objets en `numeric`.
- SVT L1 (transformations du corps) : découpage en 4 notions choisi par l'auteur (croissance, caractères sexuels primaires/secondaires, changements psychologiques, hygiène et comportements responsables : les deux dernières les plus incertaines) ; premières règles et éjaculations présentées hors du classement primaire/secondaire, sans hormones ; « poussée de croissance plus tôt chez la fille » sans âge ; mesures de taille et de masse fictives. Figures : pas de planche de l'appareil génital masculin (demande de sorte).
- EDHC L1 (droits de l'enfant) : quatre familles de droits (survie, développement, protection, participation) selon la présentation de l'UNICEF, sans article ; aucun numéro d'article ni de loi, Constitution citée en général ; Convention dite ratifiée par la Côte d'Ivoire, sans date ; faits cités : 20 novembre 1989, Charte africaine de 1990, moins de 18 ans, 16 juin ; horaires de travail des enfants fictifs.
- Français L1 (groupe nominal) : la subordonnée relative (qui, que, où ; sans « dont ») est rattachée au groupe nominal comme expansion du nom, à confirmer (sinon la remplacer par la fonction du GN dans la phrase) ; accord de l'adjectif épithète traité ici ; textes supports écrits pour Lnclass.
  - Relecture HG L1 : 4 défauts corrigés. Restent douteux : origine des Gour (Burkina seul ; Sénoufo souvent dits venus du Mali, Lobi du Ghana), des Mandé du Sud (parfois occupants plus anciens refoulés), des Krou (Libéria seul, une partie souvent dite autochtone) ; Mandé du Nord : commerce donné comme cause principale (« fuir une guerre » = Faux) alors que des manuels citent aussi le déclin du Mali ; sujet 3 exercice 3 annonce « trois erreurs » dans l'énoncé (questions faciles).
  - Relecture PC L1 : 6 défauts corrigés. Restent : le miroir classé source secondaire (il réfléchit sans diffuser ; exemple souvent évité) ; le panneau solaire dit « renvoyer un peu de lumière », ce qui brouille le compte récepteur / source secondaire d'un exercice du sujet 2.
  - Relecture SVT L1 : 5 défauts corrigés. Reste : la « poussée » des garçons placée entre 13 et 14 ans, dernier intervalle des données.
  - Relecture EDHC L1 : 5 corrections. Reste : « sensibilisation » attendu dans un sujet alors que la fiche nomme informer, protéger, aider, alerter.
- Maths L1 (décimaux relatifs) : repérer et comparer, addition, soustraction, multiplication ; quotient, notation |a| et règle de suppression des parenthèses non traités (le quotient est peut-être au programme de 4ème) ; « distance à zéro » au lieu de « valeur absolue » ; solde mobile money négatif présenté comme une dette ; montants et températures fictifs.
  - Relecture Français L1 : 9 défauts corrigés (genre d'« épithète », analyses). Restent : « que Awa » sans élision ; « groupe nominal introduit par une préposition » au lieu de « groupe prépositionnel ».
  - Relecture Maths L1 : 435 calculs refaits avec sympy, 3 défauts corrigés. Restent : « a − b mesure l'écart de b à a » (écart algébrique) ; modèle « annuler une dette = (−4) × (−3) ».
