#### Declare libraries ####
## Differential expression analysis
library(DESeq2)

#### Inputs
args = commandArgs(trailingOnly = T)

#### Count matrix
count_raw = read.table(file = args[1], header = T, sep = "\t", check.names = F)
rownames(count_raw) = count_raw$gene_id
count_raw = count_raw[,-1]

#### Metadata
metadata = read.table(file = args[2], header = T, sep = "\t", check.names = F)
rownames(metadata) = metadata[,1]
metadata[,2] = as.factor(metadata[,2])

#### Count matrix re-arrangement
count_raw = count_raw[,rownames(metadata)]


#### DESeq2
## Object initialization
dds = DESeqDataSetFromMatrix(countData = count_raw, colData = metadata, design = ~ condition)

## Analysis
dds = DESeq(dds)
res = results(dds)

## Normalized matrix
count_norm = counts(dds, normalized=T)

res_tab = as.data.frame(na.omit(res))
write.table(x = data.frame("ID" = rownames(res_tab), res_tab), file = args[3], sep = "\t", quote = F, row.names = F)
