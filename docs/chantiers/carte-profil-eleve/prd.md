# PRD — Carte de profil de l'élève dans la barre latérale

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Sur ordinateur, la barre latérale de l'élève n'a pas de carte de profil. Le porteur la veut au gabarit de celle de l'enseignant : avatar, nom complet, classe, puis la navigation.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | voir sa propre carte (lg et plus) | voir celle d'un autre ; la carte n'est pas un lien |
| Teacher, SchoolStaff, Team | inchangé | — |

Aucune règle d'autorisation nouvelle : la carte ne montre que la personne connectée, déjà lue par le shell.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève de la 3ème B du Lycée Moderne de Cocody (LMC) ouvre une page de son espace sur ordinateur.
2. La barre latérale montre sa carte : avatar, « Awa Koné », « 3ème B · LMC » ; dessous, Accueil · Cours · Ma classe.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Sans classe active | « Pas encore de classe » sous le nom |
| Établissement sans sigle | son nom à la place du sigle |
| Nom long | une ligne, tronquée |
| Sans photo | initiales, teinte de l'avatar de la barre du haut |
| Téléphone (< lg) | pas de barre latérale, rien ne change |

## 4. Critères d'acceptation

```gherkin
CA-1
Étant donné une élève de la 3ème B du LMC, connectée sur ordinateur
Quand elle ouvre une page de son espace
Alors la barre latérale commence par une carte avec son avatar, « Awa Koné » et « 3ème B · LMC »
Et la carte de navigation (3 entrées) est 16 px plus bas, sans section secondaire

CA-2
Étant donné un élève sans classe active
Alors sa carte dit « Pas encore de classe » sous son nom

CA-3
Étant donné un élève au nom très long
Alors son nom tient sur une ligne, tronqué, sans élargir la barre latérale

CA-4
Étant donné un élève sans photo
Alors la carte montre ses initiales dans la teinte de l'avatar de la barre du haut
Et avec une photo, la photo

CA-5
Étant donné un enseignant et un élève de la même école
Alors leurs cartes ont la même place, la même largeur et la même hauteur

CA-6
Étant donné un téléphone (390 px)
Alors la barre latérale reste cachée
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | la lecture du shell rend aussi le sigle de l'établissement de l'élève |
| Delivery | — |
| UI | barre latérale ; aide de vue pour la ligne « classe · sigle » ; un texte i18n |

## 6. Décisions rattachées

- ADR : aucun — ni port, ni table, ni contrat ; une colonne de plus dans une lecture existante.
- UDR-0132 §3.1 — amendée le 2026-10-30 (carte de profil de l'élève), au gabarit de UDR-0134 §3.14.
