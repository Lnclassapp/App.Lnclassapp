# PRD — Activation de l'élève : de l'inscription au premier exercice réussi

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Un élève qui vient de s'inscrire arrive sur un accueil qui lui montre sa classe et huit matières, mais aucun exercice : il lui reste 3 à 5 taps et autant de choix pour en atteindre un, et l'activation est à 0 ([memo](memo.md)). Ce chantier met **un exercice, en un tap**, sur l'accueil de tout élève qui n'a encore réussi aucun exercice (le moment « aha » = la première copie à 10/20 ou plus), choisi selon que l'élève est venu seul ou amené par sa classe. Et il fait de l'historique de l'accueil la porte du retour : reprendre ce qui est en cours, refaire ce qui est terminé.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | voir sur son accueil la carte de son premier exercice tant qu'il n'est pas activé ; démarrer ou reprendre cet exercice en un tap ; reprendre une copie en cours et refaire un exercice terminé depuis l'historique | voir un exercice qui n'est pas de son niveau ou pas publié ; refaire pendant la pause de « Recommencer » (ADR-0115) |
| Teacher, SchoolStaff, Parent, Team | — (rien de nouveau) | — |

Règles d'autorisation inchangées : `allow_roles :student` sur l'accueil, la politique de démarrage d'un exercice (`StartExerciseSession` : publication, accès, abonnement, pause). Aucune route nouvelle.

## 3. Parcours utilisateur

### Chemin nominal — l'élève seul

1. Il s'inscrit en choisissant sa classe dans la liste (mode d'entrée « liste »).
2. Il arrive sur l'accueil (« Bienvenue dans ta classe ! », inchangé : un niveau sans exercice publié n'aurait pas de carte, le message ne promet donc rien).
3. Sous la carte de sa classe, la carte « Ton premier exercice » : le titre de l'exercice, « matière · leçon », le bouton « Commencer l'exercice ».
4. Un tap : la copie s'ouvre. Il répond, rend sa copie, voit son résultat.
5. Sa copie atteint 10/20 : à son retour sur l'accueil, la carte a disparu ; l'historique montre la copie avec sa médaille et « Refaire ».

### Chemin nominal — l'élève amené par sa classe

1. Il s'inscrit par le lien ou le code de sa classe (mode d'entrée « lien » ou « code »).
2. Sur l'accueil, la carte « Ton premier exercice » propose le premier devoir de « À faire », avec « matière · Donné par ta classe ». Ce devoir n'est plus dans « À faire ».
3. Sans devoir, la carte propose le même exercice qu'à l'élève seul.

### Chemin nominal — le retour

1. L'élève a laissé un exercice en cours. Sur l'accueil, s'il n'est pas activé, la carte dit « Reprendre à la question N ». S'il est activé, l'historique montre la ligne « En cours » ; un tap la reprend où il l'a laissée.
2. Un exercice terminé, quelle que soit la note : « Refaire » démarre une nouvelle copie (sauf pendant la pause).

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun exercice publié à son niveau | Pas de carte (aucune section vide). |
| Copie terminée sous 10/20 | La carte reste et propose l'exercice suivant de la matière (règle « Prochain exercice »). |
| Élève activé | Pas de carte ; l'accueil de la simplification. |
| Élève sans classe principale active | « Choisis ta classe », pas de carte (inchangé). |
| Pause de « Recommencer » | Pas de « Refaire » sur la ligne ; la ligne mène au résultat (inchangé). |
| Période gratuite finie, sans abonnement | Le démarrage est refusé comme ailleurs (inchangé). |
| Copie en cours mise en carte | Elle n'apparaît pas aussi dans l'historique (une porte par action). |

## 4. Critères d'acceptation

```gherkin
# Requête d'activation
CA-1 Étant donné un élève qui n'a aucune copie
     Quand l'accueil cherche son premier exercice
     Alors il reçoit le premier exercice de sa première matière, dans l'ordre du programme, à commencer

CA-2 Étant donné un élève qui a une copie en cours à son niveau
     Alors la carte propose de la reprendre, à la question suivant ses réponses

CA-3 Étant donné un élève entré par le lien ou le code de sa classe, avec un devoir non commencé
     Alors la carte propose ce devoir, marqué « donné par ta classe »

CA-4 Étant donné un élève entré par la liste, dont la classe a un devoir
     Alors la carte propose le premier exercice du programme, pas le devoir

CA-5 Étant donné un élève dont une copie terminée atteint 10/20 (arrondi)
     Alors il est activé et il n'a pas de carte

CA-6 Étant donné un élève dont les copies terminées sont toutes sous 10/20
     Alors il n'est pas activé

CA-7 Étant donné un niveau sans exercice publié
     Alors il n'y a pas de carte

# Accueil
CA-8 Étant donné un élève non activé avec une classe
     Quand il ouvre l'accueil
     Alors la carte « Ton premier exercice » suit la carte de sa classe, avant « Mes matières », et son bouton démarre l'exercice

CA-9 Étant donné que la carte propose un devoir
     Alors ce devoir n'est pas dans « À faire », et « À faire » est absente s'il était le seul

CA-10 Étant donné qu'un élève vient de s'inscrire par la liste, sans copie
      Quand il suit la redirection vers l'accueil
      Alors la carte « Ton premier exercice » y est, et son bouton démarre l'exercice

# Historique
CA-11 Étant donné un élève activé avec une copie en cours
      Alors l'historique montre sa ligne « En cours », réponses/questions, qui mène à la copie

CA-12 Étant donné une copie terminée à 16/20, hors pause
      Alors l'historique propose « Refaire »

CA-13 Étant donné un élève non activé dont la copie en cours est dans la carte
      Alors l'historique ne la montre pas

CA-14 Étant donné un élève qui n'a ni copie terminée ni copie en cours
      Alors l'historique est absent (inchangé)
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | rien de nouveau : la notation existante (seuil de la moyenne, arrondi au point sur 20) dit « réussi » ; la pause de « Recommencer » reste la règle de « Refaire » |
| Infrastructure | une query de lecture de l'activation dans le contexte `classroom` (activé ?, copie à reprendre, devoir pour l'élève amené, sinon la query « Prochain exercice » existante, matière par matière) ; l'historique de l'accueil lit aussi les copies en cours. Aucune migration, aucun port. |
| Delivery | le contrôleur de l'accueil lit la carte et retire son devoir de « À faire », sa copie de l'historique ; l'inscription ne change pas |
| UI | la partial « Prochain exercice » reprend du service sur l'accueil (variante accueil) ; l'historique gagne la ligne « En cours » et « Refaire » sur toute copie terminée |

## 6. Décisions rattachées

- **Pas d'ADR** : ni port, ni table, ni dépendance, ni contrat qui change ; une query de lecture s'ajoute à côté de celles de l'accueil (CQRS, comme `StudentHomeQuery`), et la query « Prochain exercice » est réutilisée telle quelle.
- UDR-XXXX-activation-premier-exercice — la carte « Ton premier exercice » sur l'accueil, et l'historique qui reprend et refait. Amende UDR-0173 §3 (accueil) et UDR-0132 §3.5 (historique).
- ADR-0049 (pas de traceur), ADR-0062 (indicateurs lus en direct), ADR-0115 (pause de « Recommencer ») : respectés.

## 7. Mesures

La mesure est portée par le chantier `entonnoir-aarrr` (lue en direct, ADR-0062). Ce chantier n'ajoute aucun compteur.

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Taps de l'accueil au premier exercice commencé (élève sans devoir) | 3 à 5 | 1 | 1 |
| Taps de l'accueil au premier devoir commencé (élève amené) | 2 | 1 | 1 |
| Élèves ayant réussi un exercice | 0 (porteur) | > 0 | lu par `entonnoir-aarrr` |
