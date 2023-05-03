version 1.0

workflow amr_analysis {

  Array[String] READS = ["R1", "R2"]

  input{
     Array[File] fastqFiles
     String dockerRegistry
     #File card_db = "card_db/card.fasta"
  }

  scatter (fastqFile in fastqFiles) {

        call fastqc_raw {
            input:
                fastqFile = fastqFile,
                dockerRegistry = dockerRegistry
                
        }
    }
  

  call multiqc_raw {
  input:
    input_files = fastqc_raw.outZip,
  }
  
  # scatter (sample in SAMPLES) {
  #   Array[File] sample_files = glob(fastqc_raw.fastqc_zip)
  #   Array[File] fw_files = filter(sample_files, file -> file.basename.contains("_R1_"))
  #   Array[File] rv_files = filter(sample_files, file -> file.basename.contains("_R2_"))
  #   call cutadapt {
  #     input: 
  #       fw = fw_files,
  #       rv = rv_files
  #       threads = 1
  #   }
  # }
}

task fastqc_raw {

    input {
        File fastqFile

        # docker-related
        String dockerRegistry
    }

    Int numCores = 4
    String dockerImage = dockerRegistry + "/cromwell-fastqc:0.11.9"
    Float inputSize = size(fastqFile, "GiB")

    command <<<
        set -euo pipefail

        fastqc -o . ~{fastqFile}
    >>>

    output {
        File outHtml = basename(fastqFile, ".fastq.gz") + "_fastqc.html"
        File outZip = basename(fastqFile, ".fastq.gz") + "_fastqc.zip"
    }

    runtime {
        docker: dockerImage
        disks: "local-disk " + ceil(2 * (if inputSize < 1 then 1 else inputSize )) + " HDD"
        cpu: numCores
        memory: "16 GB"
    }
}

task multiqc_raw {
  input {
    Array[File]     input_files = []

    Boolean         force = false
    Boolean         full_names = false
    String?         title
    String?         comment
    String?         file_name
    String          out_dir = "./multiqc-output"
    String?         template
    String?         tag
    String?         ignore_analysis_files
    String?         ignore_sample_names
    File?           sample_names
    Array[String]?  exclude_modules
    Array[String]?  module_to_use
    Boolean         data_dir = false
    Boolean         no_data_dir = false
    String?         output_data_format
    Boolean         zip_data_dir = false
    Boolean         export = false
    Boolean         flat = false
    Boolean         interactive = true
    Boolean         lint = false
    Boolean         pdf = false
    Boolean         megaQC_upload = false # Upload generated report to MegaQC if MegaQC options are found
    File?           config  # directory
    String?         config_yaml

    String          docker = "quay.io/biocontainers/multiqc:1.8--py_2"
  }

  parameter_meta {
    output_data_format: { description: "[tsv|yaml|json] default:tsv" }
  }

  # get the basename in all wdl use the filename specified (sans ".html" extension, if specified)
  String report_filename = if (defined(file_name)) then basename(select_first([file_name]), ".html") else "multiqc"

  command {
      set -ex -o pipefail

      echo "${sep='\n' input_files}" > input-filenames.txt
      echo "" >> input-filenames.txt

      multiqc \
      --file-list input-filenames.txt \
      --dirs \
      --outdir "${out_dir}" \
      ${true="--force" false="" force} \
      ${true="--fullnames" false="" full_names} \
      ${"--title " + title} \
      ${"--comment " + comment} \
      ${"--filename " + file_name} \
      ${"--template " + template} \
      ${"--tag " + tag} \
      ${"--ignore " + ignore_analysis_files} \
      ${"--ignore-samples" + ignore_sample_names} \
      ${"--sample-names " + sample_names} \
      ${true="--exclude " false="" defined(exclude_modules)}${sep=' --exclude ' select_first([exclude_modules,[]])} \
      ${true="--module " false="" defined(module_to_use)}${sep=' --module ' select_first([module_to_use,[]])} \
      ${true="--data-dir" false="" data_dir} \
      ${true="--no-data-dir" false="" no_data_dir} \
      ${"--data-format " + output_data_format} \
      ${true="--zip-data-dir" false="" zip_data_dir} \
      ${true="--export" false="" export} \
      ${true="--flat" false="" flat} \
      ${true="--interactive" false="" interactive} \
      ${true="--lint" false="" lint} \
      ${true="--pdf" false="" pdf} \
      ${false="--no-megaqc-upload" true="" megaQC_upload} \
      ${"--config " + config} \
      ${"--cl-config " + config_yaml }

      if [ -z "${file_name}" ]; then
        mv "${out_dir}/${report_filename}_report.html" "${out_dir}/${report_filename}.html"
      fi

      tar -c "${out_dir}/${report_filename}_data" | gzip -c > "${report_filename}_data.tar.gz"
  }

  output {
      File multiqc_report            = "${out_dir}/${report_filename}.html"
      File multiqc_data_dir_tarball  = "${report_filename}_data.tar.gz"
  }

  runtime {
    memory: "3 GB"
    cpu: 2
    docker: "${docker}"
    disks: "local-disk 375 LOCAL"
    dx_instance_type: "mem1_ssd1_v2_x2"
  }
}

# task cutadapt {
#   File sample_files
#   # File fw
#   # File rv
#   Int threads

#   input{
#     sample_files
#     threads
#   }
  
#   fw = 
#   rv = 

#   command {
#     cutadapt -a CTGTCTCTTATACACATCT -A CTGTCTCTTATACACATCT -O 10 -m 30 -q 20 {input.fw} {input.rv} -o {output.fw} -p {output.rv} > {output.log}
#   }

#   output {
#     File fw_trimmed = "trimmed_data/${basename(fw, ".fastq.gz")}_trimmed.fastq.gz"
#     File rv_trimmed = "trimmed_data/${basename(rv, ".fastq.gz")}_trimmed.fastq.gz"
#     File log = "trimmed_data/${basename(fw, ".fastq.gz")}.trimmed.txt"
#   }

#   runtime{
#     #docker: "ubuntu:latest"
#     conda: "envs/cutadapt.yml"
#   }
# }