# PRD — Un standard de test pour Lnclass

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Lnclass teste chaque endroit sur des données différentes et ne vérifie l'affichage des leçons qu'à la main ([memo](memo.md)). Le chantier pose un **jeu de test standard** décrit dans le dépôt et recréé à l'identique en local, en PR et (sur décision) sur Develop ; un **test d'affichage automatique** des fichiers v3 ; un **rôle par environnement** ; une **preuve de vague** ; et une **boucle courte** pour voir en local une leçon qu'on vient de modifier.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe (rédacteur, testeur) en local | Charger le jeu standard ; prévisualiser un fichier de leçon ; lancer la preuve d'une vague | Lancer l'aperçu sur Develop, Staging ou production (refusé hors développement) |
| CI (PR, train) | Importer et rendre les leçons dans la base de test | Publier quoi que ce soit dans un environnement |
| Déploiement Develop | Charger le jeu standard (décision ouverte n° 1) | Supprimer des données sans accord du porteur |
| Déploiement Staging | Ajouter les leçons v3 absentes (décision ouverte n° 2) | Remplacer une leçon déjà présente (hors exercices des leçons à sujets, ADR-0122) |
| Production | — inchangé : import manuel du validé | Recevoir un chargement automatique |
| Comptes fictifs (direction, enseignant, élève, équipe) | Se connecter avec le PIN de test connu | Exister en production (le jeu standard n'y est jamais joué) |

Aucune règle d'autorisation applicative nouvelle : les comptes fictifs passent par les politiques existantes.

## 3. Parcours utilisateur

### Chemin nominal — boucle courte d'un rédacteur

1. Il modifie `…/tle-d/mathematiques/<leçon>.json`.
2. Il lance l'aperçu sur ce fichier : le fichier est validé (`valider.rb`), importé seul dans la base locale (la leçon de même titre est remplacée), publiée, et l'adresse de la leçon s'affiche avec un compte élève de la bonne série.
3. En mode suivi, chaque enregistrement du fichier recharge la leçon ; il rafraîchit la page.
4. Il ouvre une PR : la CI rend les fichiers touchés à 390 px et sur ordinateur.
5. Fusionnée, Develop recharge la leçon au déploiement suivant (si elle est dans ce que Develop charge).

### Chemin nominal — testeur

1. `bin/tester-pr <PR> --demo` charge le jeu standard : 2 établissements, 14 classes, comptes par rôle, une leçon par matière et par niveau-série.
2. Il retrouve les mêmes comptes et les mêmes leçons que dans l'environnement de la PR.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Le JSON est refusé par `valider.rb` ou par l'import | L'aperçu s'arrête, affiche les erreurs, ne touche pas la base ; le test d'affichage échoue avec le code de refus |
| L'aperçu est lancé hors développement local | Refus explicite, rien n'est importé |
| Un fichier du manifeste manque ou n'est pas v3 | Le test du manifeste échoue ; le jeu standard ne se charge pas à moitié |
| La page déborde à 390 px, affiche `**`, ou une figure manque | Le test d'affichage échoue en nommant le fichier, la largeur et le défaut |
| Une PR touche plus de fichiers que 5 min n'en rendent | Le rendu se découpe en parts de ≤ 5 min |
| Le jeu standard est rejoué | Rien n'est créé en double |

## 4. Critères d'acceptation

```gherkin
Fonctionnalité: Jeu de test standard

  Scénario: le manifeste décrit le jeu
    Étant donné le manifeste du jeu standard
    Alors il nomme 2 établissements, un lycée et un collège
    Et une classe par niveau-série existant dans le programme
    Et un compte par rôle : direction, enseignant, élève, équipe
    Et pour chaque dossier niveau-série et chaque matière ayant au moins un fichier v3, exactement un fichier v3 existant

  Scénario: le jeu standard est recréé à l'identique
    Étant donné une base vide
    Quand on charge le jeu standard deux fois
    Alors la base contient exactement les établissements, classes, comptes et leçons publiées du manifeste
    Et le second chargement n'a rien créé

  Scénario: même jeu en local et en PR
    Quand on lance bin/tester-pr --demo
    Ou quand l'environnement de PR sème ses données
    Alors c'est le jeu standard qui est chargé

  Scénario: un enseignant dans les deux établissements
    Étant donné le jeu standard chargé
    Alors un enseignant est affecté à une classe du lycée et à une classe du collège

Fonctionnalité: Leçons vérifiées par la machine

  Scénario: une leçon conforme passe
    Étant donné un fichier v3 conforme
    Quand le test d'affichage le rend à 390 px et sur ordinateur
    Alors la page n'a pas de défilement horizontal
    Et aucun « ** » n'apparaît dans le texte affiché
    Et chaque figure du fichier est visible
    Et le test passe

  Scénario: chaque défaut fait échouer le test
    Étant donné un fichier v3 dont une formule déborde, ou qui contient « **gras** » mal fermé, ou dont une figure est vide, ou que l'import refuse
    Quand le test d'affichage le rend
    Alors le test échoue en nommant le fichier, la largeur et le défaut

  Scénario: une PR ne rend que ce qu'elle touche
    Étant donné une PR qui modifie 3 fichiers de leçons
    Quand bin/ci-quiet joue le niveau pr
    Alors le test d'affichage rend ces 3 fichiers et eux seuls

  Scénario: le train rend tout dans le budget
    Quand la CI du train tourne
    Alors tous les fichiers v3 sont rendus
    Et aucune tâche ne dépasse 5 minutes

  Scénario: rien n'est publié ailleurs
    Quand le test d'affichage tourne
    Alors il n'écrit que dans la base de test

Fonctionnalité: Aperçu local d'un fichier

  Scénario: modifier puis voir
    Étant donné le jeu standard chargé en local
    Quand on lance l'aperçu sur un fichier v3 modifié
    Alors seule la leçon de ce fichier est réimportée et publiée
    Et l'adresse de la leçon est affichée

  Scénario: refus hors développement
    Quand on lance l'aperçu avec RAILS_ENV=production
    Alors il refuse et n'importe rien

Fonctionnalité: Un rôle par environnement

  Scénario: Staging reçoit tout sans écraser (si décision n° 2 acceptée)
    Étant donné une leçon déjà présente sur Staging
    Quand Staging se déploie
    Alors les leçons v3 absentes sont ajoutées
    Et la leçon présente n'est pas modifiée

  Scénario: Develop charge le jeu standard sans rien supprimer (option a de la décision n° 1)
    Quand Develop se déploie
    Alors les leçons du jeu standard sont chargées
    Et aucune autre leçon n'est créée, modifiée ni supprimée

  Scénario: la production ne charge rien
    Quand la production se déploie
    Alors aucune leçon n'est chargée

Fonctionnalité: Preuve d'une vague

  Scénario: preuve complète
    Quand on lance la preuve sur le dossier d'une vague
    Alors valider.rb passe sur ses fichiers
    Et le test d'affichage passe sur ses fichiers
    Et une capture à 390 px et une sur ordinateur sont produites pour une leçon par matière, hors du dépôt
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | `Catalog::StandardTestSet` (lecture et contrôle du manifeste, Ruby pur) ; `AutomaticLoadStage` étendu : Develop → jeu standard, Staging → ajout des absentes |
| Infrastructure | manifeste `db/seeds/standard/jeu.yml` ; seed `db/seeds/standard.rb` ; source de leçons filtrée par le manifeste ; `ContentTreeWriter` réutilisé (pas de nouveau port) |
| Delivery | `bin/apercu-lecon <fichier> [--suivre]`, `bin/preuve-vague <dossier>` ; `bin/tester-pr --demo` → jeu standard, `--tout-contenu` → ancien jeu |
| Tests | `test/system/catalog/lesson_rendering_test.rb` (fichiers en paramètre), découpage au train dans `.github/workflows/ci.yml` |
| UI | aucune vue modifiée — pas d'UDR |

## 6. Décisions rattachées

- ADR-XXXX-standard-de-test — jeu de test standard, rôle des environnements, test d'affichage des leçons. Amende ADR-0122 (Staging) et ADR-0123 (Develop).
- UDR : aucune, aucune vue créée ni modifiée.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Fichiers v3 vérifiés à l'écran par la machine | 0 / 417 | 417 / 417 au train | |
| Durée de `bin/tester-pr --demo` (données) | ~1 min (toutes les leçons) | < 30 s | |
| Boucle « modifier un JSON → le voir » en local | import manuel par l'écran Imports | < 15 s, une commande | |
| Tâche CI la plus longue | ≤ 5 min | ≤ 5 min | |
