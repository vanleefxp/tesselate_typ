#import "@preview/elembic:1.1.1" as e
#import "@preview/oxifmt:1.0.0": strfmt
#import "src/lib.typ" as tesselate: masonry, scalable, matrix
#import tesselate.transform: upside-down

#let cat-images = range(1, 4).map(i => image(strfmt("assets/image/cat{:}.jpg", i)))
#let dog-images = range(1, 4).map(i => image(strfmt("assets/image/dog{:}.jpg", i)))

#let masonry-example = masonry(
  (
    scalable(
      cat-images.at(0),
      // [This is an image of a cat.],
      aspect-ratio: 1,
      // fit: "stretch",
    ),
    scalable(
      upside-down(cat-images.at(1)),
      aspect-ratio: 0.75,
    ),
  ),
  cat-images.at(2),
  dog-images,
  // secondary-gutter: (5pt, 10pt),
  // primary-gutter: ((10pt,), (), (20pt, 3em)),
  gutter: 0.5em,
  flow: (ttb, ltr),
)

#let matrix-example = matrix(
  ..dog-images,
  ..cat-images,
  ..dog-images,
  columns: (3fr, 4fr, 5fr),
  rows: (3fr, 4fr, 5fr),
  gutter: 0.75em,
  flow: (ltr, ttb),
)

#page(
  figure(
    masonry-example,
    caption: [Sample images of cats and dogs, arranged in masonry layout.],
  ),
  height: auto,
)

#page(
  figure(
    matrix-example,
    caption: [Sample images of cats and dogs, arranged in matrix layout.],
  ),
  height: auto,
)
