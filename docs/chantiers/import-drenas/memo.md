# Memo — Import des DRENA par fichier

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-09-29 |
| **Branche** | `feature/import-drenas` |
| **Programme** | — |

---

## Le problème

Une production vierge est inutilisable tant que l'équipe n'a pas saisi les 41 DRENA une par une dans le formulaire. Aujourd'hui, c'est la seule façon de les créer : la décision d'origine sur le format d'import excluait explicitement les DRENA.

L'import des établissements ne crée jamais de DRENA : il les cherche par leur slug. Le fichier des établissements 2026 (3 851 écoles) référence les 41 DRENA par slug (`abidjan-1`, `bouake-2`, `san-pedro`…). Tant qu'elles n'existent pas toutes, avec exactement ces slugs, chaque école rattachée à une DRENA manquante est rejetée.

Il y a donc 41 saisies manuelles, et chaque faute de frappe dans un nom décale le slug et casse l'import des écoles.

## Pour qui

**Team** : le membre de l'équipe qui met un environnement en service, juste avant d'importer les établissements.

## Pourquoi maintenant

Le fichier des établissements 2026 est prêt à être importé. La saisie des DRENA est la seule étape manuelle qui reste avant, et elle est source d'erreurs.

## Hors périmètre

- Mettre à jour ou renommer une DRENA par import : un import ne met jamais à jour l'existant (règle commune à tous les imports).
- Supprimer une DRENA par import.
- Importer des DRENA et leurs établissements dans un même fichier.
- Toute donnée d'une DRENA autre que son nom (code officiel, région, direction, contacts).
- Parent, Student, Teacher, SchoolStaff : aucun accès à l'import, qui reste un outil de l'équipe.

## Ce que le grill a révélé

> Rempli après la session de questions adverses. Un memo qui sort du grill inchangé signifie que le grill a été mal fait.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Les DRENA sont 41 et changent rarement : le besoin revient-il vraiment, ou est-ce un remplissage unique ? | Récurrent (staging, production, recettes, réinitialisations), et l'équipe importe elle-même depuis l'écran Imports, comme pour les écoles | Il faut un cinquième type d'import complet : écran, rapport, job, et élargissement de la contrainte sur les types de rapport. La décision « les DRENA ne s'importent pas » (ADR-0034, ADR-0039) est renversée : un nouvel ADR est obligatoire |
| « Bouake 1 » saisie à la main, puis « Bouaké 1 » dans le fichier : doublon ou nouvelle DRENA ? | Doublon. Est doublon toute ligne dont le slug, tiré du nom, est celui d'une DRENA existante ou d'une ligne plus haut dans le fichier. Elle est ignorée et comptée, même si l'orthographe diffère | L'import ne corrige jamais un nom : une DRENA mal accentuée se corrige à l'écran. Et comme le slug est figé, une DRENA renommée à l'écran garde son ancien slug. Nouveau cas limite : un nom déjà pris en base sous un autre slug doit être une erreur de la ligne, jamais un plantage |
| Où l'équipe lance-t-elle l'import ? (précisé par le porteur pendant le grill) | Le bouton de création d'une DRENA reste, et un bouton « Importer » se place à côté, sur la liste des DRENA | La liste des DRENA change : une UDR est obligatoire. Le bouton mène au parcours d'import existant, avec le type DRENA présélectionné |
| Le fichier doit-il pouvoir imposer le slug d'une DRENA ? | Non, mais le porteur veut des slugs préfixés : `drena-abidjan-1`, et non `abidjan-1`. Argument avancé : le référencement. Objection notée : le slug d'une DRENA n'apparaît dans aucune URL (les URL portent l'identifiant public) et les pages DRENA sont privées. Le porteur maintient le préfixe | La règle de dérivation du slug change pour toute DRENA créée, par import comme par formulaire. Les seeds, les exemples d'import d'écoles et les tests qui citent `abidjan-1` changent. L'ADR du chantier doit le trancher |
| D'où vient le préfixe ? | Il est automatique : le nom reste « Abidjan 1 », et le slug est « drena- » suivi du slug du nom | Le fichier d'import ne porte que `name`. Le formulaire et l'import partagent la même règle : un seul endroit la définit |
| L'import des établissements accepte-t-il encore `abidjan-1` ? | Non, il n'accepte que le slug exact | Le fichier des établissements 2026 (3 851 écoles) doit être réécrit avec les slugs préfixés, et il fait partie des livrables. Tout fichier d'écoles existant qui cite l'ancien slug est désormais rejeté ligne par ligne |
| Que deviennent les DRENA déjà saisies avec l'ancien slug ? | D'abord « migration des slugs », puis corrigé par le porteur : l'application est en phase de test et sera redéployée à vide. Aucune DRENA n'existe dans un environnement à conserver | Pas de migration de données, et le slug figé ne connaît aucune exception. Les bases de développement et de test se recréent par les seeds, qui adoptent la nouvelle règle |

## Cas limites identifiés

- **Fichier vide** (aucune DRENA) : l'import se termine avec zéro DRENA créée, comme les autres types.
- **Même DRENA deux fois dans le fichier**, par exemple « Grand-Bassam » et « Grand Bassam », qui donnent le même slug : la seconde ligne est un doublon, ignorée et comptée.
- **Nom déjà pris en base sous un autre slug**, par exemple une DRENA renommée à l'écran : c'est une erreur de la ligne, notée à `name`, et jamais un échec de tout l'import.
- **Nom vide, fait d'espaces ou de plus de 80 caractères** : c'est une erreur de la ligne, avec les mêmes règles que le formulaire.
- **Nom sans lettre latine** (« ??? ») : il donnerait le slug nu « drena ». C'est une erreur de la ligne, car une DRENA doit avoir un slug qui la distingue.
- **Fichier réimporté** : toutes ses lignes sont des doublons, et rien n'est modifié.
- **Import de DRENA lancé pendant un import d'écoles** : ce sont deux types différents, donc rien ne les bloque. Les écoles qui citent une DRENA pas encore créée sont rejetées ligne par ligne, et un réimport les rattrape.
- **Import de DRENA pendant un autre import de DRENA** : il est refusé, puisqu'un seul import actif est permis par type.
- **Clé inconnue sur une ligne** (`code`, `region`…) : elle est rejetée par le schéma, comme pour les autres formats.

## Questions encore ouvertes

- Le plafond de lignes par fichier. Proposition : 500, soit plus de dix fois les 41 DRENA du pays. À figer dans le PRD.
