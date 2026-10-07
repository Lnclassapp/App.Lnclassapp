# Memo — Amélioration du parcours d'inscription des enseignants

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-07 |
| **Branche** | `feature/inscription-enseignant` |
| **Programme** | — |

---

## Le problème

Un enseignant peut aujourd'hui s'inscrire de **trois** façons :

1. avec le **code d'établissement**, saisi ou reçu dans un lien ;
2. **sans code**, en choisissant sa DRENA, puis son établissement, puis sa matière ;
3. par le **lien d'invitation** d'un collègue.

Trois entrées pour un même acteur, c'est trop : le parcours est confus. Le porteur veut n'en garder que **deux** (2026-10-07) :

- **L'inscription standard, « à froid »** : l'enseignant découvre Lnclass, arrive sur le site ou dans l'application, choisit « Je suis enseignant », puis sélectionne sa DRENA, son établissement et sa matière, et saisit son nom complet, son genre, son contact et son code secret personnel. Il valide.
- **L'inscription par le lien d'invitation d'un collègue.**

La voie « code d'établissement » disparaît.

Constat de l'exploration : le lien « Inviter un collègue » est aujourd'hui **le lien du code d'établissement**, augmenté d'une marque de parrainage. L'équipe (fiche de l'établissement) et la direction (« lien de l'établissement ») partagent aussi ce même lien. Retirer la voie « code » touche donc ces trois liens.

## Pour qui

- **L'enseignant (Teacher)** qui découvre Lnclass seul : l'inscription standard.
- **L'enseignant invité par un collègue** : l'inscription par le lien.
- **Le collègue qui invite**, la **direction** et l'**équipe**, qui partagent aujourd'hui un lien d'établissement : à cadrer.

## Pourquoi maintenant

Constats du porteur (2026-10-07) :

- **Le code d'établissement est introuvable** : les enseignants ne l'ont pas, personne ne le leur transmet, et ils restent bloqués.
- **Le parcours est confus** : trois entrées, l'enseignant ne sait pas laquelle prendre.
- **Trop d'informations sont demandées.**

## Hors périmètre

Ce qu'on ne fera **pas** dans ce chantier. Cette section est la plus utile du memo : c'est elle qui empêche le chantier de gonfler.

- …

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Q1. Pourquoi maintenant ? | Code introuvable, parcours confus, trop d'informations demandées. | Le chantier ne se limite pas à retirer une entrée : il doit aussi alléger ce qui est demandé (à préciser, Q2). |
| Q2. Comment alléger ce qui est demandé ? | Supprimer le code d'établissement ; **un seul champ « nom complet »** au lieu de nom + prénoms, séparé ensuite par une règle ; **réordonner** les informations dans l'ordre du parcours (DRENA → établissement → matière → nom complet, genre, contact → code secret). | Une règle de découpage du nom complet est à fixer (Q3). Les données enregistrées restent « nom » et « prénoms » séparés. Le formulaire change d'ordre : UDR obligatoire. |
| Q3. Quelle règle sépare le nom complet ? | **Premier mot = nom, le reste = prénoms**, affiché en aperçu (« Nom : … · Prénoms : … ») sous le champ ; l'enseignant peut corriger avant de valider. | Un nom en deux mots se corrige à la main. Le découpage doit aussi se faire côté serveur (l'aperçu n'est qu'un confort) ; la correction donne deux champs séparés. Cas d'un seul mot à trancher. |

## Cas limites identifiés

- …

## Questions encore ouvertes

- …
