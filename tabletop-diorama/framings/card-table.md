# Framing: card-table (not yet built)

A lower, closer view over a table where cards and tokens are the play, with a small miniature
behind them as the world the cards act on.

- **Camera:** perspective, field of view 32–36°, 30–35° below the horizon, 5–6 units from the
  cards' centre. The player's cards fill the bottom third; the miniature fills the middle third;
  the room fills the top.
- **Layout:** the hand of cards is in screen space or lies flat at the table's near edge (at
  most 7 cards in a fan of 6–8° per card); the miniature base is half the usual size (3–4 × 2–2.5)
  and sits 2–3 units behind the cards.
- **Light:** the key from above and slightly behind the miniature, so cards at the front get the
  fill and a soft rim; card faces must land within 10% of `paper` (raise the fill until they do).
- **Tilt-shift:** focus line at 0.35–0.4 of the screen's height, on the cards, with the miniature
  slightly soft; turn it down by half when the miniature holds information the player must read.
- **Cards:** card text is live text. Play a card by lifting it 0.3 unit and sliding it onto its
  target on the base, 0.3–0.4 s.

**Expected pitfalls:** cards in perspective at the front edge stretch and their text skews (keep
cards that carry text in screen space, or tilt them toward the camera); a miniature behind a full
hand gets covered (lower the hand while the player aims); with two focal areas the tilt-shift blurs
one of them, so pick which one leads in each phase.
