# Journal — Mode sombre de l'application

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-03 | Le mode suit le réglage du téléphone, sans interrupteur | Le porteur a demandé le mode sombre, pas un choix manuel ; un interrupteur demanderait une préférence par compte | Non — UDR-0065 |
| 2026-10-03 | Redéfinir les tokens plutôt qu'écrire des variantes `dark:` | L'application ne passe que par les tokens : une feuille change, aucune vue | Non — UDR-0065 |
| 2026-10-03 | Fonds clairs sous texte blanc, fonds profonds sous texte encre | C'est la seule règle qui garde lisibles à la fois le bouton principal (encre + blanc), le bouton « Supprimer » (erreur + blanc), les pastilles de rôle et le bouton de marque (marque + encre) sans toucher aux vues | Non — UDR-0065 |
| 2026-10-03 | Écran seulement | Une page imprimée en thème sombre serait du texte clair sur papier blanc | Non — UDR-0065 |

## Ce qui a dérapé

- **Le test du bloc sombre a été écrit après la feuille**, pas avant. Pour établir son rouge, il a été rejoué contre la feuille et le gabarit de `Develop` : 5 échecs sur 5, puis vert avec le bloc.
- **Le premier jet de la palette ratait deux paires** : l'encre claire sur l'orange enseignant (4,49) et sur l'or (4,07). Les deux fonds ont été assombris (`#9a5000`, `#8c5c00`) avant d'écrire la feuille ; le test calcule désormais chaque paire.
- **PostgreSQL s'arrête quand le conteneur est recyclé** : relancé avant chaque série de tests (environnement, pas code).

## Ce qu'on a appris sur la codebase

- Tailwind v4 compile `bg-ink/10` en `color-mix(…, var(--color-ink) 10%, …)` : les opacités suivent le token redéfini, sans rien d'autre à faire.
- En clair, le contour de focus `outline-brand` n'a que 2,7:1 sur le papier, sous le 3:1 du WCAG pour les éléments non textuels. Constat préexistant, hors de ce chantier ; le test ne le vérifie qu'en sombre.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Interrupteur clair / sombre dans le profil | Hors périmètre ; demande une préférence par compte | à ouvrir si le porteur le veut |
| Barre d'outils de l'éditeur de texte riche, claire en sombre | Feuille tierce (`trix.css`), pages d'édition seulement | — |
| Contour de focus à 2,7:1 en clair | Préexistant, touche la palette claire validée | à ouvrir (`bugfix`) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-03, en PR brouillon vers `Develop` |
| **PR** | *(voir l'index des chantiers)* |
| **ADR produits** | aucun |
| **UDR produits** | UDR-0065 ; amendement UDR-0005 |
