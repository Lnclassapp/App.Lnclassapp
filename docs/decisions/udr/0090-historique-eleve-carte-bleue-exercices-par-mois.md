# UDR-0090 : Historique de l'élève — carte bleue du total, exercices rangés par mois avec l'icône de la matière, note verte dès 14/20
<!-- index
titre: Historique de l'élève : total, exercices par mois, vert dès 14/20
statut: Accepté
adr-lie: —
problematique: Élève : « Mon historique » dans le cadre de l'accueil, ouvert depuis le menu de l'avatar ; carte bleue du nombre total d'exercices terminés ; exercices par mois avec l'icône de la matière ; note verte dès 14/20 (et non plus dès 10/20) ; deux colonnes dès 1 024 px ; aucun filtre, aucune ligne cliquable. Amende UDR-0057
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-10-15 |
| **Chantier** | [`docs/chantiers/historique-eleve`](../../chantiers/historique-eleve/memo.md) |
| **ADR lié** | — (contenu inchangé : ADR-0036, ADR-0040) |
| **Amende** | [UDR-0057](0057-ecrans-eleve-epures.md) (mise en page de l'historique) |
| **Dépend de** | [UDR-0084](0084-accueil-eleve-en-tete-au-logo-menu-de-l-avatar-et-exercice-du-jour.md) (en-tête, menu avec « Mon historique ») |
| **Remplacé par** | — |

---

## 1. Contexte

L'historique a été redessiné sur la toile https://claude.ai/artifact/V8DwH6oMQcHoxxtHji44B6. Le porteur a tranché le 2026-10-15 (memo du chantier) :

- une carte bleue avec le nombre d'exercices terminés ;
- les exercices rangés par mois, avec l'icône de leur matière ;
- la note verte dès 14/20 ;
- « Mon historique » dans le menu de l'avatar ;
- aucun filtre.

## 2. Décision

> **L'historique ouvre sur le total d'exercices terminés, puis les liste par mois, la note en vert à partir de 14/20.**

## 3. Règles d'implémentation

### 3.1 Carte bleue

- **Fond** : dégradé `brand-strong` → `brand`, texte blanc.
- **Contenu** : le nombre en grand (`font-display`), puis « exercices terminés », avec le pluriel par I18n.
- **Le nombre** vient de `Archive#completed_count`, qui n'est pas limité à 200.
- **À zéro** : « Aucun exercice terminé pour l'instant ».

### 3.2 « Mes exercices terminés »

- **Mois** : un titre par mois (`h3`, « Octobre 2026 »), du plus récent au plus ancien.
- **Ligne** :
  - l'illustration de la matière dans sa pastille teintée (`subject_illustration`, par le slug de la matière, comme les bulles de l'accueil, UDR-0069 §3.3) ; une pastille et non `ui_subject_bubble`, qui est un lien ;
  - le titre de l'exercice ;
  - la matière et la date ;
  - la note /20 à droite, dans une pastille : `bg-success-soft text-success` si `score_percent ≥ 70`, sinon `bg-mist text-ink`. Jamais de rouge.
- **Ancien seuil** : `PASS_THRESHOLD` (50 %) ne sert plus à la couleur de cette page.
- **Pas de lien** : aucune ligne n'en est un (UDR-0013).
- **« Voir plus »** : par pas de 10, comme aujourd'hui. Les titres de mois suivent les lignes révélées : une section de mois sans ligne visible est masquée en CSS (utilitaire `ui-reveal-group`, `:has`), sans changer le contrôleur `reveal`.

### 3.3 « Mes classes »

Une carte, avec une ligne par classe : nom, « niveau · établissement », année scolaire. Le contenu est inchangé.

### 3.4 Mise en page

| Largeur | Disposition |
|---|---|
| < 700 px | une colonne : carte bleue, exercices, classes |
| 700–1 023 px | une colonne de 720 px, centrée |
| ≥ 1 024 px | menu de gauche ; carte bleue en haut ; « Mes exercices terminés » à gauche (2/3), « Mes classes » à droite (1/3) |

### 3.5 États obligatoires

- Avec exercices sur plusieurs mois.
- Sans exercice.
- Sans classe.
- Plus de 200 exercices.
- Thème sombre.

### 3.6 Accessibilité

- **Structure** : chaque mois est une `section` titrée.
- **Note** : son texte est lu (« 14 sur 20 ») ; la couleur n'en est jamais le seul porteur.
- **Icône de la matière** : décorative, car la matière est écrite.

## 4. Conséquences

- **Seuil de vert** : 14/20 partout dans les écrans élève (Ma classe, résultat, historique).
- **Tests à relire** : `test/system/classroom/student_archive_test.rb` et `test/controllers/classroom/student_archives_controller_test.rb`.
