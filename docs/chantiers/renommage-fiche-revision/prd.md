# PRD — « Fiche de cours » et « Fiche de révision » à l'écran

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

À l'écran, « Cours » devient **« Fiche de cours »** et « Fiche essentielle » devient **« Fiche de révision »**. Ce sont les noms des fiches que l'équipe a dessinées et que la plateforme va intégrer ([memo](memo.md)). Seuls les textes d'interface et la doc qui fait foi changent : le code, les tables, les clés d'import et les adresses restent `Course` / `Essential`.

## 2. Acteurs et permissions

Aucune permission ne change. Chaque acteur lit les nouveaux mots sur les écrans qu'il voyait déjà.

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Student | Lire « Fiche de cours », « Fiche de révision », « Révisions de la leçon », « Fiches à revoir » sur ses écrans | — (aucun droit nouveau) |
| Teacher | Lire les nouveaux noms sur son accueil, ses classes et les fiches vues depuis une classe | — |
| Team | Lire et créer des « fiches de cours » et « fiches de révision » dans ses formulaires, imports, référentiel et publication en cascade | — |
| Visiteur | Lire les nouveaux noms sur l'accueil public, la mission et les CGU | — |
| Parent, SchoolStaff | — | Aucun écran de contenu aujourd'hui : rien ne change pour eux |

Règles d'autorisation inchangées (politiques de lecture du catalogue et de la classe en place).

## 3. Parcours utilisateur

### Chemin nominal

1. L'élève ouvre l'onglet **« Cours »**, qui ne change pas, puis une fiche de cours. Le compteur du catalogue dit « 12 fiches de cours ».
2. Dans la page de la fiche de cours, la liste s'intitule **« Révisions de la leçon »**. Chaque ligne mène à une **fiche de révision**.
3. La page de la fiche de révision a pour surtitre « Fiche de révision ». S'il a une lacune, le bandeau dit **« Fiche à revoir »**.
4. Sur son accueil, la rubrique des lacunes s'intitule **« Fiches à revoir »**.
5. L'équipe crée une fiche de cours. Le toast dit « Fiche de cours « X » créée (brouillon). »
6. L'équipe crée ensuite une fiche de révision. Le toast dit « Fiche de révision « Y » créée (brouillon). »

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Fiche de cours sans fiche de révision publiée | « Aucune fiche de révision pour cette fiche de cours. » |
| Catalogue vide | « Aucune fiche de cours pour l'instant » |
| L'équipe publie une fiche de révision dont la fiche de cours est en brouillon | « La fiche de cours de cette fiche de révision n'est pas publiée : publiez d'abord la fiche de cours. » |
| L'équipe publie un exercice dont les parents sont en brouillon | « Publiez d'abord la fiche de révision et sa fiche de cours. » |
| Lien partagé avant le renommage (`/courses/<c>/essentials/<e>`) | La page s'ouvre, sans redirection |
| Texte « en cours », « Import en cours », « Chargement en cours » | Inchangé |

## 4. Critères d'acceptation

```gherkin
Scénario: plus aucune « fiche essentielle » à l'écran
  Étant donné les fichiers de traduction français
  Alors aucune valeur ne contient « essentielle » ni « essentielles », quelle que soit la casse

Scénario: la liste des fiches d'un cours
  Étant donné une fiche de cours publiée avec une fiche de révision publiée
  Quand un élève de ce niveau ouvre la fiche de cours dans le catalogue
  Alors il lit le titre « Révisions de la leçon »
  Et la même valeur exacte s'affiche dans la page de cette fiche de cours vue depuis une classe

Scénario: le surtitre de la fiche de révision
  Quand l'élève ouvre une fiche de révision
  Alors il lit « Fiche de révision »
  Et il ne lit pas « Fiche essentielle »

Scénario: la fiche à revoir
  Étant donné un élève qui a une lacune en attente sur une fiche de révision
  Quand il ouvre son accueil
  Alors la rubrique s'intitule « Fiches à revoir »
  Et quand il ouvre cette fiche, le bandeau s'intitule « Fiche à revoir »

Scénario: l'équipe crée une fiche de cours
  Quand un membre de l'équipe crée la fiche de cours « Thalès »
  Alors il lit « Fiche de cours « Thalès » créée (brouillon). »

Scénario: l'équipe crée une fiche de révision
  Quand un membre de l'équipe crée la fiche de révision « Réciproque »
  Alors il lit « Fiche de révision « Réciproque » créée (brouillon). »

Scénario: le compteur du catalogue
  Étant donné trois fiches de cours publiées visibles par l'élève
  Quand il ouvre le catalogue
  Alors il lit « 3 fiches de cours »

Scénario: l'onglet de navigation garde son nom
  Quand un élève ouvre son accueil
  Alors l'entrée de navigation du catalogue s'intitule « Cours »

Scénario: les adresses ne changent pas
  Étant donné une fiche de révision publiée
  Quand l'élève ouvre /courses/<fiche de cours>/essentials/<fiche de révision>
  Alors la page répond 200 sans redirection

Scénario: les CGU nomment les nouveaux objets sans nouvelle version
  Quand un visiteur ouvre les conditions d'utilisation
  Alors il lit « fiches de cours, fiches de révision et exercices »
  Et la date de mise à jour reste « 2 octobre 2026 »
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | Aucun changement |
| Infrastructure | Aucun changement (ni migration, ni table, ni requête) |
| Delivery | Aucun changement de route ni de contrôleur |
| UI | Valeurs des fichiers de traduction français. Aucune clé n'est renommée. Tests qui comparent un texte exact. Garde de vocabulaire : « essentielle » interdit, exception « Révisions de la leçon » |
| Doc | Glossaire, UDR-0007 (renvoi), guide des contenus et prompt de rédaction |

## 6. Décisions rattachées

- **ADR : aucun.** Ni port, ni table, ni dépendance, ni contrat ne bouge. Les clés d'import JSON, les routes et les noms de classes restent identiques.
- **UDR-0084** — Vocabulaire « Fiche de cours » et « Fiche de révision ». Elle remplace, pour ces deux objets, la ligne `Essential` et l'amendement du 2026-09-30 de l'UDR-0007.

## 7. Mesures

| Métrique | Avant | Cible | Après |
|---|---|---|---|
| Occurrences de « essentielle(s) » dans les valeurs de traduction (hors commentaires) | 62 | 0 | |
| Valeurs de traduction qui nomment l'objet « cours » | ~85 | 0 (hors rubrique « Cours » et sens courant) | |
