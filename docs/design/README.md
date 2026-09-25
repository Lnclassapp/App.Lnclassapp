# Design

> 🚧 **En construction.** Ce pilier fera l'objet d'une session dédiée. Ce fichier n'est qu'un point d'entrée honnête vers ce qui existe aujourd'hui.

## Ce qui existe

| Source | Contenu | Limite |
|---|---|---|
| [`../../.interface-design/system.md`](../../.interface-design/system.md) | Orientation visuelle « Étude Premium » : couleurs, typographie, profondeurs et hover, iconographie, règle d'épuration. Rattaché à UDR-0001. | 27 lignes — pas de tokens d'espacement, pas de grille, pas de breakpoints, pas d'états focus/disabled/error, pas d'accessibilité |
| `app/assets/stylesheets/application.tailwind.css` | Les **vrais** design tokens, en Tailwind v4 CSS-first (bloc `@theme`) : palette, rayons, polices, animations | C'est la source de vérité technique, mais elle n'est documentée nulle part |
| `app/views/components/` | 23 partials ERB : `_button`, `_card`, `_badge`, `_modal`, `_dropdown`, `_toast`, `_empty_state`, `_page_header`… | Pas de catalogue, pas de démo, pas de documentation d'usage |
| [`../decisions/udr/`](../decisions/udr/) | Les décisions d'interface déjà prises | Couverture partielle |

## Ce qui manque

- **Un design system complet** : espacements, grille, breakpoints, états (focus, disabled, error, loading), règles d'accessibilité.
- **Un catalogue de composants** visualisable — aujourd'hui il faut lire le code ERB pour savoir ce qui existe, ce qui pousse à recréer des composants en double.
- **Des mocks haute fidélité** servant de prototype avant implémentation.
- La résolution du doublon `app/views/shared/_empty_state` vs `app/views/components/_empty_state`.

## En attendant

Toute vue nouvelle ou modifiée passe par une [UDR](../decisions/udr/TEMPLATE.md), et réutilise les partials de `app/views/components/` plutôt que d'en créer de nouveaux. En cas de doute sur un token, la source de vérité est le bloc `@theme` de `application.tailwind.css`, pas une valeur en dur.
