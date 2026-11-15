# Journal — Skills d'opérations en production

> Chantier du 2026-11-14 : transformer des tâches récurrentes en skills (`.claude/skills/`). Pas de code applicatif : ni memo ni UDR.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Étendre `/lecon`, `/annonce`, `/publier-prod` (renvois vers `/prod-agent`) ; créer `/prod-agent` et `/test-ecrans` | Décision du porteur : ne pas dupliquer | Non |
| 2026-11-14 | `/prod-agent` agit par le navigateur seulement, import et publication sans demander, tout destructif sur accord écrit nommant l'objet, dans la session qui exécute | Décision du porteur | Non |
| 2026-11-14 | `/test-ecrans` ne code pas ; elle propose une `/retouche` | Décision du porteur | Non |

## À trancher

- [ ] 2026-11-14 · skills-operations-prod · Le compte équipe exige un code à six chiffres que la session ne peut pas produire : `/prod-agent` s'arrête sans lui, il vient du porteur avec sa demande — appliqué : arrêt avec « code de vérification attendu » ; autres : second facteur dédié à un compte « Agent Claude » ; recommandé : l'option appliquée
- [ ] 2026-11-14 · skills-operations-prod · Adresse de Develop prise dans la doc (`app-develop.lnclass.com`), non vérifiée — appliqué : celle-ci ; autres : variable d'environnement ; recommandé : l'option appliquée
- [ ] 2026-11-14 · skills-operations-prod · Variables `LNCLASS_TEAM_CONTACT` et `LNCLASS_TEAM_PIN` absentes de cette session : essai connecté de `/prod-agent` et pages équipe de `/test-ecrans` non joués — appliqué : essai à blanc (pages publiques, arrêt sur la variable manquante) ; recommandé : poser les variables puis rejouer sur Staging

## Retouches

- …

## Ce qui a dérapé

- Rien.

## Ce qu'on a appris sur la codebase

- Connexion : « Numéro de téléphone » + « Code secret » (PIN 4 chiffres), puis code à six chiffres pour l'équipe.
- Essai à blanc de `/test-ecrans` sur Staging (accueil, `/login` : 12 captures, 390/768/1440 × clair/sombre) : aucun débordement, aucune erreur console. Mineur : une icône « i » sans texte sous « code secret à 4 chiffres » sur `/login` (à 390 px, thème sombre).

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Essai connecté de `/prod-agent` | Variables équipe absentes | À rejouer sur Staging |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
