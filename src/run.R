#### Declare libraries ####
library(DESeq2)           # differential expression analysis

#### Inputs
args = commandArgs(trailingOnly = T)

#### Count matrix
count_raw = read.table(file = args[1], header = T, sep = "\t", check.names = F)
rownames(count_raw) = count_raw$gene_id
gene_tab = count_raw[,1:2]
count_raw = count_raw[,c(-1,-2)]

#### Metadata
metadata = read.table(file = args[2], header = T, sep = "\t", check.names = F)
rownames(metadata) = metadata[,1]
metadata[,2] = as.factor(metadata[,2])

#### Count matrix re-arrangement
count_raw = count_raw[,rownames(metadata)]

#structure(metadata)

#### DESeq2
# Object initialization
dds = DESeqDataSetFromMatrix(countData = count_raw,
                             colData = metadata,
                             design = ~ condition)

# Pre-filtering: keep rows which more than 50 columns that have counts >= 10
keep = rowSums(counts(dds) >= 10) >= 50
dds = dds[keep,]

# DE analysis
dds = DESeq(dds)
res = results(dds)

res_tab = as.data.frame(na.omit(res))
write.table(x = data.frame("ID" = rownames(res_tab), res_tab), file = args[3], sep = "\t", quote = F, row.names = F)
