# Wayfinder Map: Migration Hexagonale Rails 8 (Strangler Fig)

## Destination
Remplacer intégralement l'ancienne architecture de l'application Lnclass par la nouvelle architecture Hexagonale (Entities, Ports, UseCases, Repositories) composant par composant, sans jamais casser la production, en se basant sur le `features_analysis.md`.

## Notes
- **Domaine** : EdTech, Rails 8, Hotwire, PostgreSQL, SolidQueue.
- **Skills recommandées** : `interface-design` (pour l'UI/UX), `domain-modeling` (pour l'architecture), `tdd` (implémentation).
- **Règles d'Or** : Chaque ticket doit générer son ADR (Architecture) et son UDR (Design). Le code doit obéir au `WORKFLOW.md` en 4 phases.

## Decisions so far
*(Vide pour l'instant. Les décisions émergeront au fil de la résolution des tickets).*

## Tickets (Le Plan de Bataille)
- **[TICKET-1: Le Catalogue Pédagogique (Niveaux, Matières, Cours)](docs/tickets/TICKET-1-catalog.md)** — *Status: Terminé (La Frontière franchie)*
- **[TICKET-2: L'Organisation Scolaire (DRENAs, Écoles, Classes)](docs/tickets/TICKET-2-schools.md)** — *Status: Terminé*
- **[TICKET-3: Le Moteur d'Évaluation (Exercices, Sessions, Badges)](docs/tickets/TICKET-3-assessment.md)** — *Status: Terminé*
- **[TICKET-4: L'Authentification & Rôles Utilisateurs](docs/tickets/TICKET-4-auth.md)** — *Status: Ouvert (En cours)*

## Not yet specified (Brouillard de guerre)
- Migration des espaces utilisateurs (`/students`, `/teachers`, `/schoolstaff`). Cela dépendra de la forme que prendront les *UseCases* métiers.
- Refonte de la messagerie interne et des notifications push/toast.
- Stratégie d'importation IA et gestion des tâches asynchrones (SolidQueue).

## Out of scope
- Réécriture du frontend en SPA (React/Vue). L'application reste strictement sur du Hotwire (Turbo/Stimulus).
