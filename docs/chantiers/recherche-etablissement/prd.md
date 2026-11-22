# PRD — Chercher son établissement en tapant son nom

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Décision D3 du porteur (programme `retours-terrain-tiassale`, 2026-11-20) : les deux listes « DRENA puis établissement » deviennent un seul champ qui cherche dans les établissements actifs en tapant quelques lettres, la DRENA affichée à côté de chaque résultat. Un seul composant sert l'élève (inscription, « Choisis ta classe », « Changer de classe ») et l'enseignant (inscription, écran d'attente, « Mes établissements »). La direction garde son code d'établissement (memo, hors périmètre).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur (élève, enseignant qui s'inscrit) | Chercher un établissement actif par son nom, son sigle, sa DRENA ou les initiales de son nom ; 20 résultats au plus | Voir un établissement inactif ou en brouillon ; dépasser 300 recherches par minute depuis une adresse |
| Student connecté, Teacher connecté | La même recherche, dans « Choisis ta classe », « Changer de classe », l'écran d'attente et « Mes établissements » | Rejoindre un établissement que le use case refuse (règles inchangées) |
| SchoolStaff, Parent, Team | — (hors périmètre) | — |

Règle d'autorisation : la recherche est publique, comme la liste des établissements d'une DRENA qu'elle remplace (ADR-0029, ADR-0050) ; elle ne renvoie que l'identifiant public, le nom et la DRENA. Les use cases d'inscription et de rattachement rejugent l'établissement envoyé (`RegisterTeacher`, `JoinSchoolWithCode`, `RegisterStudent`, `JoinAsStudent`, `ChangeClassroom`), sans changement.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre l'inscription et voit « Ton établissement », un champ de texte.
2. Il tape « notre dame tiassale » ; après 300 ms sans frappe, la liste montre au plus 20 établissements, chacun avec sa DRENA à droite.
3. Il touche « Collège Notre-Dame de la Paix · Tiassalé » : la liste se replie sur ce seul établissement, coché ; les niveaux de l'étape 2 se chargent.
4. Le reste (niveau, classe, identité, code secret) ne change pas.

L'enseignant fait de même dans « Votre établissement » ; le choix ouvre l'étape 2 de son inscription. Dans l'écran d'attente et « Mes établissements », il choisit puis touche « Rejoindre ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Moins de 2 lettres | Aucune requête ; la liste reste vide (le choix précédent est retiré si l'élève retape) |
| Aucun résultat | « Aucun établissement trouvé » et « Vérifie l'orthographe, ou tape un autre mot du nom ou ta ville. » |
| Plus de 20 résultats | Les 20 premiers, puis « Plus de 20 établissements : ajoute un mot pour affiner. » |
| Au-delà de 300 recherches par minute depuis l'adresse | Réponse 429 : état d'erreur dans la liste, « Réessayer » |
| Réseau coupé, réponse sans la liste | État d'erreur dans la liste, « Réessayer » |
| Sans JavaScript | Un bouton « Chercher » renvoie la page en GET avec les résultats ; l'élève coche puis « Continuer » ; l'enseignant coche puis poursuit (jamais son code secret dans l'adresse) |
| Nouvelle recherche après un choix | Le choix est retiré ; pour l'élève, le niveau et la classe se vident |
| Établissement désactivé, forgé, ou d'un ancien identifiant à l'envoi | Le use case refuse (« établissement introuvable » sous le champ), rien n'est révélé |

## 4. Critères d'acceptation

```gherkin
# CA-1 — tolérance (requête)
Étant donné l'établissement actif « Collège Notre-Dame de la Paix » de la DRENA « Tiassalé »
Quand on cherche « ND paix tiassale », « notre dame », « NOTRE-DAME » ou « paix collège »
Alors il est dans les résultats, avec sa DRENA

# CA-2 — actifs seulement (requête)
Étant donné un établissement inactif et un établissement en brouillon nommés « Lycée Fermé »
Quand on cherche « fermé »
Alors aucun résultat

# CA-3 — bornée (requête)
Étant donné 25 établissements actifs dont le nom contient « lycée »
Quand on cherche « lycee »
Alors 20 résultats, et l'indication qu'il y en a d'autres

# CA-4 — saisie trop courte ou démesurée (requête)
Quand on cherche « a », « » ou 500 caractères
Alors aucune requête n'est faite pour les deux premiers, et la troisième est coupée sans erreur

# CA-5 — point d'entrée public et limité (contrôleur)
Quand un visiteur appelle la recherche avec « tiassale »
Alors la réponse 200 contient le cadre des résultats, chaque résultat avec son nom et sa DRENA, en boutons radio du scope demandé
Et au-delà de 300 appels dans la minute depuis la même adresse, la réponse est 429 avec l'état d'erreur

# CA-6 — classe sur un même wifi (contrôleur)
Quand 40 élèves d'une même adresse font chacun 6 recherches dans la minute
Alors aucune n'est refusée

# CA-7 — inscription élève de bout en bout (système)
Étant donné l'inscription élève ouverte
Quand l'élève tape « tiassale » et choisit son établissement, puis un niveau et une classe, puis remplit le reste
Alors son compte est créé dans cette classe

# CA-8 — inscription enseignant (système et contrôleur)
Quand l'enseignant choisit son établissement par la recherche et termine son inscription
Alors il est rattaché à cet établissement ; la DRENA n'a jamais été demandée

# CA-9 — rejoindre (contrôleur)
Quand un enseignant en attente envoie un établissement choisi par la recherche
Alors il le rejoint, sans DRENA envoyée

# CA-10 — repli sans JavaScript (contrôleur)
Quand la page d'inscription est demandée en GET avec « school_q=tiassale »
Alors les résultats sont rendus dans la page, en boutons radio
Et pour l'enseignant, le formulaire GET de la recherche ne contient aucun champ du code secret
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | rien : les DTO et use cases gardent leur contrat ; la DRENA est déduite de l'établissement par la livraison |
| Infrastructure | une query de lecture : chercher (20 au plus) et retrouver un établissement actif avec sa DRENA |
| Delivery | une route publique de recherche, un contrôleur limité en débit, un concern partagé par les hôtes ; les contrôleurs hôtes lisent `school_q` |
| UI | un partial « champ établissement » et le cadre des résultats ; un contrôleur Stimulus ; la cascade élève, l'inscription enseignant et le rattachement enseignant le rendent |

## 6. Décisions rattachées

- ADR-0142 — une recherche publique bornée remplace les deux listes ; la DRENA déduite de l'établissement.
- UDR-0177 — le champ « Ton établissement » et sa liste de résultats.
- Amende sans les remplacer : UDR-0024 (§2.4, repli des listes), UDR-0081 §3.3 et UDR-0091 §3.2 (étape 1 de la cascade), UDR-0079 (rattachement).

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Gestes pour choisir son établissement | 2 listes, souvent > 100 options | 1 champ, ≤ 20 résultats | 1 champ, ≤ 20 résultats |
| Débit par adresse pour cette étape | 30 / min | ≥ 240 / min (40 élèves × 6) | 300 / min |
