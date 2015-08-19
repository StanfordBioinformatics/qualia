## Collect arguments
args <- commandArgs(TRUE)

## Default setting when no arguments passed
if(length(args) < 1) {
  args <- c("--help")
}

## Help section
if("--help" %in% args) {
  cat("
      The R Script
 
      Arguments:
      --drive_id=DRIVE_ID   - The hard drive ID from which the samples originated
      --path=/PATH/TO/FASTQC/RESULTS   - Path to the directory where the FastQC results are stored.  Only SAMPLE_fastqc_data.txt allowed in the directory.
      --help              - print this text
 
      Example:
      ./fastqc_analysis.R --drive_id='CLA00127' --path='fastqc/CLA00127' \n\n")
  
  q(save="no")
}

## Parse arguments (we expect the form --arg=value)
parseArgs <- function(x) strsplit(sub("^--", "", x), "=")
argsDF <- as.data.frame(do.call("rbind", parseArgs(args)))
argsL <- data.frame(t(as.character(argsDF$V2)))
#print(argsL)
names(argsL) <- argsDF$V1

#print(args)
print(argsL)

## Arg1 default
if(is.null(argsL$drive_id)) {
  print("ERROR: Drive ID required.")
  stop()
}

## Arg2 default
if(is.null(argsL$path)) {
  print("ERROR: Path to FastQC results required.")
  stop()
}

drive_id = argsL$drive_id
fastqc_output = as.character(argsL$path)


#### TESTING
#fastqc_output = '~/projects/mvp/claritas/fastqc/'
#drive_id = 'CLA00127'
####

print("Running analysis of FastQC results")
print(paste("Drive ID: ", drive_id, sep=""))
print(paste("FastQC Directory: ", fastqc_output, sep=""))

## Start script
require(ggplot2)
source("~/src/qualia/data/fastqc_helper.R")

# Build reference
reference_filename = '~/src/qualia/data/IonTorrent_NA12878_V3.fastqc_data.txt'
reference_lines = readLines(reference_filename)
# Define dataframes to store results
for (i in 1:length(reference_lines)) {
  if (grepl(">>Per base sequence quality", reference_lines[i])) {
    reference_mean_base_quality <- MeanPerBaseQuality(reference_lines, i+2)
    print(paste("Reference Mean Base Quality: ", reference_mean_base_quality))
    reference_base_quality <- ExtractPerBaseQuality(reference_lines, i+2)
    reference_base_quality$SampleName = 'NA12878'
  } else if (grepl(">>Per sequence quality scores", reference_lines[i])) {
    reference_mean_sequence_quality <- MeanQuality(reference_lines, i+2)
    print(paste("Reference Mean Sequence Quality: ", reference_mean_sequence_quality))
  } else if (grepl(">>Per sequence GC content", reference_lines[i])) {
    reference_mean_gc_content <- MeanQuality(reference_lines, i+2)
    print(paste("Reference Mean GC Content: ", reference_mean_gc_content))
  } else if (grepl(">>Sequence Length Distribution", reference_lines[i])) {
    reference_median_sequence_length <- MedianSequenceLength(reference_lines, i+2)
    print(paste("Reference Median Sequence Length: ", reference_median_sequence_length))
  }
}

# Read in all other files
sample_files <- list.files(fastqc_output)
sample_df <- data.frame("SampleName" = character(0), "MeanBaseQuality" = numeric(0), "MeanSequenceQuality" = numeric(0),
                        "MeanGCContent" = numeric(0), "LowPerBaseQuality" = logical(0), "HighKmerContent" = logical(0),
                        "MedianSequenceLength" = numeric(0))
per_base_quality_df <- data.frame("SampleName" = character(0), "Range" = character(0), "Mean" = numeric(0), "Median" = numeric(0))
for (i in 1:length(sample_files)) {
  current_file <- sample_files[i]
  print(current_file)
  sample_name <- strsplit(current_file,"_")[[1]][1]
  file_content = readLines(paste(fastqc_output, current_file, sep="/"))
  for (i in 1:length(file_content)) {
    if (grepl(">>Per base sequence quality", file_content[i])) {
      mean_base_quality <- MeanPerBaseQuality(file_content, i+2)
      per_base_quality <- ExtractPerBaseQuality(file_content, i+2)
      low_per_base_quality <- LowPerBaseQuality(reference_base_quality, per_base_quality)
      per_base_quality$SampleName <- sample_name
      per_base_quality_df <- rbind(per_base_quality_df, per_base_quality)
    } else if (grepl(">>Per sequence quality scores", file_content[i])) {
      mean_sequence_quality <- MeanQuality(file_content, i+2)
    } else if (grepl(">>Per sequence GC content", file_content[i])) {
      mean_gc_content <- MeanQuality(file_content, i+2)
    } else if (grepl(">>Kmer Content", file_content[i])) {
      kmer_content <- CheckKmerContent(file_content, i+2)
    } else if (grepl(">>Sequence Length Distribution", file_content[i])) {
      median_sequence_length <- MedianSequenceLength(file_content, i+2)
    }
  }
  row = data.frame("SampleName" = sample_name, "MeanBaseQuality" = mean_base_quality, 
                   "MeanSequenceQuality" = mean_sequence_quality, "LowPerBaseQuality" = low_per_base_quality, 
                   "MeanGCContent" = mean_gc_content, "HighKmerContent" = kmer_content, "MedianSequenceLength" = median_sequence_length)
  sample_df <- rbind(sample_df, row)
}

# Write raw data
write.csv(per_base_quality_df, paste(drive_id, "base-quality.csv", sep="."))
write.csv(sample_df, paste(drive_id, "fastqc-results", sep="."))

# Create plots
plot_theme = theme_minimal(base_size = 24, base_family = "Helvetica") + 
  theme(axis.line = element_line(colour = "black"),
        panel.grid = element_blank())

ggplot(sample_df) +
  geom_point(aes(SampleName, MeanBaseQuality), size=4) +
  geom_hline(yintercept = reference_mean_base_quality) +
  ggtitle("Average Base Quality") +
  xlab("Sample") +
  ylab("Mean base quality over all reads") +
  plot_theme +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

ggsave(paste(drive_id, "base-quality.png", sep="."))

ggplot(sample_df) +
  geom_point(aes(SampleName, MeanSequenceQuality), size=4) +
  geom_hline(yintercept = reference_mean_sequence_quality) +
  ggtitle("Average Sequence Quality") +
  xlab("Sample") +
  ylab("Mean sequence quality over all sequences") +
  plot_theme +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

ggsave(paste(drive_id, "sequence-quality.png", sep="."))

ggplot(sample_df) +
  geom_point(aes(SampleName, MeanGCContent), size=4) +
  geom_hline(yintercept = reference_mean_gc_content) +
  ggtitle("Average GC Content") +
  xlab("Sample") +
  ylab("Mean gc content over all sequences") +
  plot_theme +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

ggsave(paste(drive_id, "gc-content.png", sep="."))

ggplot(sample_df) +
  geom_point(aes(SampleName, MedianSequenceLength), size=4) +
  geom_hline(yintercept = reference_median_sequence_length) +
  ggtitle("Median sequence length") +
  xlab("Sample") +
  ylab("Median sequence length") +
  plot_theme +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank())

ggsave(paste(drive_id, "sequence-length.png", sep="."))

ggplot(per_base_quality_df) +
  geom_point(aes(Range, Mean, color=SampleName), alpha = 0.4, size = 3) +
  geom_point(data = reference_base_quality, aes(Range, Mean), size = 4) +
  plot_theme + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1),
        legend.position="none")

ggsave(paste(drive_id, "base-quality-all.png", sep="."))