#let div = calc.div-euclid
#let mod = calc.rem-euclid

#let cdiv(a, b) = {
  let q = div(a, b)
  let r = mod(a, b)
  if r == 0 { q } else { q + 1 }
}


/// argument parser for `elembic` elements that accepts an arbitrary number of positional arguments.
#let arbitrary-pos-arg-parser(default-parser, fields: none, typecheck: none) = {
  (args, include-required: false) => {
    let args = if include-required {
      // receive items as an arbitrary number of positional arguments
      let pos-args = args.pos()
      arguments(pos-args, ..args.named())
    } else if args.pos() == () {
      args
    } else {
      return (false, "unexpected positional arguments\n  hint: these can only be passed to the constructor")
    }
    default-parser(args, include-required: include-required)
  }
}

#let dir-is-inv(dir) = {
  let start = dir.start()
  start == right or start == bottom
}

#let transpose(arr) = {
  if arr.len() == 0 { arr }
  else { arr.at(0).zip(..arr.slice(1)) }
}

#let reflow(arr, flow: (ltr, ttb)) = {
  let arr = arr
  let n-rows = arr.len()

  let (dir1, dir2) = flow
  // the two directions must have different axes
  assert.ne(dir1.axis(), dir2.axis())

  let dir1-is-inv = dir-is-inv(dir1)
  let dir2-is-inv = dir-is-inv(dir2)
  let should-transpose = dir1.axis() == "vertical"
  if should-transpose {
    // needs transpose
    arr = arr.join().chunks(n-rows)
  }
  if dir1-is-inv { arr = arr.map(array.rev) }
  if dir2-is-inv { arr = arr.rev() }
  if should-transpose {
    arr = transpose(arr)
  }
  arr
}

#let reshape(arr, n-rows: auto, n-cols: auto, pad: none) = {
  let arr = arr
  let n-eles = arr.len()
  let n-rows = n-rows
  let n-cols = n-cols

  if n-rows == auto {
    if n-cols == auto {
      n-rows = arr
      n-cols = 1
    } else {
      n-rows = cdiv(n-eles, n-cols)
      arr += (pad,) * (n-rows * n-cols - n-eles)
    }
  } else if n-cols == auto {
    n-cols = cdiv(n-eles, n-rows)
    arr += (pad,) * (n-rows * n-cols - n-eles)
  } else {
    let n-grids = n-rows * n-cols
    if n-grids < n-eles {
      arr = arr.slice(0, n-grids)
    } else {
      arr += (pad,) * (n-grids - n-eles)
    }
  }
  arr.chunks(n-cols)
}


