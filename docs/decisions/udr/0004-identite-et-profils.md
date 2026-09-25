# UDR-0004 : Identité et Profils (Identity UI)

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | — |
| **Chantier** | — |
| **ADR lié** | [ADR-0021 — Migration de la gestion de l'identité vers le domaine pur](../adr/0021-gestion-de-l-identite.md) |
| **Remplacé par** | — |

---

## 1. Contexte

L'interface utilisateur de l'application permet à 5 types de rôles (`student`, `teacher`, `team`, `parent`, `school_admin`) d'accéder à la plateforme.
Leur expérience utilisateur diverge radicalement après la connexion. Bien que le design de ces profils ait déjà été établi dans des tickets précédents, le refactoring du module Identity côté backend nécessitait une décision sur l'impact UI.

## 2. Décision

- **Zero-Break Migration** : L'interface utilisateur ne doit subir aucune régression lors de la migration du modèle d'identité. Le `CurrentUserConcern` continue de fournir un objet compatible en surface, mais sécurisé par la logique métier pure du nouveau backend.
- **Composants Isolés** : Les vues (`_drawer.html.erb`, `_sidebar.html.erb`) qui se basent sur des informations du profil (ex: affichage de `current_user.avatar` ou du `public_id`) ont été conservées sans altération pour garantir l'expérience familière des utilisateurs et la fluidité des navigations Turbo.

## 3. Règles d'implémentation

> Contrat d'exécution — reprise de la section « Interactions et Accessibilité » du document d'origine.

**Structure**
- Composants concernés : `_drawer.html.erb`, `_sidebar.html.erb`. Ils lisent le profil via `CurrentUserConcern` (`current_user.avatar`, `public_id`) et **ne doivent pas être altérés** par la migration Identity.

**Comportement**
- Les redirections post-login (`after_sign_in_path_for`) guident chaque rôle vers son tableau de bord respectif (`teachers_feed_path`, `students_feed_path`, etc.).
- Les toasts Hotwire (alertes Turbo) continuent d'afficher les erreurs d'autorisation.

**Tokens**
- — *(non documenté)*

**États obligatoires**
- Erreur : toasts Hotwire pour les erreurs d'autorisation.
- Vide · Chargement · Succès : — *(non documenté)*

**Accessibilité**
- — *(non documenté)*

## 4. Conséquences

— *(non documenté à l'époque)*
