# PRD — Bleu unique de marque

## 1. Contexte

L'application porte quatre bleus (logo, boutons, second bouton, icône) et un bouton qui change de couleur en sombre. Le porteur fait du bleu roi #0861E1 le seul bleu de Lnclass. Ce chantier change des jetons, des classes de vues, des valeurs hors jetons et des images ; aucune règle métier.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Tous | voir le même bleu partout, texte blanc sur fond bleu | — |

Aucune règle d'autorisation touchée.

## 3. Parcours utilisateur

### Chemin nominal

1. Un élève ouvre la connexion : carte bleue #0861E1, texte blanc, bouton « Se connecter » du même bleu.
2. Il arrive sur son accueil : bandeau bleu à texte blanc, bouton « Le faire maintenant » du même bleu, logo baobab sur le même bleu.
3. Il passe en mode sombre : les fonds bleus ne changent pas, les liens bleus s'éclaircissent.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Page d'erreur 404 / 500, page hors connexion | Même bleu, bouton à texte blanc |
| Enseignant | Bandeau orange à encre foncée (inchangé), boutons au bleu unique |
| Un développeur écrit `bg-brand-strong` ou `bg-brand text-white` | Le test de conception échoue |
| `ui_button(variant: :brand)` | `ArgumentError` |

## 4. Critères d'acceptation

```gherkin
Scénario: un seul bleu en clair
  Étant donné la feuille de style
  Alors brand et brand-strong valent #0861e1, brand-soft #e7f0fd et on-brand #ffffff

Scénario: le même fond bleu en sombre, plus d'inversion
  Étant donné les deux blocs sombres
  Alors brand vaut #0861e1 et on-brand #ffffff, brand-strong #8bb8f9 et brand-soft #122949

Scénario: contrastes
  Alors on-brand sur brand fait 5,52:1 dans les deux modes
  Et brand-strong se lit (≥ 4,5) sur paper, white et brand-soft dans les deux modes
  Et brand se voit (≥ 3) sur paper et white dans les deux modes

Scénario: plus de fond brand-strong ni de texte blanc/noir sur bleu
  Étant donné les vues, helpers et contrôleurs Stimulus
  Alors aucun n'écrit bg-brand-strong (hors pastille du jeton sur /design)
  Et aucune chaîne de classes n'associe bg-brand à text-white ou text-ink au même préfixe

Scénario: un seul bouton bleu
  Quand une vue demande ui_button variant :brand
  Alors une ArgumentError est levée

Scénario: hors des jetons
  Alors theme_color, les pages d'erreur, la page hors connexion et les couleurs Android élèves valent #0861e1
  Et aucun ancien bleu (#00a0ff, #0070b3, #e5f5ff, #7fd0ff, #132c42, #1e6bae, #0f6fde) n'y reste

Scénario: bandeau par rôle
  Quand le bandeau de l'élève est rendu
  Alors il porte bg-brand et text-on-brand
  Quand celui de l'enseignant est rendu
  Alors il porte bg-teacher et text-band-ink

Scénario: thème d'annonce Ciel
  Alors Ciel reprend les jetons de marque, clair et sombre, et les neuf autres thèmes sont inchangés
```

Tests : `test/design/brand_blue_test.rb`, `dark_mode_test.rb`, `design_tokens_test.rb`, `announcement_themes_test.rb`, `shared_classes_test.rb`, `test/helpers/components_helper_test.rb`, `test/views/shared/navigation/home_band_test.rb`, plus les sélecteurs des tests de contrôleurs et système mis à jour.

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | — |
| Infrastructure | — |
| Delivery | `config.x.pwa[:theme_color]` |
| UI | jetons `@theme` et blocs sombres, utilitaires `ui-button-*`, `ComponentsHelper`, `NavigationHelper#role_ink_classes`, ~40 vues, 2 contrôleurs Stimulus, pages `public/`, service worker (numéro de cache), images, ressources Android |

## 6. Décisions rattachées

- Pas d'ADR : ni port, ni table, ni dépendance, ni contrat ; seules des valeurs de l'ADR-0082 §4.1 et de l'ADR-0086 §4.8 changent, annotées sur place.
- UDR-XXXX-bleu-unique-de-marque — amende UDR-0136 (et UDR-0005, 0065, 0075, 0078, 0080).
