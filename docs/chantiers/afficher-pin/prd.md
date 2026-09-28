# PRD — Afficher le code PIN

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier.

## 1. Contexte

Chaque champ de PIN gagne un bouton œil qui affiche puis remasque le code ([memo](memo.md)). Le domaine ne change pas : mêmes paramètres envoyés, mêmes validations, PIN toujours vidé au re-rendu.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Visiteur, élève, enseignant, équipe | afficher et remasquer le PIN qu'il est en train de saisir | voir un PIN enregistré (inchangé : aucun PIN n'est jamais renvoyé) |

## 3. Critères d'acceptation

```gherkin
# AP-01
Étant donné l'un des 13 champs PIN (connexion, invitation, inscription enseignant, inscription élève,
  profil : PIN actuel / nouveau / confirmation, changement de numéro, PIN oublié)
Alors le champ est de type « password »
Et il porte, à droite et à l'intérieur, un bouton « Afficher le code » (type « button », aria-pressed="false",
  aria-controls = l'id du champ), icône œil, cible de 48 px

# AP-02
Étant donné la page de connexion et un PIN saisi
Quand l'utilisateur clique sur « Afficher le code »
Alors le PIN se lit en clair, le bouton s'appelle « Masquer le code », aria-pressed="true", icône œil barré
Et le focus est toujours dans le champ
Quand il clique sur « Masquer le code »
Alors le PIN est de nouveau masqué

# AP-03
Étant donné une inscription (élève par code de classe) et le PIN affiché
Quand l'envoi échoue en 422
Alors le PIN revient vide et masqué, le bouton « Afficher le code » est toujours là

# AP-04
Étant donné la modale « Changer mon PIN » du profil
Alors chacun des trois champs se démasque et se remasque indépendamment

# AP-05
Étant donné un champ PIN, au clavier
Quand l'utilisateur fait Tab depuis le champ
Alors le focus est sur le bouton « Afficher le code »
Et Entrée, puis Espace, affichent puis remasquent le PIN

# AP-06
Étant donné un PIN affiché
Quand le formulaire est envoyé
Alors le champ repasse en « password » avant l'envoi

# AP-07
Étant donné n'importe quelle page chargée ou restaurée du cache
Alors le PIN est masqué ; rien n'est mémorisé

# AP-08
Étant donné un navigateur sans JavaScript
Alors le bouton n'est pas affiché (attribut hidden) et le champ reste utilisable

# AP-09
Étant donné un écran de 390 px de large
Alors AP-02 à AP-05 tiennent, le bouton reste dans le champ et la page ne défile pas en largeur

# AP-10
Étant donné ces parcours dans Chrome
Alors la console ne relève aucune erreur JavaScript
```

## 4. Hors périmètre

Voir le [memo](memo.md#hors-périmètre).

## 5. Décisions

- [UDR-0051](../../decisions/udr/0051-afficher-le-code-pin.md) : option `reveal:` de `ui_field` et contrôleur `password-reveal` ; amende l'UDR-0005 (composant champ).
- Pas d'ADR : aucune architecture ne bouge. La CSP stricte (ADR-0049) est respectée : aucun script en ligne, un contrôleur du bundle.
