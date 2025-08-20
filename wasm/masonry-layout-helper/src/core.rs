pub fn masonry_col_widths(
    width: f64,
    aspect_ratios: &[f64],
    col_gap: f64,
    row_gaps: &[f64],
) -> Vec<f64> {
    let k_i_reci_sum: f64 = aspect_ratios.iter().map(|&k_i| 1.0 / k_i).sum();
    let d_i_over_k_i_sum: f64 = row_gaps
        .iter()
        .zip(aspect_ratios.iter())
        .map(|(&d_i, &k_i)| d_i / k_i)
        .sum();
    let height = (width - col_gap + d_i_over_k_i_sum) / k_i_reci_sum;
    let col_widths = row_gaps
        .iter()
        .zip(aspect_ratios.iter())
        .map(|(d_i, k_i)| (height - d_i) / k_i)
        .collect();
    col_widths
}
