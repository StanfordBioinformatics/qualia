# Processing data from Bina

This document will cover the steps used to process genomic data from Bina on Google Cloud.  We will cover several QC steps on the bam files, VCFs, and finally how to get the data into BigQuery.

## Unpacking and Decryption

The data is delivered to one of our [Google buckets](https://console.cloud.google.com/storage/browser/gbsc-gcp-project-mvp-received-from-bina/?project=gbsc-gcp-project-mvp) in the form of tarballs of PGP encrypted files.  The first step in processing is to unpack and decrypt them.  To do this we have a Pipelines API [pipeline](https://github.com/StanfordBioinformatics/pipelines-api-examples/tree/master/decrypt).  Copy the entire repo to your local machine and make sure you have the proper credentials set up to run things on the cloud from your computer.

Data is delivered to this bucket
```
gs://gbsc-gcp-project-mvp-received-from-bina
```

The easiest way to launch a series of pipelines API jobs to decrypt is as follows.

```
for x in `cat sample_list.txt ` ; do 
  sample=`echo $x | cut -f1 -d,` ; 
  file=`echo $x | cut -f2 -d,`; 
  echo $file ; \
  PYTHONPATH=.. python ./run_decrypt.py     \
    --project gbsc-gcp-project-mvp     \
    --zones "us-central1-*"   \
    --disk-size 1024  \
    --input gs://gbsc-gcp-project-mvp-received-from-bina/$sample/$file.tar.pgp \
    gs://gbsc-gcp-project-mvp-va_aaa/misc/keys/pair.asc \
    gs://gbsc-gcp-project-mvp-va_aaa/misc/keys/passphrase.txt  \
    --output gs://gbsc-gcp-project-mvp-phase-2-data/data/bina-deliverables/$sample/$file \
    --logging gs://gbsc-gcp-project-mvp-phase-2-data/data/bina-deliverables/$sample/$file/logging \
; done
```

Where sample_list.txt is a newline delimited file containing the google cloud paths to the files that need to be unpacked and decrypted.

The ordering of the keys files are important for the pipeline.

Example
```
gs://gbsc-gcp-project-mvp-received-from-bina/400264758/4bdfdc5b-88c6-4469-a227-e4fc4f633757.tar.pgp
gs://gbsc-gcp-project-mvp-received-from-bina/400264758/650fa686-c297-4398-8b6a-0cfa24a58846.tar.pgp
```

You can generate this list like this, but make sure to exclude previously processed samples.
```
gsutil ls gs://gbsc-gcp-project-mvp-received-from-bina/*
```

The ouput of this process is the full deliverable from Bina.

*NOTE: Using [Dockerflow](https://github.com/googlegenomics/dockerflow) is likely the fastest way to submit a batch of pipelines api jobs, but I have not had time to implement it*

## Bam processing
This section covers several quality control steps that may be of interest in processing the bam files.  These were initally designed to validate the quality information provided by Bina, so they may not be necessary to run on every new genome.

### Samtools
Running samtools

[Pipelines API](https://github.com/StanfordBioinformatics/pipelines-api-examples/tree/master/samtools)

Command
```
for x in `cat bina_bams.txt` ; do \
  gcloud alpha genomics pipelines run \
    --pipeline-file cloud/samtools.yaml \
    --inputs inputPath=$x \
    --outputs outputPath=gs://gbsc-gcp-project-mvp-phase-2-data/data/batch_1/samtools/ \
    --logging gs://gbsc-gcp-project-mvp-phase-2-data/data/batch_1/samtools/logging \
    --disk-size datadisk:512 \
; done
```

Where bina_bams.txt is a list of the full paths to the bams to be processed.

Something like this can gather them
```
gsutil ls gs://gbsc-gcp-project-mvp-phase-2-data/data/bina-deliverables/*/*/*/Recalibration | grep bam$ > bina_bams.txt
```
### FastQC

[Pipelines API](https://github.com/StanfordBioinformatics/pipelines-api-examples/tree/master/fastqc)

```
for x in `cat ../samtools/bina_bams.txt` ; do \
  PYTHONPATH=.. python cloud/run_fastqc.py \
    --project gbsc-gcp-project-mvp \
    --zones "us-central1-*" \
    --disk-size 512 \
    --input $x \
    --output gs://gbsc-gcp-project-mvp-phase-2-data/data/batch_1/fastqc/ \
    --logging gs://gbsc-gcp-project-mvp-phase-2-data/data/batch_1/fastqc/logging \
; done
```
The output from FastQC needs to be unzipped before it can be processed.  You can do this again using the [Pipelines API](https://github.com/StanfordBioinformatics/pipelines-api-examples/tree/master/compress)

```
for x in `cat fastq_zips.txt` ; do id=`echo $x | cut -f7 -d/` ;\
  PYTHONPATH=.. python ./run_compress.py \
    --project gbsc-gcp-project-mvp \
    --zones "us-central1-*" \
    --disk-size 5 \
    --operation "unzip" \
    --input $x \
    --output gs://gbsc-gcp-project-mvp-phase-2-data/data/batch_1/fastqc/$id/ \
    --logging gs://gbsc-gcp-project-mvp-phase-2-data/data/batch_1/fastqc/$id/logging \
; done
```

## Variant processing
### Reducing non-variant blocks

The gVCFs from Bina contain many non-variant segments with very fine quality resolution.  This means that the gVCF files are very large, much larger than is necessary or wise to use in BigQuery.  Combining consequtive non-variant segments into a single non-variant segment reduces the size of the gVCFs drastically and leaves the information we care about most.  

*WORK IN PROGRESS*
*WILL BE DONE ASAP*

### Importing to variant set

To get to our final goal of having BigQuery tables with our variant data, we next need to import the gVCFs into a Google Genomics variant set.  This is essentially a json representation of the variant data that can be accessed through the Google Genomics API.  

We will import the reduced gVCFs we produced in the last step.

To perform this step and the following steps you will need to install [gcloud](https://cloud.google.com/sdk/gcloud/).

First, we need to create a dataset.

```
gcloud alpha genomics datasets create --name DATASET_NAME
```

I have started using the following naming convention:

date-dataset-descriptor

Example
20160915-aaa-qc-lite

The output will look like this:
```
Created dataset DATASET_NAME, id: 12406857362375913404
```

Using the numeric ID from the previous step, create a variantset within the dataset.
```
gcloud alpha genomics variantsets create --dataset-id 12406857362375913404
```

Output
```
Created variant set id: 14165412073904006532 "", belonging to dataset id: 12406857362375913404
Created [14165412073904006532].
```

Now we can import the variants.  You will need to provide the path to the specific files to be imported.  You can use regular expressions to point to certain patterns.

```
gcloud alpha genomics variants import --variantset-id 14165412073904006532 --source-uris gs://PATH/TO/VCFs --info-merge-config QD=MOVE_TO_CALLS,FS=MOVE_TO_CALLS,MQ=MOVE_TO_CALLS,VQSLOD=MOVE_TO_CALLS,MQRankSum=MOVE_TO_CALLS,ReadPosRankSum=MOVE_TO_CALLS,PL=MOVE_TO_CALLS,culprit=MOVE_TO_CALLS
```
Output
```
done: false
name: operations/CJ3k0-yGHBCmrYC8BRi1ou-Z5OTE4PEB
```


The MOVE_TO_CALLS commands make sure that these fields are copied into the variantset.  They are only necessary if you want to keep the various scores for QC once the data is in BigQuery.

This command will take about 6 hours to run.  You can monitor the status of the job like this.

```
gcloud alpha genomics operations describe operations/CJ3k0-yGHBCmrYC8BRi1ou-Z5OTE4PEB
```

### Exporting to BigQuery

Finally we can export the data to BigQuery.  We use two different types of tables, a genome_calls table, and a multi_sample_variants table.


#### Genome calls table
Create the genome calls table like this

```
gcloud alpha genomics variantsets export 14165412073904006532 aaa_genome_calls_no_qc --bigquery-dataset va_aaa_pilot_data
```

Again, this will take a while.  Monitor the job as above.

#### Multisample variants table
The multisample variants table is a little more complicated.  Copy [this](https://github.com/StanfordBioinformatics/codelabs) repo to your computer.  

Compile the code like this
```
cd codelabs/Java
mvn compile
mvn bundle:bundle
```

And launch the export job like this
```
java -cp target/non-variant-segment-transformer-*runnable.jar \
  com.google.cloud.genomics.examples.TransformNonVariantSegmentData \
  --project=gbsc-gcp-project-mvp \
  --stagingLocation=gs://gbsc-gcp-project-mvp-va_aaa_hadoop/dataflow/staging/ \
  --variantSetId=14165412073904006532   \
  --allReferences \
  --hasNonVariantSegments \
  --outputTable=va_aaa_pilot_data.aaa_multisample_variants_no_qc \
  --runner=DataflowPipelineRunner \
  --numWorkers=20
```

Replacing the appropriate fields, of course.  

You can monitor this job through the Google Cloud web interface.  Locate the dataflow tab and find the corresponding job.

### BigQuery QC

Next we can do our quality control in BigQuery.  Through this process we will generate four (!) more BigQuery tables.  A genome_calls table and multisample_variants table after the sample level QC is complete, and another set of tables after the variant level QC is complete.

I'll update this section more soon.


