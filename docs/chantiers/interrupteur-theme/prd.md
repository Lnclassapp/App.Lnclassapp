# PRD — Interrupteur clair / sombre

## 1. Contexte

Voir le [memo](memo.md). Demande du porteur du 2026-10-03.

## 2. Acteurs et permissions

| Acteur | Ce qu'il peut faire |
|---|---|
| Tout compte connecté | Basculer entre clair et sombre ; le choix vaut pour toutes les pages de cet appareil |
| Visiteur | Rien de nouveau : les pages publiques suivent le choix déjà fait sur l'appareil, sinon le téléphone |

## 3. Parcours utilisateur

### Chemin nominal

1. Sur un grand écran, l'élève touche l'icône lune à côté de son avatar : la page passe en sombre sans se recharger, l'icône devient un soleil.
2. Il change de page ou recharge : la page s'ouvre directement en sombre.
3. Sur son téléphone, il ouvre « Mon profil » : la carte « Apparence » porte l'interrupteur « Mode sombre ».

### Chemins alternatifs et erreurs

- JavaScript coupé : l'interrupteur n'apparaît pas ; l'application suit le téléphone.
- Cookie inconnu ou forgé : ignoré.

## 4. Critères d'acceptation

```gherkin
# IT-01 — Le choix est rendu par le serveur
Étant donné un cookie theme=dark
Alors <html> porte data-theme="dark" et la meta color-scheme vaut « dark »
Et sans cookie, <html> n'a pas de data-theme et la meta vaut « light dark »
Et un cookie d'une autre valeur est ignoré

# IT-02 — Deux emplacements, un seul visible à chaque largeur
Étant donné un compte connecté sur « Mon profil »
Alors l'en-tête porte un interrupteur role=switch « Mode sombre », caché sous lg
Et le profil porte la carte « Apparence » et son interrupteur, cachée à partir de lg
Et les deux sont cachés tant que JavaScript n'a pas démarré

# IT-03 — Basculer sans recharger, et le choix tient
Étant donné un élève connecté sur grand écran, téléphone en clair
Quand il touche l'interrupteur de l'en-tête
Alors la page passe en sombre sans rechargement et l'interrupteur est coché
Et après un rechargement la page est toujours sombre
Et un second toucher la repasse en clair

# IT-04 — Le choix « clair » l'emporte sur un téléphone sombre, et le bloc du choix « sombre » est celui du téléphone
Étant donné la feuille de style
Alors le bloc du téléphone ne s'applique pas sous data-theme="light"
Et le bloc data-theme="dark" porte exactement les mêmes valeurs

# IT-05 — La page de protection des données dit vrai
Étant donné la page « Protection des données »
Alors elle mentionne le cookie qui retient le choix clair ou sombre
```

## 5. Modélisation préliminaire

| Couche | Ce qui change |
|---|---|
| Domaine, infrastructure, contrôleurs | rien |
| Helpers | `ThemeHelper` (lecture du cookie, liste blanche) |
| UI | `layouts/application` (`data-theme`, meta), `shared/_theme_switch` (icône, carte), en-tête du shell, « Mon profil », contrôleur Stimulus `theme`, feuille de style (deux blocs), locale `shared/theme_switch`, phrase de la page de confidentialité |

## 6. Décisions rattachées

- [UDR-0065](../../decisions/udr/0065-mode-sombre-par-les-tokens.md), amendement du 2026-10-03 — l'interrupteur.
- Pas d'ADR : ni port, ni table ; un cookie de préférence, sans donnée personnelle.

## 7. Mesures

| Métrique | Avant | Après |
|---|---|---|
| Durée ajoutée à la suite système | — | 1,0 s (garde : 15 s) |
| Cookies posés par l'application | 1 (session) | 2 (session, thème) |
