#!/usr/bin/env nextflow
/*
========================================================================================
                    CRISPResso-NF PIPELINE - CRISPR/CAS9 AMPLICON ANALYSIS PIPELINE
========================================================================================
 CRISPResso-NF Pipeline Started 2026-04-29.
 #### Homepage / Documentation
 https://github.com/FrederickMappin/crispresso-nf
 #### Contributors
 Frederick Mappin
========================================================================================
========================================================================================

Pipeline steps:

    1. FASTP
       - Trim and filter paired-end FASTQ reads
       - Output: per-sample trimmed FASTQs, HTML and JSON QC reports

    2. CRISPResso
       - Quantify CRISPR/Cas9 editing outcomes from the trimmed amplicon reads
       - Output: per-sample CRISPResso_on_<sample> result directories

*/

nextflow.enable.dsl=2

/*
========================================================================================
    HELP MESSAGE
========================================================================================
*/

def helpMessage() {
    log.info"""
========================================================================================
                    CRISPResso-NF PIPELINE - Help Message
========================================================================================

  Docs : https://github.com/FrederickMappin/crispresso-nf

Usage:
  nextflow run main.nf --samplesheet <samplesheet.csv> [options]

========================================================================================

Parameters:

    --samplesheet     Path to samplesheet CSV/TSV file.
                      Required columns: sample, read1, read2, amplicon, guide

    --outdir          Directory where results will be saved  [default: results]

    --test            Use the built-in test samplesheet (test_data/samplesheet.csv)
                      Overrides --samplesheet

    --fastp_extra     Additional arguments passed verbatim to fastp

    --crispresso_extra
                      Additional arguments passed verbatim to CRISPResso

========================================================================================

Profiles:

  docker        Run with Docker (image: crispresso-nf:latest).
                Build locally first:  docker build -t crispresso-nf .

                nextflow run main.nf -profile docker --samplesheet samplesheet.csv

  test          Quick test run using the bundled test data.

                nextflow run main.nf --test
                nextflow run main.nf -profile docker --test

========================================================================================

Override examples:

  # Basic run
  nextflow run main.nf --samplesheet samplesheet.csv

  # Docker run with custom output directory
  nextflow run main.nf -profile docker \\
      --samplesheet samplesheet.csv \\
      --outdir my_results

  # Pass extra fastp and CRISPResso options
  nextflow run main.nf --samplesheet samplesheet.csv \\
      --fastp_extra '--length_required 50' \\
      --crispresso_extra '--min_frequency_alleles_around_cut_to_plot 0.05'

========================================================================================

Outputs (written to --outdir/):

  fastp/                    fastp HTML + JSON QC reports per sample
  CRISPResso_on_<sample>/   CRISPResso result directory per sample

========================================================================================
    """.stripIndent()
}

/*
========================================================================================
    PARAMETERS
========================================================================================
*/

params.help             = false
params.test             = false
params.samplesheet      = null
params.outdir           = 'results'
params.fastp_extra      = ''
params.crispresso_extra = ''

if ( params.help ) {
    helpMessage()
    exit 0
}

if ( !params.test && !params.samplesheet ) {
    error "Please provide --samplesheet (CSV/TSV with read1, read2, amplicon, guide and optional sample columns)."
}

/*
========================================================================================
    SAMPLESHEET PARSING
========================================================================================
*/

def samplesheetPath = params.test ? "${projectDir}/test/samplesheet.csv" : params.samplesheet

def sheetFile = file(samplesheetPath)
if ( !sheetFile.exists() ) {
    error "Samplesheet not found: ${samplesheetPath}"
}

def sep = sheetFile.name.toLowerCase().endsWith('.tsv') ? '\t' : ','
def sheetDir = sheetFile.parent ?: '.'

// Resolve FASTQ paths from either launch dir or samplesheet directory.
def resolveFastq = { String rawPath ->
    def candidate = file(rawPath)
    if ( candidate.exists() ) {
        return candidate
    }

    def relCandidate = file("${sheetDir}/${rawPath}")
    if ( relCandidate.exists() ) {
        return relCandidate
    }

    error "FASTQ not found: ${rawPath}"
}

Channel
    .fromPath(samplesheetPath)
    .splitCsv(header: true, sep: sep)
    .map { row ->
        def read1 = row.read1 ?: row.Read1 ?: row.R1
        def read2 = row.read2 ?: row.Read2 ?: row.R2
        def amplicon = row.amplicon ?: row.Amplicon
        def guide = row.guide ?: row.Guide

        if ( !read1 || !read2 || !amplicon || !guide ) {
            error "Each row must include read1, read2, amplicon, and guide columns. Offending row: ${row}"
        }

        def sample = row.sample ?: row.Sample ?: (resolveFastq(read1).baseName.replaceAll(/_R?1.*/, ''))

        tuple(sample as String, resolveFastq(read1), resolveFastq(read2), amplicon as String, guide as String)
    }
    .set { crispresso_input_ch }

/*
========================================================================================
    PROCESSES
========================================================================================
*/

process FASTP {
        tag "${sample_id}"

        publishDir "${params.outdir}/fastp", mode: 'copy', pattern: '*.fastp.*'

        cpus 2
        memory '4 GB'

        input:
        tuple val(sample_id), path(read1), path(read2), val(amplicon), val(guide)

        output:
        tuple val(sample_id), path("${sample_id}_trimmed_R1.fastq.gz"), path("${sample_id}_trimmed_R2.fastq.gz"), val(amplicon), val(guide), emit: trimmed_reads
        path "${sample_id}.fastp.html", emit: html
        path "${sample_id}.fastp.json", emit: json

        script:
        def extra = params.fastp_extra ?: ''
        """
        fastp \
            --thread ${task.cpus} \
            --in1 ${read1} \
            --in2 ${read2} \
            --out1 ${sample_id}_trimmed_R1.fastq.gz \
            --out2 ${sample_id}_trimmed_R2.fastq.gz \
            --html ${sample_id}.fastp.html \
            --json ${sample_id}.fastp.json \
            ${extra}
        """
}

process CRISPRESSO {
    tag "${sample_id}"

    publishDir params.outdir, mode: 'copy', pattern: 'CRISPResso_on_*'

    cpus 2
    memory '4 GB'

    input:
    tuple val(sample_id), path(read1), path(read2), val(amplicon), val(guide)

    output:
    path "CRISPResso_on_${sample_id}", emit: reports

    script:
    def extra = params.crispresso_extra ?: ''
    """
    CRISPResso \
      --name ${sample_id} \
      --fastq_r1 ${read1} \
      --fastq_r2 ${read2} \
      --amplicon_seq ${amplicon} \
      --guide_seq ${guide} \
      --output_folder . \
      ${extra}
    """
}

/*
========================================================================================
    WORKFLOW
========================================================================================
*/

workflow {
    FASTP(crispresso_input_ch)
    CRISPRESSO(FASTP.out.trimmed_reads)
}
