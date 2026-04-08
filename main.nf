nextflow.enable.dsl=2

params.samplesheet = null
params.outdir = 'results'
params.fastp_extra = ''
params.crispresso_extra = ''

if ( !params.samplesheet ) {
    error "Please provide --samplesheet (CSV/TSV with read1, read2, amplicon, guide and optional sample columns)."
}

def sheetFile = file(params.samplesheet)
if ( !sheetFile.exists() ) {
    error "Samplesheet not found: ${params.samplesheet}"
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
    .fromPath(params.samplesheet)
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

workflow {
    FASTP(crispresso_input_ch)
    CRISPRESSO(FASTP.out.trimmed_reads)
}
