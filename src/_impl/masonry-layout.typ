// #import "@preview/grayness:0.3.0"
#import "@preview/elembic:1.1.1"as e
#import "utils.typ": arbitrary-pos-arg-parser, dir-is-inv, div, mod, cdiv, reflow
#import "typing.typ": *

/// Calculate column widths for masonry image layout.
///
/// - width (length): width of the masonry layout block
/// - aspect-ratio-sums (array): an array, each element the sum of aspect ratios of images in a column
/// - column-gutter-sum (length): sum of column gaps
/// - row-gutter-sums (array): an array, each element the sum of row gaps in a column
/// -> array
#let calc-col-widths(
  width,
  aspect-ratio-sums,
  column-gutter-sum,
  row-gutter-sums
) = {
  let k_i-reci-sum = aspect-ratio-sums
    .map(k_i => 1 / k_i)
    .sum(default: 0)
  let d_i-over-k_i-sum = row-gutter-sums
    .zip(aspect-ratio-sums)
    .map(((d_i, k_i)) => d_i / k_i)
    .sum(default: 0)
  let height = (width - column-gutter-sum + d_i-over-k_i-sum) / k_i-reci-sum
  row-gutter-sums
    .zip(aspect-ratio-sums)
    .map(((d_i, k_i)) => (height - d_i) / k_i)
}

// override `calc-col-widths` with Rust impl
#import "masonry-layout-helper_wasm.typ": calc-col-widths

#let rescale(
  body,
  width: auto,
  height: auto,
  fit: "cover",
  alignment: center + horizon,
) = {
  if height == auto {
    if width == auto {
      body
    } else {
      let (width: orig-width) = measure(body)
      let scale-ratio = width / orig-width
      scale(width / orig-width * 100%, body, reflow: true)
    }
  } else if width == auto {
    let (height: orig-height) = measure(body)
    scale(height / orig-height * 100%, body, reflow: true)
  } else {
    let (width: orig-width, height: orig-height) = measure(body)
    if fit == "stretch" {
      scale(
        body,
        x: width / orig-width * 100%,
        y: height / orig-height * 100%,
        reflow: true,
      )
    } else {
      let width-scale-ratio = width / orig-width * 100%
      let h1 = width-scale-ratio * orig-height
      let scale-ratio = if h1 < height {
        height / orig-height * 100%
      } else {
        width-scale-ratio
      }
      box(
        align(
          scale(
            box(body, width: orig-width, height: orig-height),
            scale-ratio,
            reflow: true
          ),
          alignment,
        ),
        clip: true,
      )
    }
  }
}

#let resolve-gutter1(
  gutter: auto,
  n: 1,
  default-gutter: 0pt,
  inv: false
) = {
  let gutter-sum = 0pt
  let gutter = gutter
  if gutter == auto {
    gutter-sum = default-gutter.to-absolute() * (n - 1)
    gutter = default-gutter
  } else if type(gutter) == length {
    gutter-sum = gutter * (n - 1)
  } else if type(gutter) == array {
    gutter = range(n - 1).map(i => gutter.at(mod(i, gutter.len())).to-absolute())
    gutter-sum = gutter.sum(default: 0pt)
    if inv { gutter = gutter.rev() }
  } else {
    assert.eq(type(gutter), function)
    gutter = range(n - 1).map(gutter)
    gutter-sum = gutter.sum(default: 0pt)
    if inv { gutter = gutter.rev() }
  }
  (gutter: gutter, sum: gutter-sum)
}

#let resolve-gutter2(
  gutter: auto,
  n-primary: none,
  n: 1,
  default-gutter: 0pt,
  dir1-inv: false,
  dir2-inv: false
) = {
  let n = n
  let gutter = gutter
  if type(gutter) == array {
    assert.eq(n, gutter.len())
  }

  // resolve row gutters and calculate the sum of row gutters in each column
  if type(gutter) == function {
    gutter = n-primary
      .enumerate()
      .map(((j, m)) => range(m - 1).map(i => gutter(j, i)))
  } else if gutter == auto {
    gutter = (gutter,) * n
  } else if type(gutter) == length {
    gutter = (gutter,) * n
  }
  // `row-gutter` is now of type `array`
  let temp = gutter
    .zip(n-primary)
    .map(
      ((g, n)) => resolve-gutter1(
        gutter: g,
        n: n,
        default-gutter: default-gutter,
        inv: dir1-inv,
      )
    )

  if dir2-inv { temp = temp.rev() }
  gutter = temp.map(item => item.gutter)
  let gutter-sums = temp.map(item => item.sum)
  (gutter: gutter, sum: gutter-sums)
}

#let correct-item-dir(items, dir1-inv: false, dir2-inv: false) = {
  if dir1-inv {
    if dir2-inv {
      items.rev().map(item => item.rev())
    } else {
      items.map(item => item.rev())
    }
  } else if dir2-inv {
    items.rev()
  } else {
    items
  }
}

#let masonry-item = e.element.declare(
  "masonry-item",
  prefix: "booklet-theme.layout.masonry",
  fields: (
    e.field(
      "body",
      content,
      named: false,
      required: true,
    ),
    e.field(
      "aspect-ratio",
      e.types.smart(float),
      default: auto,
      named: true,
    ),
    e.field(
      "fit",
      e.types.union(..("stretch", "cover").map(e.types.literal)),
      default: "cover",
      named: true,
    ),
    e.field(
      "alignment",
      alignment,
      default: center + horizon,
      named: true,
    ),
  ),
  display: el => el.body,
)

#let resolve-masonry-item(item) = {
  if e.eid(item) == e.eid(masonry-item) { item }
    else { masonry-item(item) }
}

/// Calculate the aspect ratio of a `content` item.
///
/// - item (content | bytes | str): a `content`, or path to an image, or source bytes of an image
/// -> float
#let aspect-ratio(item, reci: false) = {
  assert.eq(e.eid(item), e.eid(masonry-item))
  let fields = e.fields(item)
  if "aspect-ratio" in fields {
    let aspect-ratio = fields.aspect-ratio
    if (reci) { 1 / aspect-ratio } else { aspect-ratio }
  } else {
    let (width, height) = measure(item)
    if (reci) { width / height } else { height / width }
  }
}

#let masonry = e.element.declare(
  "masonry",
  prefix: "booklet-theme.layout.masonry",
  fields: (
    e.field(
      "children",
      e.types.array(e.types.union(content, e.types.array(content))),
      default: (),
      named: false,
    ),
    e.field(
      "gutter",
      length,
      default: 0pt,
      named: true,
    ),
    e.field(
      "secondary-gutter",
      secondary-gutter,
      named: true,
    ),
    e.field(
      "primary-gutter",
      primary-gutter,
      named: true,
    ),
    e.field(
      "column-gutter",
      e.types.option(gutter-like),
      named: true,
    ),
    e.field(
      "row-gutter",
      e.types.option(gutter-like),
      named: true,
    ),
    e.field(
      "flow",
      e.types.array(direction),
      named: true,
      default: (ttb, ltr),
      folds: false,
    )
  ),
  allow-unknown-fields: true,
  display: el => {
    let (
      children,
      gutter,
      column-gutter,
      row-gutter,
      primary-gutter,
      secondary-gutter,
      flow: (dir1, dir2)
    ) = e.fields(el)

    // primary and secondary directions must have different axes
    assert.ne(dir1.axis(), dir2.axis())
    let dir1-inv = dir-is-inv(dir1)
    let dir2-inv = dir-is-inv(dir2)

    // convert single items to arrays
    // turn all items into `masonry-item` type
    let children = children.map(
      item => {
        if type(item) == array { item.map(resolve-masonry-item) }
        else { (resolve-masonry-item(item),) }
      }
    )

    // `n-rows` is calculated before direction correction
    let n-rows = children.map(array.len)
    let n-cols = children.len()

    // correct directions of items
    children = correct-item-dir(
      children,
      dir1-inv: dir1-inv,
      dir2-inv: dir2-inv,
    )

    if dir1.axis() == "horizontal" {
      // horizontal then vertical

      if row-gutter == none {
        row-gutter = secondary-gutter
      }
      if column-gutter == none {
        column-gutter = primary-gutter
      }

      let n-rows = children.len()
      let n-cols = children.map(array.len)

      let (gutter: row-gutter) = resolve-gutter1(
        gutter: row-gutter,
        n: n-rows,
        default-gutter: gutter,
        inv: dir2-inv,
      )

      let (
        gutter: column-gutter,
        sum: column-gutter-sums
      ) = resolve-gutter2(
        gutter: column-gutter,
        n: n-rows,
        n-primary: n-cols,
        default-gutter: gutter,
        dir1-inv: dir1-inv,
        dir2-inv: dir2-inv,
      )

      if (dir2-inv) { n-cols = n-cols.rev() }
      let aspect-ratio-recis = children
        .map(item => item.map(aspect-ratio.with(reci: true)))
      let aspect-ratio-reci-sums = aspect-ratio-recis
        .map(array.sum.with(default: 0))

      layout(((width,)) => {
        let heights = aspect-ratio-reci-sums
          .zip(column-gutter-sums)
          .map(
            ((aspect-ratio-reci-sum, column-gutter-sum)) =>
            (width - column-gutter-sum) / aspect-ratio-reci-sum
          )
        let rows = children
          .zip(column-gutter, aspect-ratio-recis)
          .map(
            ((items, column-gutter, aspect-ratio-recis)) => {
              let items = items.map(
                item => {
                  let fields = e.fields(item)
                  let body = fields.remove("body")
                  if "aspect-ratio" in fields {
                    fields.remove("aspect-ratio")
                  }
                  return if body.func() == image {
                    layout(
                      ((width, height)) =>
                      rescale(body, width: width, height: height, ..fields)
                    )
                  } else { body }
                }
              )
              grid(
                ..items,
                columns: aspect-ratio-recis.map(value => value * 1fr),
                column-gutter: column-gutter,
              )
            }
          )
        grid(
          ..rows,
          row-gutter: row-gutter,
          rows: heights,
        )
      })
    } else {
      // vertical then horizontal

      if column-gutter == none {
        column-gutter = secondary-gutter
      }
      if row-gutter == none {
        row-gutter = primary-gutter
      }

      layout(((width,)) => {
        let n-rows = n-rows

        // resolve column gutters and calculate the sum of column gutters
        // direction is corrected
        let (gutter: column-gutter, sum: column-gutter-sum) = resolve-gutter1(
          gutter: column-gutter,
          n: n-cols,
          default-gutter: gutter,
          inv: dir2-inv,
        )

        // resolve row gutters and calculate the sum of row gutters in each column
        let (gutter: row-gutter, sum: row-gutter-sums) = resolve-gutter2(
          gutter: row-gutter,
          n-primary: n-rows,
          n: n-cols,
          default-gutter: gutter,
          dir1-inv: dir1-inv,
          dir2-inv: dir2-inv
        )

        if (dir2-inv) { n-rows = n-rows.rev() }

        // calculate aspect ratios of each image
        let aspect-ratios = children.map(item => item.map(aspect-ratio))
        let aspect-ratio-sums = aspect-ratios.map(array.sum)

        // calculate column widths
        let column-widths = calc-col-widths(
          width,
          aspect-ratio-sums,
          column-gutter-sum,
          row-gutter-sums
        )

        // create `grid`s for each column
        let columns = row-gutter
          .zip(children, column-widths, aspect-ratios)
          .map(
            ((gutter, items, width, aspect-ratio)) => {
              let heights = aspect-ratio.map(value => width * value)
              let items = items.zip(heights).map(((item, height)) => {
                let fields = e.fields(item)
                let body = fields.remove("body")
                if "aspect-ratio" in fields {
                  fields.remove("aspect-ratio")
                }
                return if body.func() == image {
                  rescale(
                    body,
                    width: width,
                    height: height,
                    ..fields,
                  )
                } else {
                  body
                }
              })
              grid(..items, row-gutter: gutter, rows: heights)
            }
          )

        grid(
          ..columns,
          column-gutter: column-gutter,
          columns: column-widths,
        )
      })
    }
  },
  parse-args: arbitrary-pos-arg-parser,
)

#let image-matrix = e.element.declare(
  "image-matrix",
  prefix: "booklet-theme.layout.masonry",
  fields: (
    e.field(
      "children",
      e.types.array(content),
      named: false,
      default: (),
    ),
    e.field(
      "columns",
      e.types.smart(e.types.union(int, e.types.array(fraction))),
      default: 1,
      named: true,
    ),
    e.field(
      "rows",
      e.types.smart(e.types.union(int, e.types.array(fraction))),
      default: auto,
      named: true,
    ),
    e.field(
      "flow",
      e.types.array(direction),
      default: (ltr, ttb),
      named: true,
      folds: false,
    ),
    e.field(
      "gutter",
      length,
      default: 0pt,
      named: true,
    ),
    e.field(
      "row-gutter",
      primary-gutter,
      default: auto,
      named: true,
    ),
    e.field(
      "column-gutter",
      primary-gutter,
      default: auto,
      named: true,
    ),
  ),
  allow-unknown-fields: true,
  parse-args: arbitrary-pos-arg-parser,
  display: el => {
    let (
      children,
      rows,
      columns: cols,
      flow,
      gutter,
      row-gutter,
      column-gutter,
    ) = e.fields(el)
    let n-items = children.len()

    // convert row / column number to repeating `1fr`s
    if type(rows) == int {
      rows = (1fr,) * rows
    }
    if type(cols) == int {
      cols = (1fr,) * cols
    }

    // regularize parameters
    // calculate number of rows and columns
    // pad or trim `children` to desired number of cells
    let n-rows
    let n-cols
    let n-cells

    if rows == auto {
      if columns == auto {
        n-rows = n-items
        n-cols = 1
        rows = (1fr,) * n-items
        cols = (1fr,)
        n-cells = n-rows * n-cols
      } else {
        n-cols = cols.len()
        n-rows = cdiv(n-items, n-cols)
        rows = (1fr,) * n-rows
        // pad with empty grids
        n-cells = n-rows * n-cols
        children += ([],) * (n-cells - n-items)
      }
    } else if cols == auto {
      n-rows = rows.len()
      n-cols = cdiv(n-items, n-rows)
      cols = (1fr,) * n-cols
      // pad with empty grids
      n-cells = n-rows * n-cols
      children += ([],) * (n-cells - n-items)
    } else {
      n-rows = rows.len()
      n-cols = cols.len()
      n-cells = n-rows * n-cols
      if n-cells < n-items {
        // remove residual cells
        children = children.slice(0, n-cells)
      } else if n-cells > n-items {
        // pad with empty grids
        children += ([],) * (n-cells - n-items)
      }
    }

    children = reflow(
      children
        .map(resolve-masonry-item)
        .chunks(n-cols),
      flow: flow
    ).join()

    let (
      gutter: row-gutter,
      sum: row-gutter-sum,
    ) = resolve-gutter1(
      gutter: row-gutter,
      default-gutter: gutter,
      n: n-rows,
    )
    let (
      gutter: column-gutter,
      sum: column-gutter-sum,
    ) = resolve-gutter1(
      gutter: column-gutter,
      default-gutter: gutter,
      n: n-cols,
    )
    let column-fraction-sum = cols.sum(default: 0fr)
    let row-fraction-sum = rows.sum(default: 0fr)

    layout(((width,)) => {
      let fr = (width - column-gutter-sum) / (column-fraction-sum / 1fr)
      let height = fr * (row-fraction-sum / 1fr) + row-gutter-sum
      block(
        grid(
          ..children.map(
            item => {
              let fields = e.fields(item)
              let body = fields.remove("body")
              if "aspect-ratio" in fields {
                fields.remove("aspect-ratio")
              }
              if body.func() == image {
                return layout(((width, height)) => {
                  rescale(body, width: width, height: height, ..fields)
                })
              } else {
                return body
              }
            }
          ),
          // ..args,
          rows: rows,
          columns: cols,
          row-gutter: row-gutter,
          column-gutter: column-gutter,
        ),
        width: 100%,
        height: height,
      )
    })
  },
)
