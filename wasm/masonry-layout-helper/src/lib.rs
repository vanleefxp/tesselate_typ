mod core;
use wasm_minimal_protocol::*;

initiate_protocol!();

#[derive(serde::Deserialize)]
struct CalcColumnWidthArgs {
    width: f64,
    aspect_ratios: Vec<f64>,
    col_gap: f64,
    row_gaps: Vec<f64>,
}

#[wasm_func]
pub fn masonry_col_widths(arg: &[u8]) -> Vec<u8> {
    let args: CalcColumnWidthArgs = ciborium::de::from_reader(arg).unwrap();
    let column_widths = core::masonry_col_widths(
        args.width,
        &args.aspect_ratios,
        args.col_gap,
        &args.row_gaps,
    );
    let mut out = Vec::new();
    ciborium::ser::into_writer(&column_widths, &mut out).unwrap();
    out
}
