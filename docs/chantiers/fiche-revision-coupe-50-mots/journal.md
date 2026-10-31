# Journal — La fiche de révision coupée à 50 mots

## 2026-10-31 — Lot A

- Tests domaine réécrits à 50 mots : 7 rouges, puis verts une fois le seuil changé.
- Tests d'intégration et système : la notion longue passe de 160 à 60 mots (avec 150, elle ne serait plus coupée : le test prouve le nouveau seuil).
- Test de la query : deux notions types (96 mots) sont désormais coupées après la première ; le test le dit au lieu d'attendre aucune coupe.
- Fusion de `Develop` (« Je m'entraîne ») : UDR renumérotée 0148 (0147 prise) ; le test « l'entraînement compte zéro mot » garde une seule notion (48 mots), car deux notions dépassent désormais 50.
