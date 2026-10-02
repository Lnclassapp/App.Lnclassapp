# Memo — Blog de Lnclass

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-10-02 |
| **Branche** | `feature/blog` |
| **Programme** | — *(hors plan de `refonte-application` ; rattaché à la V6, Communication, par défaut : grill 12)* |

---

## Le problème

Demande du porteur (2026-10-02) : « créer le blog de Lnclass ». Précisée au cadrage : un **blog public**, écrit par l'équipe Lnclass, lisible sans compte.

En dehors des écrans d'entrée, Lnclass n'a aujourd'hui que deux sortes de pages publiques : la page d'accueil, qui présente le produit, et les pages institutionnelles (mission, protection des données, conditions d'utilisation et de vente), en ligne depuis le 2026-10-02. Tout le reste est derrière la connexion. Quatre conséquences :

1. **Personne ne trouve Lnclass par ce qu'elle sait.** Un parent, un élève ou un enseignant qui cherche « réviser le BEPC » ou « méthode pour le BAC » ne tombe sur aucune page de Lnclass, et un lien partagé sur WhatsApp ou Facebook n'a rien d'autre à montrer que la page d'accueil.
2. **L'équipe démarche les mains vides.** Pendant la prospection, elle n'a rien à envoyer à un établissement, une DRENA ou un parent pour montrer le sérieux de Lnclass, sinon la page d'accueil.
3. **Les conseils n'ont pas d'endroit où vivre.** Méthodes de révision, préparation des examens, orientation : l'équipe produit des cours, pas des conseils, et rien ne les publie.
4. **Les nouveautés ne s'expliquent nulle part.** Un utilisateur découvre un changement en tombant dessus ; aucun texte ne dit ce qui a changé ni pourquoi.

Le porteur retient les quatre objectifs ensemble : **se faire connaître** (Google, partages WhatsApp et Facebook), **rassurer et convaincre** (démarchage), **aider à réussir** (conseils BEPC et BAC), **annoncer les nouveautés**.

## Pour qui

- **Le lecteur sans compte** : parent, élève, enseignant, chef d'établissement, agent de DRENA. Il arrive par Google, par un lien partagé sur WhatsApp ou Facebook, ou par la page d'accueil, souvent sur un téléphone d'entrée de gamme et avec peu de données mobiles. Le parent n'est jamais un rôle de l'application : c'est un visiteur.
- **L'utilisateur connecté** (élève, enseignant, direction) : lit les mêmes articles, en particulier les nouveautés. Seul l'élève a une entrée depuis son espace, par la carte « Besoin d'aide ? » (grill 3) ; enseignants et directions arrivent par les liens partagés.
- **L'équipe Lnclass (Team)** : les sous-rôles **Administration et Contenu** écrivent, publient, retirent les articles et lisent leur compteur de lectures (grilles 2 et 8) ; le **Terrain** ne gère pas le blog mais en partage les liens pendant le démarchage.

## Pourquoi maintenant

Deux raisons, données par le porteur le 2026-10-02 :

1. **La rentrée.** La production est ouverte depuis le 2026-09-27 ; octobre est le moment où élèves, parents et enseignants cherchent des outils et en parlent. Un contenu publié après la rentrée arrive après la décision.
2. **Le démarchage est en cours.** L'équipe prospecte des établissements maintenant et n'a, en dehors de la page d'accueil, aucun contenu à leur montrer ni à leur envoyer.

## Hors périmètre

Exclus par le porteur au cadrage :

- les **commentaires** des lecteurs ;
- l'**abonnement** aux nouveaux articles (e-mail, WhatsApp, notification) ;
- la **publication programmée** : un article publié l'est tout de suite.

Exclus par le grill :

- les **rubriques** et la **recherche** (grill 6) : une liste simple, du plus récent au plus ancien ; on les ajoute quand le volume le justifie ;
- le **ciblage** d'un article par niveau, classe ou établissement (grill 10) : c'est le rôle des annonces ;
- la **suppression définitive** d'un article (grill 7) : on archive ;
- l'**entrée vers le blog** depuis l'espace des enseignants, des directions et de l'équipe (grill 3) : seule la carte d'aide de l'élève y mène ;
- le **lien entre un article et une inscription** (grill 8) : on compte des lectures, pas des conversions ;
- toute **règle sur le sujet** d'un article (grill 4) : le logiciel ne filtre ni ne rappelle rien, le contenu relève de l'équipe qui publie.

Exclus par le choix d'un « blog public de Lnclass » :

- les articles écrits par un **enseignant**, une **direction** ou un **élève** : seule l'équipe Lnclass écrit ;
- les **annonces ciblées** dans l'application (V6, chantier `annonces`) : un article s'adresse à tout le monde, il ne remplace pas une annonce.

Exclus par les règles en vigueur :

- tout **service tiers** dans les pages : mesure d'audience, pixel, bouton de partage scripté, vidéo intégrée, police ou image hébergée ailleurs (ADR-0049) ;
- une autre **langue** que le français.

## Ce que le grill a révélé

> Grill mené avec le porteur, une question à la fois, à partir du 2026-10-02.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| 1. La rentrée presse : pourquoi construire le blog dans Lnclass plutôt qu'avec un outil existant (WordPress, Ghost), en ligne en un jour ? | Dans Lnclass, à l'adresse lnclass.com/blog : Google crédite le site principal ; même design, mêmes comptes d'équipe protégés par le second facteur, aucun tiers. | Le coût est accepté : l'éditeur, les images et le référencement sont à construire. Pour tenir la rentrée, la V1 est **minimale** : toute fonction qui n'est pas indispensable au premier article part en suite. Ni sous-domaine, ni outil externe. |
| 2. Un article est la vitrine publique de Lnclass : dans l'équipe, qui peut le publier ? | Les sous-rôles Administration et Contenu écrivent et publient ; le Terrain ne peut ni écrire ni publier. | Première règle qui distingue les sous-rôles de l'équipe : la matrice des droits de l'équipe (ADR-0038) gagne une ligne « blog », décidée ici pour le blog seul (la question générale des sous-rôles reste ouverte pour la V4). Un membre du Terrain reçoit un refus et ne voit pas l'entrée de gestion du blog ; il lit et partage les articles comme tout le monde. |
| 3. « Annoncer les nouveautés » vise ceux qui utilisent déjà Lnclass, mais une personne connectée n'atteint jamais la page d'accueil et aucune page publique n'est liée depuis l'espace connecté : comment trouve-t-elle un article ? | Par la carte « Besoin d'aide ? » seulement : une ligne « Blog » à son pied, à côté de Mission et Conditions. | Seul l'élève connecté (accueil élève, seul écran qui porte la carte) a une entrée vers le blog. Enseignants et directions n'en ont pas : pour eux, les nouveautés passent par les liens partagés, puis par les annonces (V6). Amendement de la carte d'aide (UDR-0061) ; la navigation de l'espace connecté et le menu du compte ne changent pas. |
| 4. Pour « rassurer et convaincre », un article peut raconter un établissement, un enseignant ou un élève (11 à 18 ans, mineur) : que peut-on publier sur des personnes réelles ? | Porteur (2026-10-02, après un premier « sans préférence ») : « Un article est un article. On s'en fout du sujet abordé, que ce soit par le nom d'un élève ou qui que ce soit. » | Aucune règle sur le sujet d'un article : ni rappel dans l'écran de rédaction, ni vérification. Ce qu'un article dit relève de la responsabilité éditoriale de l'équipe qui le publie, pas du logiciel. Le défaut proposé (aucun élève nommé) est **abandonné**. |
| 5. Les articles ont-ils des images ? L'éditeur les refuse partout aujourd'hui, et un lien partagé n'affiche d'aperçu illustré que si la page a une image. | Oui : une image de couverture (en tête de l'article, dans la liste, dans l'aperçu WhatsApp et Facebook) et des images au fil du texte. | Le choix le plus coûteux du grill. L'éditeur s'ouvre aux images **pour le blog seulement** : les cours et les fiches les refusent toujours. ADR obligatoire : images servies publiquement par Lnclass (pas d'hébergeur tiers), format et poids bornés et vérifiés par le serveur, réduites dans le navigateur avant l'envoi comme la photo de profil, puisque le serveur ne redimensionne pas. Le poids d'une page d'article devient une mesure du PRD (lecteurs sur données mobiles). Une image sans texte de remplacement est refusée à la publication. |
| 6. Catégories et recherche, gardées au cadrage : combien d'articles au lancement ? Avec cinq articles, quatre rubriques sont presque vides et une recherche ne trouve rien. | Liste simple : ni rubrique ni recherche en V1, les articles du plus récent au plus ancien. | Catégories et recherche passent en **hors périmètre** (le cadrage les gardait) : pas de table de rubriques, pas d'écran de gestion, pas de requête de recherche. On les ajoute quand le volume le justifie. La liste a besoin d'une pagination (composant existant) et d'un état vide. |
| 7. Un article déjà partagé sur WhatsApp doit être retiré : que voit celui qui ouvre le lien ensuite ? Si on corrige le titre, l'adresse change-t-elle ? | L'article est archivé, jamais détruit : son lien affiche « Cet article n'est plus disponible » et renvoie vers le blog. L'adresse est figée à la création. | Cycle brouillon → publié → archivé, avec remise en ligne possible, comme les cours (ADR-0035) ; aucune suppression. Un article archivé sort de la liste et du plan du site. Un brouillon, lui, reste introuvable pour un visiteur (on ne révèle pas qu'il existe). Adresse lisible, figée à la création, unique même si deux titres se ressemblent : amendement des identifiants (ADR-0029), qui réserve aujourd'hui ces adresses lisibles au catalogue. |
| 8. Comment saura-t-on que le blog marche, sachant que les outils d'audience tiers sont interdits (ADR-0049) ? | Un compteur de lectures par article, tenu par le serveur, sans cookie ni adresse IP. Pas de lien entre un article et une inscription. | Une lecture = l'ouverture d'un article publié par quelqu'un qui n'est pas de l'équipe ; ni brouillon, ni aperçu, ni article archivé. Le chiffre est brut et le dit : sans cookie, un lecteur qui revient compte deux fois, et un robot d'indexation qui se présente comme tel n'est pas compté. Visible par l'équipe seulement, dans la gestion du blog. Le compte se fait dans la même requête que la lecture, sans dépasser le budget de temps des pages (ADR-0067). Savoir si le blog amène des inscriptions reste une question ouverte. |
| 9. Qui signe un article ? Un membre de l'équipe peut quitter Lnclass ; son nom resterait sur des articles publics indexés par Google. | Au choix de l'auteur, article par article : « L'équipe Lnclass » ou son nom. | Un choix de signature dans l'éditeur, « L'équipe Lnclass » par défaut. L'auteur réel est toujours tracé, sans lui donner de droit (le contenu appartient à la plateforme). Quand le compte de l'auteur est désactivé ou anonymisé, ses articles signés de son nom passent **automatiquement** à « L'équipe Lnclass » : aucun nom d'ancien membre ne reste en ligne. |
| 10. Multi-appartenance : un élève rattaché à plusieurs classes ou établissements voit-il un blog différent ? Un article peut-il viser un niveau ou une classe ? | **Établi par l'exploration** : non. Un article est le même pour tout le monde, connecté ou non ; aucun ciblage par niveau, classe ou établissement. | Aucun doublon possible, aucune vue qui « fait foi » à choisir. Le ciblage entre dans le hors périmètre : il appartient aux annonces (V6), qui ont une audience. |
| 11. Permissions entre établissements : un enseignant ou une direction de deux établissements a-t-il des droits sur le blog ? | **Établi par l'exploration** : aucun. Écrire est réservé à l'équipe (Administration, Contenu) ; tous les autres lisent, comme un visiteur. | Rien ne dépend de l'établissement de l'acteur : la règle de lecture est la même pour un visiteur anonyme et pour tout compte connecté. Seule la gestion vérifie un rôle, celui de l'équipe. |
| 12. Quel contexte borné porte le blog, et à quelle vague de la refonte le rattacher ? | **Défaut** : le contexte de la communication, qui porte déjà les pages publiques (aide, mission, conditions) et portera les annonces ; rattachement à la V6 (Communication). | Une table d'articles amende la répartition des tables par contexte (ADR-0027). Article et annonce sont distingués dans le glossaire : l'article est public, sans audience ni rejet ; l'annonce est connectée et ciblée. Le blog ne touche aucun contrat d'une vague livrée, sauf la matrice de l'équipe (grill 2) et l'éditeur de texte riche, réservé aux cours (ADR-0051) : chacun par amendement. |

## Cas limites identifiés

- **Aucun article publié** : la page du blog affiche un état vide ; les liens vers le blog (pied de la page d'accueil, carte d'aide) n'apparaissent qu'à partir du premier article publié, pour ne jamais mener à une page vide.
- **Un seul article**, puis **des centaines** : la liste est paginée ; la page d'un article ne charge jamais la liste.
- **Brouillon ou article jamais publié** ouvert par son adresse par un visiteur ou un connecté hors équipe : « page introuvable », sans révéler qu'il existe. L'équipe (Administration, Contenu) le voit avec un bandeau « Brouillon ».
- **Article archivé** ouvert par un lien partagé : « Cet article n'est plus disponible », lien vers le blog ; il disparaît de la liste et du plan du site. Remis en ligne, il retrouve la même adresse.
- **Deux articles au titre identique ou proche** : deux adresses distinctes ; corriger un titre après publication ne change pas l'adresse.
- **Image refusée** (format inconnu, fichier trop lourd, fichier qui n'est pas une image, image sans texte de remplacement) : l'article n'est pas publié, le message dit laquelle et pourquoi ; le brouillon est conservé.
- **Image retirée du texte** d'un article : elle n'est plus servie avec l'article ; une image orpheline est purgée, jamais une image encore utilisée.
- **Auteur désactivé ou anonymisé** : ses articles restent en ligne ; ceux signés de son nom passent à « L'équipe Lnclass ».
- **Membre du Terrain**, enseignant, direction ou élève qui tente d'ouvrir la gestion du blog ou d'appeler une action d'écriture : refus, sans effet.
- **Lecture comptée** : ni l'équipe, ni un aperçu, ni un brouillon, ni un article archivé, ni un robot qui se déclare ; un lecteur qui revient compte deux fois (limite assumée, sans cookie).
- **Article très long** ou riche en images sur un téléphone d'entrée de gamme : images chargées à la demande, poids de la page mesuré (PRD §7).
- **Personne connectée** qui ouvre un article : il s'affiche comme pour un visiteur, sans l'espace connecté autour ; pas de redirection vers son accueil.

## Questions encore ouvertes

1. ~~Grill 4~~ : tranché par le porteur le 2026-10-02, aucune règle sur le sujet d'un article.
2. **Grill 12 (défaut)** : contexte de la communication et rattachement à la V6. À confirmer par le porteur.
3. Hôte canonique des adresses partagées et indexées : `lnclass.com` ou `www.lnclass.com` (les deux servent aujourd'hui l'application). Défaut proposé : `lnclass.com`.
4. Poids maximal d'une image et nombre d'images par article : chiffres à fixer dans l'ADR, au plus près de la photo de profil (1 Mo, 1024 px) et des annonces (2 Mo).
5. Mesurer plus tard les inscriptions venues d'un article (hors V1, grill 8).
6. Ton des articles (vouvoiement des pages publiques ou tutoiement de l'espace élève) : choix éditorial de l'auteur, hors logiciel ; les libellés de l'interface du blog vouvoient, comme les pages publiques (UDR-0063).
