# crispresso-nf

Minimal Nextflow pipeline for CRISPResso paired-end amplicon editing analysis.

## Requirements

- Nextflow (23+ recommended)
- CRISPResso available in your environment (`CRISPResso` on `PATH`), or use the Docker profile

## Samplesheet format

Provide `--samplesheet` as CSV or TSV with these required columns:

- `read1`
- `read2`
- `amplicon`
- `guide`

Optional column:

- `sample` (if omitted, a sample name is inferred from `read1`)

Example (`samplesheet.csv`):

```csv
sample,read1,read2,amplicon,guide
s1,reads1.fastq.gz,reads2.fastq.gz,AATGTCCCCCAATGGGAAGTTCATCTGGCACTGCCCACAGGTGAGGAGGTCATGATCCCCTTCTGGAGCTCCCAACGGGCCGTGGTCTGGTTCATCATCTGTAAGAATGGCTTCAAGAGGCTCGGCTGTGGTT,TGAACCAGACCACGGCCCGT
```

## Run

Local environment:

```bash
nextflow run main.nf --samplesheet samplesheet.csv --outdir results
```

Docker profile:

```bash
nextflow run main.nf -profile docker --samplesheet samplesheet.csv --outdir results
```

Pass extra CRISPResso flags via:

```bash
nextflow run main.nf --samplesheet samplesheet.csv --crispresso_extra "--quantification_window_size 1"
```

## Outputs

Results are copied to `--outdir` (default: `results`) as per-sample CRISPResso folders:

- `CRISPResso_on_<sample>`
