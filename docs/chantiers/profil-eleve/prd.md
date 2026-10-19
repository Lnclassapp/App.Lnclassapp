# PRD — Profil de l'élève aux couleurs Wave et Djamo

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

« Mon profil » de l'élève prend le cadre de l'accueil : carte bleue avec la photo, le nom et « Élève en 3e B », lignes entières à toucher, fenêtres par le bas au téléphone. « Mes informations » gagne l'établissement, et un bouton « Se déconnecter » s'ajoute en bas de la page. Les règles d'identité (code secret, numéro, photo, blocage) ne changent pas.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Voir son profil, changer son nom, sa photo, son code secret, son numéro, se déconnecter | Voir le profil d'un autre |
| Teacher, direction, équipe | Rien ne change pour eux | — |

Règles inchangées : contrôleurs `identity/profile_*`, vérification du code secret, blocage après trop d'essais.

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre « Mon profil » depuis le menu de l'avatar.
2. Carte bleue : photo (ou initiales et « + »), nom, « Élève en 3e B ».
3. « Mes informations » : photo, nom, numéro, classe, établissement (lecture seule), date d'inscription ; chaque ligne modifiable est entière à toucher.
4. « Mon code secret » : une ligne qui ouvre la fenêtre.
5. « Apparence » au téléphone (inchangé), puis « Se déconnecter ».

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Code secret actuel faux (code, numéro) | « Code secret incorrect. » dans la fenêtre (actuel) |
| Trop d'essais | Blocage actuel |
| Photo trop lourde ou illisible | Erreur actuelle dans la fenêtre |
| Élève sans classe | Lignes « Classe » et « Établissement » absentes ; carte bleue sans « Élève en … » |
| < 700 px | Fenêtres par le bas (feuille) |
| ≥ 700 px | Fenêtres au centre, 480 px au plus |
| ≥ 1 024 px | « Mes informations » à gauche ; code secret et « Se déconnecter » à droite ; « Apparence » remplacée par la lune de l'en-tête |

## 4. Critères d'acceptation

```gherkin
# CA-1 Carte bleue
Étant donné une élève de 3e B au Lycée Classique d'Abidjan
Quand elle ouvre « Mon profil »
Alors la carte bleue montre sa photo, son nom et « Élève en 3e B »

# CA-2 Établissement
Alors « Mes informations » montre une ligne « Établissement » : « Lycée Classique d'Abidjan », sans bouton

# CA-3 Lignes à toucher
Quand elle touche n'importe où sur la ligne « Numéro »
Alors la fenêtre du numéro s'ouvre

# CA-4 Fenêtre par le bas
Étant donné un écran de 390 px
Quand elle ouvre la fenêtre du code secret
Alors elle s'ouvre en feuille depuis le bas
Étant donné un écran de 1 280 px
Alors elle s'ouvre au centre, 480 px au plus

# CA-5 Se déconnecter
Quand elle touche « Se déconnecter » en bas du profil
Alors elle est déconnectée (même action que le menu de l'avatar)
Et « Se déconnecter » est toujours dans le menu de l'avatar

# CA-6 Ordinateur
Étant donné un écran de 1 280 px
Alors « Mes informations » est à gauche, le code secret et « Se déconnecter » à droite

# CA-7 Règles inchangées
Alors les tests actuels du nom, de la photo, du code secret et du numéro passent sans changement de comportement

# CA-8 Autres rôles
Étant donné un enseignant sur son profil
Alors sa page est inchangée
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | `ProfileQuery` : `school_name` rempli aussi pour l'élève (établissement de sa classe principale active). |
| Delivery | — |
| UI | `identity/profiles/show` et `_information` (branche élève) ; les quatre fenêtres `identity/profile_{names,photos,pins,contacts}/edit` en feuille sous 700 px ; bouton « Se déconnecter » (`button_to session_path, method: :delete`). |

## 6. Décisions rattachées

- Pas d'ADR : un champ de lecture rempli pour un rôle de plus, sur des tables existantes.
- [UDR-0089](../../decisions/udr/0089-profil-eleve-carte-bleue-lignes-a-toucher-et-se-deconnecter.md) : profil élève redessiné.
- Dépend d'[UDR-0084](../../decisions/udr/0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu, avatar sans photo).

## 7. Mesures

*Sans objet : une jointure de plus dans une requête existante.*
