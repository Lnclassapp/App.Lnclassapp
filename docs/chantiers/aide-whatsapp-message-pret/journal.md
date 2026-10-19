# Journal — Message prêt dans le lien WhatsApp de la carte d'aide

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le message réutilise la lecture du shell, qui rend désormais les éléments du détail séparés et le genre | Zéro requête de plus sur chaque page ; le genre est une colonne de la même lecture | Non (UDR-0128 §3.3) |
| 2026-10-16 | Établissement après une virgule, « enseignant / enseignante » selon le genre, « membre de la direction », message simple pour l'équipe | Article de l'établissement et fonction de la direction non enregistrés ; à confirmer par le porteur | Non |
| 2026-10-16 | Le test de la configuration refuse un numéro qui commence par 0 | `wa.me/0584258085` n'ouvre aucune conversation | Non |
| 2026-10-16 | Plus d'identifiant public dans le message | Consigne du porteur : pas d'identifiant interne ; la personne ne le connaît pas | Non (UDR-0128 §2) |
| 2026-10-16 | « Besoin d'aide ? » dans l'en-tête de la direction | Le porteur demande la carte ouverte pour la direction ; elle n'y avait aucun accès | Non (UDR-0128 §3.4, amende UDR-0006) |
| 2026-10-19 | Élève : prénom seul dans le message ; enseignant(e) et direction gardent le nom complet | Décision du porteur : le texte part vers Meta dès le clic (il est dans l'URL), et un élève peut être mineur | Non (UDR-0128 §2, §3.1) |

## Ce qui a dérapé

- La reprise : le premier jet mettait l'identifiant public dans le message et laissait la direction sans carte ; corrigés avant le premier commit.
- Une méthode de test nommée `message` masquait celle de Minitest (message d'échec des assertions) : toutes les assertions plantaient. Renommée `text_of`.
- `bin/rails db:prepare` sur une base de test neuve y joue les seeds : les matières du référentiel entrent en collision avec les factories. Base vidée par `db:truncate_all`.

## Ce qu'on a appris sur la codebase

- La carte d'aide n'était rendue que dans l'en-tête de l'élève et de l'enseignant, et sur la connexion et l'inscription élève : la direction n'avait aucun accès à l'aide depuis le shell.
- Aucune page du shell ne pose de titre (`content_for :title`) : « la page d'où elle écrit » n'a pas de source lisible.
- Le détail de l'en-tête (« Tle D 1 · Lycée … ») était une chaîne déjà jointe : impossible d'en tirer la classe sans la recouper.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Page d'où la personne écrit, dans le message | Pas de titre de page lisible dans le shell | — (à rouvrir si le porteur le demande) |
| Fonction de la direction dans le message | Donnée absente | `espace-direction` (V2 complète) |
| Plusieurs matières de l'enseignant dans le message | Chantier en cours | `enseignant-plusieurs-matieres` |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-16 |
| **PR** | vers `Develop` (lien dans l'index des chantiers à la fusion) |
| **ADR produits** | — |
| **UDR produits** | [UDR-0128](../../decisions/udr/0128-message-pret-dans-le-lien-whatsapp-de-la-carte-d-aide.md) (amende UDR-0061 §3.4) |
