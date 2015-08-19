require(plyr)
require(cwhmisc)

MeanPerBaseQuality <- function(lines, i) {
  sum <- 0
  count <- 0
  while (!grepl(">>END_MODULE", lines[i])) {
    current <- strsplit(lines[i],"\t")[[1]]
    if (nchar(current[1]) == 1) {
      count <- count + 1
      sum <- sum + as.numeric(current[2])
    } else {
      count <- count + 10
      sum <- sum + (as.numeric(current[2]) * 10)
    }
    i <- i + 1
  }
  mean <- sum/count
  return(mean)
}

MeanQuality <- function(lines, i) {
  sum <- 0
  count <- 0
  while (!grepl(">>END_MODULE", lines[i])) {
    current <- strsplit(lines[i],"\t")[[1]]
    row_count <- as.numeric(current[2])
    count <- count + row_count
    sum <- sum + (as.numeric(current[1]) * row_count)
    i <- i + 1
  }
  mean <- sum/count
  return(mean)
}

ExtractPerBaseQuality <- function(lines, i) {
  df <- data.frame("Range" = character(0), "Mean" = numeric(0), "Median" = numeric(0))
  while (!grepl(">>END_MODULE", lines[i])) {
    current <- strsplit(lines[i],"\t")[[1]]
    if (nchar(current[1]) > 1) {
      values <- strsplit(current[1], "-")[[1]]
      if (length(values) > 1 && as.numeric(values[2]) %% 10 != 9) {
        values[2] <- round_any(as.numeric(values[2]), 10, f=ceiling) - 1
        current[1] = paste(values[1], as.character(values[2]), sep="-")
      }
      else if (length(values == 1)) {
        values[2] <- as.numeric(values[1]) + 9
        current[1] = paste(values[1], as.character(values[2]), sep="-")
      }
    }
    new_row = data.frame("Range" = current[1], "Mean" = as.numeric(current[2]), "Median" = as.numeric(current[3]))
    df = rbind(df, new_row)
    i <- i + 1
  }
  return(df)
}

CheckKmerContent <- function(lines, i) {
  df <- data.frame("Sequence" = character(0), "PValue" = numeric(0), "Position" = character(0))
  while (!grepl(">>END_MODULE", lines[i])) {
    current <- strsplit(lines[i], "\t")[[1]]
    range = strsplit(current[5], "-")[[1]]
    if (as.numeric(range[1]) <= 250) {
      new_row = data.frame("Sequence" = current[1], "PValue" = as.numeric(current[3]), "Position" = current[5])
      df = rbind(df, new_row)
    }
    i <- i + 1
  }
  if (nrow(df) > 0) {
    return(TRUE)
  }
  return(FALSE)
}

LowPerBaseQuality <- function(reference, sample) {
  merged = merge(reference, sample, all.x=TRUE, by="Range")
  merged = na.omit(merged)
  low_quality <- merged[(merged$Mean.y < merged$Mean.x-5) | 
                          (merged$Median.y < merged$Median.x-5 & merged$Median.y != 0),]
  if (nrow(low_quality) > 0) {
    print(low_quality)
    return(TRUE)
  }
  return(FALSE)
}

MedianSequenceLength <- function(lines, i) {
  df <- data.frame("Range" = numeric(0), "Count" = numeric(0))
  while (!grepl(">>END_MODULE", lines[i])) {
    current <- strsplit(lines[i],"\t")[[1]]
    new_row <- data.frame("Range" = as.numeric(strsplit(current[1], "-")[[1]][1]), "Count" = as.numeric(current[2]))
    df <- rbind(df, new_row)
    i <- i + 1
  }
  m <- w.median(df$Range, df$Count)
  return(m)
}