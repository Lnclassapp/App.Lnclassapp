# Design

Le design system de Lnclass est fixé par [UDR-0005](../decisions/udr/0005-design-system-fondateur.md) (tokens, composants, règles vérifiées) et [UDR-0006](../decisions/udr/0006-shell-applicatif-par-role.md) (shell par rôle, navigation, accueil, toasts, états).

## Où regarder

| Source | Contenu |
|---|---|
| `/design` (dev et test, jamais en production) | Guide vivant : chaque token, chaque composant dans chacune de ses variantes et de ses états, et le shell de chaque rôle (`/design/shell/:role`). Ce qui n'y figure pas n'existe pas. |
| `app/assets/stylesheets/application.tailwind.css` | Le bloc `@theme` : **seule** source des couleurs, polices, rayons, ombres, espacements nommés et animations. |
| `app/helpers/components_helper.rb` | L'API des composants (`ui_button`, `ui_card`, `ui_field`, `ui_modal`…). Une vue appelle le composant et n'en recopie jamais le balisage. |
| `app/views/components/` | Le balisage des composants. |
| `app/helpers/navigation_helper.rb` · `app/views/layouts/shell.html.erb` | Le shell : destinations par rôle, en-tête, barre latérale, barre basse. |
| `test/design/design_tokens_test.rb` | Le garde-fou : refuse `[…]`, `#hex`, `style=`, `dark:`, les couleurs, rayons et ombres par défaut de Tailwind, et les espacements hors échelle. |

## Ajouter ou modifier

1. Un nouveau token passe par le `@theme` **et** par une UDR.
2. Un nouveau composant a sa méthode dans `ComponentsHelper`, son exemple sur `/design` et son test système.
3. [`.interface-design/system.md`](../../.interface-design/system.md) (palette `slate/blue`) est historique : l'UDR-0005 le remplace.
