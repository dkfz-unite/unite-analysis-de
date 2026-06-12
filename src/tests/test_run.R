library(testthat)

# Traverse up from CWD to find the repo root (.git marker).
find_project_root <- function() {
  d <- normalizePath(getwd())
  while (!file.exists(file.path(d, ".git")) && d != dirname(d)) {
    d <- dirname(d)
  }
  d
}

# ── End-to-end test of src/run/run.R ──────────────────────────────────────────
#
# Key behaviour under test:
#   The script should assign the (second (last-occuring) group as the reference category,
#   regardless of their alphabetical labelling
# ─────────────────────────────────────────────────────────────────────────────

# Test design:
#   Metadata order:  control (s1–s3, first),  treated (s4–s6, last / second-occurring)
#   Expected reference → "treated" (last-occurring)
#
#   gene1: high in control, low in treated → LFC = log2(control/treated) > 0
#   gene2: low in control,  high in treated → LFC = log2(control/treated) < 0


test_that("last-occurring condition in metadata is the DESeq2 reference level", {

  tmpdir <- tempfile(pattern = "run_test_")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  counts_file   <- file.path(tmpdir, "counts.tsv")
  metadata_file <- file.path(tmpdir, "metadata.tsv")
  output_file   <- file.path(tmpdir, "results.tsv")

  # gene1: clearly higher in control; gene2: clearly higher in treated.
  # hk_*: 300 housekeeping genes stable across conditions, drawn from a
  # negative-binomial distribution at means spanning 5–8000 counts so DESeq2
  # has enough range to fit a parametric dispersion trend without falling back
  # to local regression (which fails with locfit on small datasets).
  set.seed(42)
  n_hk    <- 300
  hk_means <- round(exp(seq(log(5), log(8000), length.out = n_hk)))
  hk_mat   <- do.call(rbind, lapply(hk_means, function(mu) rnbinom(6, mu = mu, size = 10)))
  hk_names <- paste0("hk_", sprintf("%03d", seq_len(n_hk)))

  counts <- data.frame(
    gene_id = c("gene1", "gene2", hk_names),
    s1 = c(1000,   10, hk_mat[, 1]),
    s2 = c(1200,    8, hk_mat[, 2]),
    s3 = c( 900,   12, hk_mat[, 3]),
    s4 = c(  10, 1000, hk_mat[, 4]),
    s5 = c(   8, 1200, hk_mat[, 5]),
    s6 = c(  12,  900, hk_mat[, 6])
  )
  write.table(counts, counts_file, sep = "\t", quote = FALSE, row.names = FALSE)

  # "control" appears FIRST; "treated" appears LAST (second / last-occurring).
  # Expected: "treated" is the reference level.
  meta <- data.frame(
    sample    = c("s1",      "s2",      "s3",      "s4",      "s5",      "s6"),
    condition = c("control", "control", "control", "treated", "treated", "treated")
  )
  write.table(meta, metadata_file, sep = "\t", quote = FALSE, row.names = FALSE)

  script_path <- file.path(find_project_root(), "src", "run", "run.R")
  skip_if_not(file.exists(script_path), "run.R not found — run from within the repository")

  script_output <- system2(
    "Rscript",
    args   = c(script_path, counts_file, metadata_file, output_file),
    stdout = TRUE,
    stderr = TRUE
  )

  if (!file.exists(output_file)) {
    fail(paste("Script did not produce output file. Script output:\n",
               paste(script_output, collapse = "\n")))
  }

  res <- read.table(output_file, header = TRUE, sep = "\t", check.names = FALSE)
  rownames(res) <- res$ID

  # With "treated" as reference (last-occurring): LFC = log2(control / treated).
  # gene1 (high in control, low in treated)  → LFC > 0
  # gene2 (low in control,  high in treated) → LFC < 0
  expect_gt(
    res["gene1", "log2FoldChange"], 0,
    label = "gene1 LFC > 0: control >> treated; positive only when treated is the reference"
  )
  expect_lt(
    res["gene2", "log2FoldChange"], 0,
    label = "gene2 LFC < 0: treated >> control; negative only when treated is the reference"
  )

  # The contrast column should name the non-reference condition against the
  # reference, confirming which comparison was made.
  expect_true(
    "contrast" %in% colnames(res),
    info = "output must contain a 'contrast' column"
  )
  expect_match(
    res["gene1", "contrast"],
    "^control - treated",
    info = "contrast should be 'control - treated' when treated is the reference"
  )
})
