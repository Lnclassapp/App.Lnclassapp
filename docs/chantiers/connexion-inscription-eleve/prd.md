# PRD — Connexion et inscription de l'élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

La connexion (`/login`, tous les rôles) et l'inscription élève prennent la langue visuelle des écrans élève redessinés : carte bleue d'accueil au téléphone, panneau bleu à gauche dès 1 024 px, « Besoin d'aide ? » en haut, rubriques numérotées en cartes. Les règles d'identité ne changent pas ; la connexion gagne un lien vers l'inscription élève.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur | Se connecter (tous les rôles), créer un compte élève, ouvrir l'aide | Rien de nouveau |

Règles inchangées : débit limité, numéro ivoirien à 10 chiffres, code secret à 4 chiffres, refus dans la mauvaise app (ADR-0050, ADR-0084 à ADR-0086).

## 3. Parcours utilisateur

### Chemin nominal

1. **Connexion** : carte bleue « Heureux de vous revoir » (logo), puis la carte « Connexion » : numéro, code secret avec l'œil et l'info, « Se connecter », « Code secret oublié ? », « Pas encore de compte ? Créer mon compte élève ».
2. **Inscription** : carte bleue « Bienvenue sur Lnclass », puis « Créer ton compte élève » en trois rubriques numérotées : ① Ta classe, ② Toi (nom, prénoms, genre en deux grandes pastilles, numéro), ③ Code secret (code, confirmation, « Les codes concordent. »), « Créer mon compte », « Déjà un compte ? Se connecter ».
3. « Besoin d'aide ? » en haut à droite ouvre la feuille d'aide.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Numéro ou code faux | « Numéro ou code secret incorrect. » dans la carte, focus sur le code (actuel) |
| Mauvaise app | Message actuel (`:wrong_app`) |
| Trop d'essais | Réponse actuelle (429) |
| Inscription par le lien de la classe | Bandeau de la classe dans la rubrique ① avec « Ce n'est pas ta classe ? » (actuel) |
| Erreurs de l'inscription | Sous chaque champ, focus sur le premier champ en erreur (actuel) |
| Codes différents | Message actuel sous la confirmation |
| Thème sombre | Tokens seulement |
| Application Android | Même page dans la coque, sans « Besoin d'aide ? » si la barre native porte déjà l'aide (UDR-0080) |

## 4. Critères d'acceptation

```gherkin
# CA-1 Connexion au téléphone
Étant donné un visiteur sur un écran de 390 px
Quand il ouvre la connexion
Alors il voit la carte bleue avec le logo, puis la carte « Connexion »
Et « Besoin d'aide ? » en haut à droite
Et sous « Code secret oublié ? », le lien « Créer mon compte élève » vers l'inscription élève

# CA-2 Connexion sur ordinateur
Étant donné un écran de 1 280 px
Alors le panneau bleu est à gauche et la carte « Connexion » à droite, centrée en hauteur

# CA-3 Texte au « vous »
Alors les textes de la connexion vouvoient le lecteur

# CA-4 Inscription en trois rubriques
Étant donné un visiteur qui ouvre l'inscription élève
Alors il voit les rubriques 1. Ta classe, 2. Toi, 3. Code secret, chacune dans une carte
Et le genre se choisit par deux grandes pastilles

# CA-5 Inscription réussie
Quand il remplit les trois rubriques et touche « Créer mon compte »
Alors son compte est créé et il arrive sur son accueil (comportement actuel)

# CA-6 Erreurs
Étant donné un numéro de 9 chiffres
Quand il touche « Créer mon compte »
Alors l'erreur s'affiche sous le numéro et le focus va sur ce champ

# CA-7 Lien de la classe
Étant donné une inscription ouverte depuis le lien d'une classe
Alors la rubrique 1 montre le bandeau de la classe et « Ce n'est pas ta classe ? »

# CA-8 Aide
Quand le visiteur touche « Besoin d'aide ? »
Alors la feuille d'aide s'ouvre

# CA-9 Règles inchangées
Alors les tests actuels de connexion, de débit limité et d'inscription passent sans changement de comportement
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | — |
| Delivery | — (aucune route ni paramètre nouveau) |
| UI | `identity/sessions/new` ; `classroom/student_registrations/{new,_form}` ; partials partagés `shared/_auth_welcome` (carte ou panneau bleu) et `shared/_auth_help` (« Besoin d'aide ? » et la feuille) ; pastilles du genre. La cascade `_class_picker` vient du chantier `choix-classe-eleve`. |

## 6. Décisions rattachées

- Pas d'ADR : ni port, ni table, ni contrat.
- [UDR-0088](../../decisions/udr/0088-connexion-et-inscription-eleve-carte-bleue-et-rubriques-numerotees.md) : connexion et inscription élève redessinées.
- La cascade de classe redessinée (pastilles des niveaux, cases des classes) appartient au chantier `choix-classe-eleve` (`_class_picker` partagé).

## 7. Mesures

*Sans objet : pas de requête ajoutée.*
