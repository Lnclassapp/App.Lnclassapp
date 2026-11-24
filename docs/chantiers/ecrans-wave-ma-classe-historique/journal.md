# Journal — ecrans-wave-ma-classe-historique

Demande du porteur (2026-11-24, captures au téléphone) : « Ma classe » et « Mon historique » ne ressemblent pas à une application mobile (en-tête du site, fil « < Accueil », cases « cahier » en police serif, grandes cartes « Voir ma copie »). Les passer au format des écrans intérieurs déjà décidé (UDR-0173, écrans minimalistes style Wave), simple et tourné vers l'action.

## Ce qui change

- **Les deux écrans deviennent des écrans intérieurs** (`content_for :inner`) : ni en-tête, ni menu, à toute largeur ; flèche retour vers l'accueil et grand titre (`shared/screens/_inner_header`), fond gris, une colonne de 720 px au plus.
- **Ma classe** : la classe passe en sous-titre (nom · niveau · établissement · année) ; la carte bleue disparaît. D'abord ce qui est à faire : « Exercices assignés » (une ligne par envoi : notion, « Prépare interros n°1 · À rendre le … » ; plus de compte des réussis, demande du porteur du 2026-11-24), « Notions à revoir », « Fiches de cours » (lignes au lieu du carrousel), « Exercices traités » (lignes, médaille à droite, toute la ligne mène à la copie). Chaque groupe : carte blanche, 3 lignes puis « Voir plus (n) ». Une section vide est masquée ; sans rien du tout, une seule phrase.
- **Mon historique** : carte bleue du total gardée, puis « Mes exercices terminés » et « Mes classes » en cartes blanches, l'une sous l'autre ; une liste vide est masquée.
- `shared/screens/_row` prend un `trailing:` (HTML à droite, la médaille).
- **La note revient, la médaille devient une récompense** (demande du porteur, 2026-11-24) : sur les exercices traités de « Ma classe », « Mes exercices terminés » et l'historique de l'accueil, la note sur 20 en gras, et sous elle la médaille en pastille teintée à sa couleur, trophée sur un rond blanc (`grade_and_medal`, `medal_reward_tag`). Une copie vide : « Pas encore » seul, jamais « 0/20 ». Les comptes « réussis » et « répondu/total » restent retirés.

## À trancher

- **Ma classe sans la carte bleue de la classe** (UDR-0086 §3.2, UDR-0171) : la classe tient dans le sous-titre, pour mettre les exercices à faire en haut. Réversible : remettre `_classroom_card` (supprimée).
- **Les envois de l'enseignant en lignes plates, plus en cases « cahier »** (UDR feuilles-en-cases-lues-avant-de-commencer §3, qui citait « Ma classe ») : les cases restent sur la leçon. Réversible.
- **« Ma classe » n'a plus le menu de gauche sur ordinateur** (écran intérieur à toute largeur, comme la matière) : on y entre par la carte de l'accueil ou le menu, on en sort par la flèche.
- **La note sur 20 revient à l'écran de l'élève** (UDR-0167 l'interdisait : « la médaille remplace la note ») : décision du porteur, appliquée aux trois listes de l'élève seulement ; les écrans enseignant et direction ne changent pas. À formaliser par une UDR qui amende l'UDR-0167 à la fusion. Réversible : `grade_and_medal` → `medal_reward_tag`.
