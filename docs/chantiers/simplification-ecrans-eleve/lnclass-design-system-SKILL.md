---
name: "lnclass-design-system"
description: "Règles de design UI/UX de Lnclass (app éducative ivoirienne) : tokens, logo, en-tête, accueil, matière et leçon style Wave, grille des matières, annonces, listes, dates. Pour tout écran, maquette ou revue de design Lnclass."
---

# Design system Lnclass

Lnclass est une application éducative pour les élèves de Côte d'Ivoire (collège et lycée), avec des espaces prof et direction. Ces règles viennent d'un travail de revue UI/UX mené « comme le designer de Wave » et validé point par point avec le fondateur. Applique-les à tout nouvel écran ou composant, et sers-t'en comme grille de lecture quand on te demande une critique.

## 1. Principes (le « pourquoi »)

- **Un écran = une tâche principale.** Wave sert « payer / recevoir ». L'accueil élève sert « qu'est-ce que je fais maintenant ? ». Ne copie jamais une mise en page sans la logique qui la justifie.
- **Dire chaque chose une seule fois.** Ne répète pas la même information (exercice dans la carte + compteur sur la matière + ligne de liste) : ça crée de la pression sans informer.
- **Public :** élèves de 11 à 18 ans, souvent sur Android d'entrée de gamme, forfaits data chers, soleil fort. Les captures d'écran circulent sur WhatsApp (élèves, parents) : l'écran doit identifier la marque, la classe et l'établissement.
- **Ton :** tutoiement pour l'élève, phrases courtes, jamais culpabilisant.
- **Pas de barre de navigation en bas** sur l'accueil (comme Wave), ni de barre du haut sur les écrans intérieurs (flèche retour + titre).

## 2. Identité

- **Logo officiel :** un baobab noir (#262626) aux feuilles blanches, sur fond bleu #00a0ff. Utilise le fichier fourni par l'équipe (PNG détouré ou SVG), ne le redessine pas. Si tu ne l'as pas, demande-le.
- **Une seule couleur de marque :** le bleu Lnclass. Pas de seconde couleur d'identité (une carte prune sur bandeau bleu a été rejetée : deux identités se disputaient l'écran). Les surfaces fortes utilisent une version plus profonde du même bleu.
- **Place du logo (option validée) :** dans l'en-tête, sur une seule ligne, logo 40 px + « Lnclass » + sous-titre « 3ème B · Établissement ». Pas de ligne dédiée au logo, pas de filigrane.

## 3. Tokens

Définis toutes les couleurs comme variables, avec mode sombre (`prefers-color-scheme` + `[data-theme]`).

```css
:root {
  --bg: #ffffff;  --band: #00a0ff;  --band-fg: #ffffff;
  --ink: #1f2128; --label: #000000; --mute: #5f6470; --line: #e3eef7;
  --accent: #00a0ff; --accent-strong: #0070b3; --soft: #e5f5ff; --press: #f1f6fb;
  --ok: #18723f;  --ok-soft: #e7f5ed;                       /* réussi */
  --urgent: #8a4a00; --urgent-soft: #fff1dc; --urgent-dot: #f08c00; /* ambre = urgence */
  --hero-a: #0077c2; --hero-b: #004e80; --hero-ink: #004e80;  /* carte du haut */
  --due-bg: #fff1dc; --due-fg: #8a4a00;
  --msg-band: #f1f1f1; --msg-bg: #d6eeff; --msg-fg: #002a4f; --msg-sub: #2d5272;
  --play-ring: #ffffff; --play-icon: #002a4f; --play-done-ring: rgb(255 255 255 / .55); --play-done-icon: #6f8ba4;
  --brand-tile: #00a0ff;
  /* teintes des pastilles */
  --t-indigo: #dee5ff; --t-lilac: #f0dfff; --t-green: #e3ffdf; --t-yellow: #fff8d2;
  --t-lav: #f2f2ff;    --t-pink: #ffe1f3;  --t-mint: #d4fff6;  --t-red: #fff0f0;
  --font-display: "Bricolage Grotesque", ui-sans-serif, system-ui, sans-serif;
  --font-sans: "DM Sans", ui-sans-serif, system-ui, sans-serif;
  --font-mono: ui-monospace, SFMono-Regular, Menlo, monospace;
}
/* Sombre (valeurs clés) */
--bg #0f1218 · --band #0070b3 · --ink #eef1f5 · --mute #9aa3b0 · --line #222c39
--accent-strong #7fd0ff · --soft #132c42 · --ok #6fd69a · --urgent #ffbf73 · --urgent-dot #ffa33a
--hero-a #0b5a8f · --hero-b #063354 · --msg-bg #12324d · --msg-fg #d6eeff · --msg-sub #a9c9e4
--t-indigo #23284d · --t-lilac #33224a · --t-green #18361d · --t-yellow #3a3214
--t-lav #252845 · --t-pink #3d1a30 · --t-mint #113832 · --t-red #3d2023
```

## 4. Typographie

- Titres : Bricolage Grotesque 800. Texte : DM Sans 400/500/700. En production, envisage la police système pour le texte courant (moins de données à charger).
- Échelle : titre de la carte 21 px · titres de section 18 px · classe/logo 16–19 px · titre de message 15 px · titre de ligne 15 px (500) · texte 14 px · sous-texte 13 px · étiquettes en capitales 12 px (letter-spacing .08–.1em).
- **Minimum 12 px partout.** Les textes en gras restent modestes : le fondateur a demandé de réduire leur taille, ne remonte pas au-delà de cette échelle.
- Chiffres alignés : `font-variant-numeric: tabular-nums`.

## 5. Couleur sémantique (une couleur = un seul sens)

- **Ambre = urgence, et rien d'autre** : date limite dans moins de 24 h, ou dépassée. Jamais pour un statut « À faire », jamais pour une note.
- **Vert = réussi** : note ≥ 14/20, fiche « Lue », « Hors connexion » disponible.
- **Notes** : ≥ 14 vert · 10 à 13,5 neutre · < 10 neutre + bouton bleu doux « Refaire ». Jamais de rouge, jamais d'ambre : on met en avant la progression, pas la sanction.
- **Pas de compteurs rouges** sur la grille des matières.

## 6. Écrans de l'élève : style Wave (remplace l'ancien accueil à carte « Prochain exercice »)

Autorité : l'UDR « écrans minimalistes, style Wave » du dépôt (`docs/decisions/udr/`) et la skill de projet `ecrans-wave` (`.claude/skills/ecrans-wave/`). Ce chapitre en est le résumé de design.

**Huit règles.** 1. Un écran, une chose de valeur. 2. Jamais de section vide (masquée, titre compris). 3. Pas de raccourci en double. 4. Pas de barre de navigation sur les écrans intérieurs : flèche retour + grand titre. 5. Fond gris clair, groupes dans des cartes blanches arrondies, libellé de section gris. 6. Recherche dans un champ gris plein. 7. Listes plates, valeur alignée à droite (« 0/4 »). 8. Trois éléments au plus par section, puis « Voir plus (n) ».

**Accueil (ordre fixe)** : bandeau bleu (avatar à gauche, aide en icône seule à droite) ; le blanc à coins arrondis de 28 px commence à 159 px ; carte de la classe à cheval sur la jonction (nom, établissement, sigle en pastille ronde, petit logo Lnclass, bouton « Entrer en classe ») ; grille « Mes matières » 4 colonnes ; carrousel d'annonces (audio et croix) ; « À faire » et « Historique » seulement s'ils ne sont pas vides ; bannière d'invitation « Ton enseignant n'est pas sur Lnclass ? » masquable.

**Matière** : flèche retour, nom de la matière, champ de recherche gris, grille de 4 colonnes de tuiles pastel (pictogramme calculé du titre, libellé court, « Leçon n », coche si faite).

**Leçon** : flèche retour, titre, sous-titre « Leçon n · Matière · Niveau » ; groupes « Réviser », « Prépare interros », « Prépare devoirs » (« 0/4 » à droite), 3 lignes puis « Voir plus (n) ».

**Supprimés** : carte « Prochain exercice » (son code est conservé hors des écrans pour le guidage d'activation), « Exercice du jour », case « Inviter » en double, « Tous les exercices », cadre noir. Ce qu'on ajoute à un écran en retire un autre.

## 7. En-tête

- Hauteur du bandeau 187 px ; le blanc le recouvre de 28 px (début à 159 px) et la carte de classe remonte sur la jonction.
- Gauche : logo 40 px + « Lnclass » (19 px, 800) + sous-ligne 13 px « Classe · Établissement ».
- **Établissement : nom complet s'il tient sur la ligne, sinon le sigle.** Le sigle officiel vient de la base de données (jamais calculé automatiquement). Le nom complet reste dans l'`aria-label` et le `title`.
- Droite : aide (icône seule, 44 px, `aria-label`) + avatar 44 px (initiales, dégradé or). Pas de point « en ligne » sur son propre avatar.

## 8. Carte « Prochain exercice » (retirée des écrans)

Plus affichée sur aucun écran élève (UDR style Wave). Le code reste dans le dépôt pour le guidage d'activation après l'inscription ; ne la redessine pas sur l'accueil, la matière ou la leçon.

## 9. Grille des matières (4 × 2)

- **1er cycle :** les matières de la classe, 4 colonnes, sans case « Inviter » (la bannière d'invitation est la seule porte).
- **2nd cycle :** Philosophie remplace EDHC (même case, même teinte rose). Ce sont les seules matières proposées par Lnclass.
- Pastille ronde 60 px teintée + illustration 40 px ; libellé 14 px/500 en dessous. « Physique-Chimie » se coupe au trait d'union (`<wbr>`).
- Aucun compteur. **Point ambre 13 px (anneau de la couleur du fond) uniquement si un exercice de la matière est en retard.**

## 10. Annonces (carrousel)

Créées par les profs, la direction ou l'équipe Lnclass. Carte : fond `--msg-bg`, texte `--msg-fg`, rayon 10 px, largeur 100 % − 34 px, min-height 156 px, pagination par points sous le carrousel.

- **Émetteur (ligne 12 px, 700, au-dessus du titre) :**
  - Personnes : icône personne + « M./Mme Nom · fonction » — ex. « M. Kouassi · SVT », « Mme Kamaté · ACE ». Séparateur « · ».
  - Direction / officiel : même format + badge vérifié bleu ; **pas de croix** (non masquable).
  - Équipe : petit carré bleu avec le logo + « Lnclass ».
- **Ordre :** annonces scolaires d'abord, marketing (parrainage, abonnement) en dernier.
- **Masquer :** croix 44 px en haut à droite ; toast « Message masqué · Annuler » pendant 5 s.
- **Colonne de droite (≈ 92 px) :** illustration 64 px, puis **bouton audio dans son propre espace en dessous**, jamais par-dessus l'illustration.
- **Bouton audio :** cercle 32 px, **contour blanc 2 px, sans fond**, zone tactile 44 px. États : lecture (icône play) → pause pendant la lecture → déjà écouté (contour et icône atténués). Mémorise « déjà écouté » localement.
- **Lecture vocale :** lit « émetteur. titre. texte » en fr-FR, « M. » → « Monsieur », « Mme » → « Madame ». Si aucune voix française : afficher « Audio indisponible sur ce téléphone. » (jamais d'échec silencieux). En production, permettre aux profs d'enregistrer leur voix.

## 11. Listes (À faire, Historique)

- **Toute la ligne est cliquable** (lien étiré), avec état pressé (`--press`). Les lignes « À faire » ont une flèche à droite.
- Structure : pastille ronde 44 px teintée (illustration 28 px) · titre 15 px/500 tronqué · sous-texte 13 px « Matière · Type · durée » · colonne de droite.
- Droite « À faire » : date (§12) + mini-barre **avec le pourcentage** (« 60 % ») si commencé. Pas d'étiquette « À faire » (redondante).
- Droite « Historique » : note + heure, ou « Lue » + heure, ou note + bouton « Refaire » (< 10).
- Mention « Hors connexion » en vert avec icône de téléchargement pour les fiches disponibles sans réseau.
- Séparateurs 1 px `--line` entre lignes ; titres de jour en capitales 12 px `--mute`.

## 12. Formats

- **Dates à venir :** « Demain », puis le nom du jour seul jusqu'à 7 jours (« Samedi »), au-delà « Lun. 12 oct. ».
- **Dates passées :** « Aujourd'hui », « Hier », puis « Mardi 29 sept. » (avec la date, pour ne pas confondre avec un jour à venir).
- Heures « 09:14 » · notes « 16/20 » · pourcentages « 60 % » (espace insécable) · code de classe en 2 groupes de 3 (« K7M 4Q2 »).

## 13. Formes et icônes

- Pastilles de matière et de liste : **cercles**. Icône de la carte du haut : **carré arrondi 18 px**. Logo équipe : carré arrondi 5 px.
- Illustrations plates, 2–3 tons, `viewBox 0 0 48 48`, couleurs via classes `c-*` (voir annexe). Ne dessine aucun personnage ou logo existant.

| Élément | Teinte | Illustration |
|---|---|---|
| Maths | `--t-indigo` | calculatrice indigo |
| Physique-Chimie | `--t-lilac` | fiole violette |
| SVT | `--t-green` | feuille verte |
| Français | `--t-yellow` | livre ouvert orange |
| Histoire-Géo | `--t-lav` | globe pervenche |
| EDHC (1er cycle) | `--t-pink` | balance rose |
| Philosophie (2nd cycle) | `--t-pink` | tête de profil + « ? » |
| Paiement | `--t-mint` | portefeuille + pièce |
| Inviter | `--t-red` | deux élèves + « + » vert |

## 14. Accessibilité et performance

- Zones tactiles ≥ 44 px ; focus visible (contour 3 px `--accent`).
- `aria-live` pour les retours (copié, audio indisponible, historique chargé) ; texte `sr-only` pour les infos visuelles (message officiel, nombre d'éléments).
- `prefers-reduced-motion` respecté ; squelettes de chargement de la même taille que le contenu final.
- Mode sombre complet via les tokens ; jamais de couleur littérale qui ne marche que dans un thème.
- État hors connexion visible ; peu de polices web.

## 15. Checklist avant de livrer un écran

- [ ] Les 8 règles de la skill `ecrans-wave` sont-elles respectées (section vide, doublon, navbar intérieure, > 3 éléments sans « Voir plus (n) ») ?
- [ ] La tâche principale de l'écran est-elle visible sans défiler ?
- [ ] Une information n'apparaît-elle qu'une fois ?
- [ ] L'ambre n'est-il utilisé que pour l'urgence ? Aucune note en rouge ?
- [ ] Chaque bouton dit-il ce qui va se passer ?
- [ ] Textes ≥ 12 px, zones tactiles ≥ 44 px, mode sombre vérifié ?
- [ ] Dates au bon format (§12) et noms de matières cohérents partout ?
- [ ] Logo, classe et établissement visibles sur une capture de l'écran ?
- [ ] États vides, chargement, erreur et hors connexion prévus ?

## Annexe — illustrations SVG

```css
.c-white{fill:#fff}
.c-indigo{fill:#4f46e5}.c-indigo-d{fill:#1e1b9a}.c-indigo-l{fill:#c7c9ff}
.c-orange{fill:#ffb020}.c-orange-d{fill:#e2681c}.c-cream{fill:#ffe7a8}
.c-red{fill:#ef3b45}.c-red-l{fill:#ffb3b6}
.c-purple{fill:#a24be8}.c-purple-d{fill:#7b2bc4}.c-purple-l{fill:#ead7fd}
.c-green{fill:#4cc764}.c-green-d{fill:#24934a}
.c-pink{fill:#e63fa8}.c-pink-d{fill:#a3176f}
.c-peri{fill:#6f7cf2}.c-peri-d{fill:#3a45c4}
.c-teal{fill:#1fbf9a}.c-teal-d{fill:#0e8f72}
.c-gold{fill:#ffc83d}.c-gold-d{fill:#f39c12}
.s-pink-d{fill:none;stroke:#a3176f;stroke-width:1.6;stroke-linecap:round}
.s-peri-d{fill:none;stroke:#3a45c4;stroke-width:3;stroke-linecap:round}
.s-orange-d{fill:none;stroke:#e2681c;stroke-width:1.8;stroke-linecap:round}
.txt{font-family:var(--font-display);font-weight:800}
```

```html
<symbol id="i-maths" viewBox="0 0 48 48">
  <rect class="c-indigo" x="10" y="4" width="28" height="40" rx="6"/>
  <rect class="c-indigo-l" x="14" y="9" width="20" height="10" rx="2.5"/>
  <rect class="c-indigo-d" x="25" y="12" width="6" height="4" rx="1"/>
  <circle class="c-white" cx="17.5" cy="26" r="2.6"/><circle class="c-white" cx="24" cy="26" r="2.6"/><circle class="c-white" cx="30.5" cy="26" r="2.6"/>
  <circle class="c-white" cx="17.5" cy="33" r="2.6"/><circle class="c-white" cx="24" cy="33" r="2.6"/><circle class="c-gold" cx="30.5" cy="33" r="2.6"/>
  <rect class="c-indigo-d" x="14" y="38" width="20" height="2.5" rx="1.25"/>
</symbol>
<symbol id="i-pc" viewBox="0 0 48 48">
  <rect class="c-purple-d" x="18" y="4" width="12" height="5" rx="2.5"/>
  <path class="c-purple-l" d="M20.5 8.5V19L10.5 37.5A3.6 3.6 0 0 0 13.6 43h20.8a3.6 3.6 0 0 0 3.1-5.5L27.5 19V8.5z"/>
  <path class="c-purple" d="M15.1 29h17.8l4.6 8.5a3.6 3.6 0 0 1-3.1 5.5H13.6a3.6 3.6 0 0 1-3.1-5.5z"/>
  <circle class="c-white" cx="20" cy="36" r="2"/><circle class="c-white" cx="27" cy="33" r="1.4"/><circle class="c-purple" cx="24" cy="22" r="1.6"/>
</symbol>
<symbol id="i-svt" viewBox="0 0 48 48">
  <path class="c-green" d="M8 40C7 20 19 7 41 6c1 22-11 34-33 34z"/>
  <path class="c-green-d" d="M8 40C7 20 19 7 41 6z"/>
  <rect class="c-green-d" x="4" y="38.5" width="10" height="3" rx="1.5" transform="rotate(-45 9 40)"/>
</symbol>
<symbol id="i-fr" viewBox="0 0 48 48">
  <rect class="c-orange-d" x="4" y="14" width="40" height="27" rx="4"/>
  <path class="c-cream" d="M7 11c6-2 12-1.5 16.5 2v25c-4.5-3-10.5-3.5-16.5-2z"/>
  <path class="c-orange" d="M41 11c-6-2-12-1.5-16.5 2v25c4.5-3 10.5-3.5 16.5-2z"/>
  <path class="s-orange-d" d="M11 18.5c3-.5 6-.2 8.5.8M11 24c3-.5 6-.2 8.5.8M11 29.5c3-.5 6-.2 8.5.8"/>
  <path class="c-red" d="M31 10.5V22l3-2.2 3 2.2V10z"/>
</symbol>
<symbol id="i-hg" viewBox="0 0 48 48">
  <circle class="c-peri" cx="24" cy="20" r="15"/>
  <path class="c-peri-d" d="M17 8.5c4-1.2 8 .5 7.5 4.5-.5 3.4-5 3-6.2 6.4-.9 2.6-5.1 1.8-5.7-1.7-.6-3.9 1-8 4.4-9.2zM28.5 21c4-.4 6.8 2.3 5.7 5.9-.9 2.7-4.6 4.1-6 1.7-1.5-2.5-3.4-7.3.3-7.6z"/>
  <path class="s-peri-d" d="M6 20a18 18 0 0 0 31 12.5"/>
  <rect class="c-peri-d" x="22.5" y="37" width="3" height="5"/>
  <rect class="c-peri-d" x="15" y="41" width="18" height="4.5" rx="2.25"/>
</symbol>
<symbol id="i-edhc" viewBox="0 0 48 48">
  <rect class="c-pink-d" x="22.5" y="8" width="3" height="31" rx="1.5"/>
  <rect class="c-pink-d" x="8" y="11" width="32" height="3" rx="1.5"/>
  <circle class="c-pink" cx="24" cy="8" r="3.5"/>
  <path class="s-pink-d" d="M12 13.5 6.5 26M12 13.5 17.5 26M36 13.5 30.5 26M36 13.5 41.5 26"/>
  <path class="c-pink" d="M4.5 26h15a7.5 7.5 0 0 1-15 0zM28.5 26h15a7.5 7.5 0 0 1-15 0z"/>
  <rect class="c-pink" x="14" y="38" width="20" height="6" rx="3"/>
</symbol>
<symbol id="i-philo" viewBox="0 0 48 48">
  <path class="c-pink" d="M15 45v-7.5C9.6 34.6 6.5 29.4 6.5 23.2 6.5 13.4 14.4 6 24 6c8.7 0 15.2 6.1 15.2 14.1l3.4 6.6c.5 1-.2 2.1-1.3 2.1h-2.3v4.4c0 2.3-1.8 4.1-4.1 4.1h-4.2V45z"/>
  <circle class="c-white" cx="22.5" cy="20.5" r="9"/>
  <text class="txt c-pink-d" x="22.5" y="25.6" text-anchor="middle" font-size="14">?</text>
  <circle class="c-gold" cx="41" cy="9.5" r="2.6"/><circle class="c-gold" cx="45" cy="4" r="1.6"/>
</symbol>
<symbol id="i-pay" viewBox="0 0 48 48">
  <circle class="c-gold-d" cx="30" cy="11" r="7"/><circle class="c-gold" cx="30" cy="11" r="5"/>
  <rect class="c-teal" x="4" y="14" width="38" height="27" rx="6"/>
  <rect class="c-teal-d" x="28" y="22" width="16" height="11" rx="4"/>
  <circle class="c-white" cx="35" cy="27.5" r="2.4"/>
</symbol>
<symbol id="i-invite" viewBox="0 0 48 48">
  <circle class="c-red-l" cx="30" cy="14" r="7"/><path class="c-red-l" d="M18 37a12 12 0 0 1 24 0z"/>
  <circle class="c-red" cx="18" cy="18" r="7.5"/><path class="c-red" d="M5 42a13 13 0 0 1 26 0z"/>
  <circle class="c-green" cx="38" cy="36" r="8"/>
  <path d="M38 32v8M34 36h8" stroke="#fff" stroke-width="2.6" stroke-linecap="round"/>
</symbol>
```