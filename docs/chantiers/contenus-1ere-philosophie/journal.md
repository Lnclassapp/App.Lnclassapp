# Journal — Les 8 leçons de Philosophie de 1ère

> Rempli **pendant** le chantier.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | Séries A1, A2, C, D ; pas de série « A » | Le référentiel de 1ère n'a pas de série A ; la progression est identique en A, C et D | Non |
| 2026-11-02 | Intitulés de la progression gardés à l'identique, y compris « Le Moyen-Age et la renaissance » | L'import détecte les doublons à ce nom | Non |
| 2026-11-02 | Règles Philosophie de `prompt-redaction.md` reprises sans changement | Déjà fusionnées par la vague T6 | Non |
| 2026-11-02 | Tle non touchée : « accroche » (1ère) et « amorce » (Tle) cohabitent, la 1ère écrit « accroche (on dit aussi amorce) » | Hors périmètre de la vague | Non |

## Ce qui a dérapé

- **Aucune leçon n'était livrable au premier jet** : la relecture Opus a trouvé 1 défaut majeur (Épictète donné comme auteur du « Manuel », écrit par son disciple Arrien) et 4 à 16 défauts par leçon : classement des désirs d'Épicure incomplet, dates de lettre incertaines, thèse de Thomas d'Aquin trop simplifiée (accord et hiérarchie), numérotation de « Des cannibales », corrections désignant une proposition par son rang (13 cas dans les leçons 1 à 4), `fill_blank` refusant une variante légitime, barèmes incohérents avec leurs critères, questions non autonomes.
- **`script/contenus/valider.rb` exige Ruby 3.4** (`it`) : les rédacteurs l'ont lancé sur une copie patchée ; le contrôle final des 32 fichiers est fait sous Ruby 3.4.9 installé par `rbenv`.
- Le scratchpad étant partagé entre rédacteurs, des générateurs se sont écrasés ; les corrections ont été appliquées sur les JSON.

## À faire valider par un enseignant de philosophie

| Leçon | Point à valider |
|---|---|
| L1 à L4 (méthode) | Aucune attribution ; textes supports écrits pour Lnclass. Vocabulaire : problème = la difficulté, problématique = la question, accroche (dite aussi amorce), idée directrice, « oui, à condition que… » (jamais « cela dépend ») ; introduction en 4 temps ; Descartes, « Discours de la méthode », 1637 et Rousseau, « Du contrat social », 1762 (citations mot pour mot, leçon 2) |
| L5 Période antique | Thalès (VIe s. av. J.-C.), eau comme principe d'après Aristote, « Métaphysique » ; Socrate (vers 470-399), « Apologie de Socrate » de Platon (défense, non procès) ; « Connais-toi toi-même » (Delphes) ; Platon (vers 428-348), caverne, « La République » VII, soleil = Idée du Bien ; Aristote (384-322), « La Politique », « Éthique à Nicomaque » ; Épicure (341-270), « Lettre à Ménécée » datée « vers 300 av. J.-C. », trois sortes de désirs ; Zénon de Cition (stoïcisme, vers 300) ; Épictète (Ier-IIe s. apr. J.-C.), « Manuel » rédigé par son disciple Arrien |
| L6 Moyen Âge et Renaissance | Anselme, « Proslogion » (XIe s.) ; Thomas d'Aquin (1225-1274), « Somme théologique » : accord et hiérarchie foi/raison ; Avicenne (980-1037, d'origine persane), Averroès (1126-1198) ; Ibn Khaldoun (1332-1406), « Muqaddima » (1377) ; Pic de la Mirandole (1463-1494), discours rédigé en 1486 ; Érasme, « Éloge de la folie » (1511) ; Montaigne (1533-1592), « Essais » (1580), « Que sais-je ? » (II, 12), « Des cannibales » (I, 31, numérotation moderne) ; repères 476 et imprimerie vers 1450 (bascule Moyen Âge/Renaissance vers 1450) |
| L7 Période moderne | Descartes, « Discours de la méthode » 1637 (cogito, 4e partie), « Méditations métaphysiques » 1641 ; Hobbes, « Léviathan », 1651 ; « Encyclopédie », 1er volume 1751 ; Voltaire, « Traité sur la tolérance », 1763 ; Rousseau, « Du contrat social », 1762, chap. 1 du livre I, volonté générale ; Kant, « Critique de la raison pure », 1781, « Qu'est-ce que les Lumières ? », 1784 (minorité, courage) ; empirisme présenté sans nom d'auteur |
| L8 Période contemporaine | Repère 1789 (conventionnel ; cas limites Kant, Hegel) ; Comte (1798-1857), « Cours de philosophie positive » 1830-1842, loi des trois états ; Marx (1818-1883), « Manifeste du parti communiste » 1848 avec Engels, « Le Capital » livre I 1867 ; Nietzsche, « Le Gai Savoir », 1882, « Dieu est mort » ; Sartre (1905-1980), « L'existentialisme est un humanisme », 1946, « l'existence précède l'essence » ; négritude (années 1930, Senghor, Césaire, Damas) ; Tempels, « La philosophie bantoue », 1945 (missionnaire belge) ; Hountondji, 1976 ; équilibre des positions sur la philosophie africaine |
| Toutes | Barèmes des questions rédigées ; niveau de détail de 1ère |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Relecture par un enseignant de philosophie (table ci-dessus) | Aucun enseignant dans le chantier ; les leçons restent en brouillon | Programme `contenus-v3-tous-niveaux` |
| « accroche » (1ère) et « amorce » (Tle, La dissertation philosophique) | Hors périmètre ; Tle déjà fusionnée | À harmoniser par l'enseignant |
| `valider.rb` ne détecte pas une correction qui désigne une proposition par son rang | Aucun code dans cette vague | Dette déjà ouverte par `contenus-tle-philosophie` |
| Challenger empirique (import en brouillon, captures 390 px et ordinateur) | Pas de base ni de navigateur sur la session de rédaction ; aucune vue modifiée | Avant publication, par l'équipe |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-02 |
| **PR** | #442 |
