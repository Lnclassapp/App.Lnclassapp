# Journal — Retouches sans chantier parent

## Retouches

> Format : `- AAAA-MM-JJ · #<PR> · <ce qui change, en une phrase>`

- …
- 2026-11-08 · #PR · Pages d'erreur et message d'exercices au bon registre (tu / vous), `turbo_submits_with` sur 3 envois, cibles tactiles ≥ 44 px (liens de résultat, « Retirer »)
- 2026-11-13 · #578 · Accueil élève : la grille « Mes matières » affiche Maths, PC, HG (nom entier lu aux lecteurs d'écran) ; Français et SVT inchangés
- 2026-11-13 · #586 · Macaron de l'accueil : « Je prépare mes interros et devoirs à la maison. », « interros et devoirs » en accent (graisse 800, `ink`)
- 2026-11-13 · #587 · Grille « Mes matières » : Philosophie s'affiche « Philo » (EPS non proposée par Lnclass, EDHC et Anglais déjà courts : rien à faire)
- 2026-11-14 · #614 · Inscription élève, étape 1 : la cascade DRENA s'ouvre d'abord, lien « J'ai le code de ma classe › » sous la DRENA (plus de case à cocher), « ‹ Je n'ai pas de code » rouvre la cascade ; UDR-0135 §2.2 et §3.2 mis à jour
- 2026-11-21 · #666 · Ruby 3.4.9 → 3.4.13 (CVE signalée par Brakeman) et brakeman 8.1.0 → 8.1.1
- 2026-11-24 · #690 · Accueil élève, annonces et listes Wave : carrousel à 8 px du bord (la carte suivante dépasse), image de la bannière à 96 px ; libellé gris d'un groupe (shared/screens/_group) aligné sur le texte des lignes (16 px), sur l'accueil, la matière et la leçon
- 2026-11-24 · #689 · Carte de classe de l'accueil élève : « Scanner » et l'appareil photo dans le cadre du QR, en bas (indication, pas un bouton ; disposition du QR inchangée, choix du porteur), marges x de 48 px (mx-12) comme la carte au QR de Wave
- 2026-11-24 · #688 · Accueil élève, marges Wave : grille « Mes matières » et « Inviter » sur toute la largeur (px-1), disques 56 px, libellés 14 px à 10 px du disque, 16 px sous la carte de classe, « À faire » et l'historique à 20 px du bord ; dès lg, « Invite tes camarades » ne colle plus au libellé des matières
- 2026-11-24 · fix/retouche-accueil-eleve-matieres-annonces · Accueil élève : titre « Mes matières » lu aux seuls lecteurs d'écran ; libellés de la grille noirs en 600 ; bannière d'annonce aux coins rounded-ln, plus haute (min-h-40, titre 18 px), sans signature ; plus de points sous le carrousel (écrans des enseignants et de la direction inchangés)
- 2026-11-26 · #PR · Compte enseignant : « Retirer de la classe » en bouton secondaire d'erreur et « Arrivé·e le » insécable (fiche élève) ; noms du suivi d'un devoir et « Retour à la classe » de l'affiche à 44 px tactiles ; Cours : niveau et série dans la ligne « Leçon n » (deux séries d'un même niveau aux leçons de même titre, 1ère A1 et A2, ne se distinguaient pas ; le seed est sain, deux cours distincts)
