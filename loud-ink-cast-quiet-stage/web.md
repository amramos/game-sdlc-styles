# Web snippets (prototype)

Plain HTML and CSS; no 3D. Colours are CSS custom properties named after the palette roles.

```css
:root {
  --ink: <ink>; --paper: <paper>; --accent: <accent>; --shadow: <shadow>;
}
.panel {
  background: var(--paper);
  border: 4px solid var(--ink);
  padding: 10px 12px;
  color: var(--ink);
}
.action-primary {
  background: var(--ink);
  color: var(--paper);
  border: 4px solid var(--ink);
  box-shadow: 6px 6px 0 var(--accent);   /* hard offset, no blur */
}
.tilt-l { transform: rotate(-2deg); }
.tilt-r { transform: rotate(2.5deg); }
.halftone {                               /* engine-drawn shadow only, never the stage */
  background-image: radial-gradient(var(--shadow) 1.6px, transparent 1.8px);
  background-size: 6px 6px;
}
.card { transition: transform 80ms cubic-bezier(.34, 1.56, .64, 1); }
.card:focus-visible, .card:hover { transform: translateY(-12px) scale(1.06); }
@media (prefers-reduced-motion: reduce) {
  .card, .card:hover { transition: none; transform: none; }
}
```

Stage layers are stacked `<img>` elements in one positioned box; the camera is a CSS transform on
that box (`scale(1.4)` and a translate toward the subject, 0.4 s ease). The interface lives outside
the box, so zooming never crops it.
