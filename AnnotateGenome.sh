#!/bin/bash

# This is the main workflow for the woodchuck genome annotation.
# Calls upon programs and files that are either listed in the README file or located in the repository.

# The woodchuck genome is WCK01_AAH20201022_F8-SCF.fasta

# First, perform annotation liftover using LiftOff from closely related species

# Download RefSeq Alpine marmot genome (marMar2.1)
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/001/458/135/GCF_001458135.1_marMar2.1/GCF_001458135.1_marMar2.1_genomic.fna.gz
 gunzip GCF_001458135.1_marMar2.1_genomic.fna.gz
 # Download the corresponding annotation file
 wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/001/458/135/GCF_001458135.1_marMar2.1/GCF_001458135.1_marMar2.1_genomic.gff.gz
 gunzip GCF_001458135.1_marMar2.1_genomic.gff.gz

# Perform liftover of the Alpine marmot genome annotation to the woodchuck genome sequence
# Uses LiftOff v1.5.1, Minimap2 v2.17-r941 and Python v3.6.11
# Arguments:
# -g is the Alpine marmot annotation file to liftover
# -o is the name of the output annotation
# -p is number of threads
# -f are the feature types to liftover; includes gene, mRNA, exon, CDS, and lnc_RNA
# -flank: amount of flanking sequence to align as a fraction [0.0-1.0] of gene length. This can improve gene alignment where gene structure differs between target and reference
# -copies: look for extra gene copies in the target genome
liftoff \
 WCK01_AAH20201022_F8-SCF.fasta \
 GCF_001458135.1_marMar2.1_genomic.fna \
 -g GCF_001458135.1_marMar2.1_genomic.gff \
 -o from_marMar_copies_scf.gff -p 15 \
 -f liftoffFeatures.txt \
 -m /path/to/minimap2 -flank 0.5 -copies

# Repeat the annotation liftover with the yellow-bellied marmot RefSeq genome annotation (GSC_YBM_2.0)

# Download genome
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/676/075/GCF_003676075.2_GSC_YBM_2.0/GCF_003676075.2_GSC_YBM_2.0_genomic.fna.gz
gunzip GCF_003676075.2_GSC_YBM_2.0_genomic.fna.gz
# Download the annotation file
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/676/075/GCF_003676075.2_GSC_YBM_2.0/GCF_003676075.2_GSC_YBM_2.0_genomic.gff.gz
gunzip GCF_003676075.2_GSC_YBM_2.0_genomic.gff.gz

# Run LiftOff using the same parameters
liftoff \
 WCK01_AAH20201022_F8-SCF.fasta \
 GCF_003676075.2_GSC_YBM_2.0_genomic.fna \
 -g GCF_003676075.2_GSC_YBM_2.0_genomic.gff \
 -o from_gsc_ybm_scf.gff -p 15 \
 -f liftoffFeatures.txt \
 -m /path/to/minimap2 -flank 0.5 -copies
 
 # Repeat this again with the 13-lined ground squirrel Refseq genome annotation (SpeTri2.0)
 
 # Download genome
 wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/236/235/GCF_000236235.1_SpeTri2.0/GCF_000236235.1_SpeTri2.0_genomic.fna.gz
 gunzip GCF_000236235.1_SpeTri2.0_genomic.fna.gz
 # Download annotation
 wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/236/235/GCF_000236235.1_SpeTri2.0/GCF_000236235.1_SpeTri2.0_genomic.gff.gz
 gunzip GCF_000236235.1_SpeTri2.0_genomic.gff.gz
 
 # Run LiftOff using the same parameters
liftoff \
 WCK01_AAH20201022_F8-SCF.fasta \
 GCF_000236235.1_SpeTri2.0_genomic.fna \
 -g GCF_000236235.1_SpeTri2.0_genomic.gff \
 -o from_SpeTri_scf.gff -p 15 \
 -f liftoffFeatures.txt \
 -m /path/to/minimap2 -flank 0.5 -copies

# Second, use transcriptional evidence to locate transcribed genes

# The first step of this process is downloading publically available woodchuck RNA-seq data
# These reads are paired-end and 200bp which improves the accuracy of gene calling compared to short read sequences that
# seem to predict more fragmented gene structure

# Using SRA-toolkit v2.10.8
# Retrieve and the liver reads
prefetch SRR10172922
# Unpack - this provides the two paired fastq files within the reads folder SRR10172922
fasterq-dump --split-files SRR10172922.sra
# Retrieve and unpack kidney
prefetch SRR10172923
fasterq-dump --split-files SRR10172923.sra
# Retrieve and unpack spleen
prefetch SRR10172924
fasterq-dump --split-files SRR10172924.sra
# Retrieve and unpack lung
prefetch SRR10172925
fasterq-dump --split-files SRR10172925.sra
# Retrieve and unpack heart
prefetch SRR10172926
fasterq-dump --split-files SRR10172926.sra
# Retrieve and unpack pancreas
prefetch SRR10172930
fasterq-dump --split-files SRR10172930.sra
# Retrieve and unpack thymus
prefetch SRR10172931
fasterq-dump --split-files SRR10172931.sra

# Now align these reads to the woodchuck genome sequence using hisat2 v2.2.1
# Index the woodchuck genome; -p is the number of threads
# hisat2-build-s specifies the building of a small index library and creates .ht2 extensions
# This is used over the creation of a large index because the genome is less than 4 billion base pairs in length
hisat2-build-s -p 48 WCK01_AAH20201022_F8-SCF.fasta WCK01_AAH20201022_F8-SCF
# Align the reads
# hisat2-align-s specifies that a small reference index is used
# -p is the number of threads
# --dta reports alignments tailored for transcript assemblers (e.g. stringtie)
# -x is the base name of the reference genome index that was specified in hisat2-build-s (precedes the .ht2 extensions)
# -1 and -2 specify the first and second mates of paired-end reads
# -S is the output SAM alignment file
hisat2-align-s -p 48 --dta -x WCK01_AAH20201022_F8-SCF \
 -1 SRR10172922/SRR10172922.sra_1.fastq \
 -2 SRR10172922/SRR10172922.sra_2.fastq \
 -S SRR10172922_scf.sam
hisat2-align-s -p 48 --dta -x WCK01_AAH20201023_F8-SCF \
 -1 SRR10172923/SRR10172923.sra_1.fastq \
 -2 SRR10172923/SRR10172923.sra_2.fastq \
 -S SRR10172923_scf.sam
hisat2-align-s -p 48 --dta -x WCK01_AAH20201022_F8-SCF \
 -1 SRR10172924/SRR10172924.sra_1.fastq \
 -2 SRR10172924/SRR10172924.sra_2.fastq \
 -S SRR10172924_scf.sam
hisat2-align-s -p 48 --dta -x WCK01_AAH20201022_F8-SCF \
 -1 SRR10172925/SRR10172925.sra_1.fastq \
 -2 SRR10172925/SRR10172925.sra_2.fastq \
 -S SRR10172925_scf.sam
hisat2-align-s -p 48 --dta -x WCK01_AAH20201022_F8-SCF \
 -1 SRR10172926/SRR10172926.sra_1.fastq \
 -2 SRR10172926/SRR10172926.sra_2.fastq \
 -S SRR10172926_scf.sam
hisat2-align-s -p 48 --dta -x WCK01_AAH20201022_F8-SCF \
 -1 SRR10172930/SRR10172930.sra_1.fastq \
 -2 SRR10172930/SRR10172930.sra_2.fastq \
 -S SRR10172930_scf.sam
hisat2-align-s -p 48 --dta -x WCK01_AAH20201022_F8-SCF \
 -1 SRR10172931/SRR10172931.sra_1.fastq \
 -2 SRR10172931/SRR10172931.sra_2.fastq \
 -S SRR10172931_scf.sam
 
# These alignments now needed to be converted into sorted BAM files to be used as input for stringtie
# Using samtools v1.12
# -@ is number of threads
# -S specifies SAM input
# -h include header in SAM output; might be irrelevant in this scenario
# -u indicates uncompressed BAM output
# -o is name of output file
samtools view -@ 48 -Shu -o SRR10172922_scf.bam SRR10172922_scf.sam
samtools sort -@ 48 -o SRR10172922_scf.sorted.bam SRR10172922_scf.bam
samtools view -@ 48 -Shu -o SRR10172923_scf.bam SRR10172923_scf.sam
samtools sort -@ 48 -o SRR10172923_scf.sorted.bam SRR10172923_scf.bam
samtools view -@ 48 -Shu -o SRR10172924_scf.bam SRR10172924_scf.sam
samtools sort -@ 48 -o SRR10172924_scf.sorted.bam SRR10172924_scf.bam
samtools view -@ 48 -Shu -o SRR10172925_scf.bam SRR10172925_scf.sam
samtools sort -@ 48 -o SRR10172925_scf.sorted.bam SRR10172925_scf.bam
samtools view -@ 48 -Shu -o SRR10172926_scf.bam SRR10172926_scf.sam
samtools sort -@ 48 -o SRR10172926_scf.sorted.bam SRR10172926_scf.bam
samtools view -@ 48 -Shu -o SRR10172930_scf.bam SRR10172930_scf.sam
samtools sort -@ 48 -o SRR10172930_scf.sorted.bam SRR10172930_scf.bam
samtools view -@ 48 -Shu -o SRR10172931_scf.bam SRR10172931_scf.sam
samtools sort -@ 48 -o SRR10172931_scf.sorted.bam SRR10172931_scf.bam

# Use the sorted bam files as input for stringtie
# The output is a genome annotation file
# Using stringtie v2.1.3
# -o is the name of the output gtf file
# -p is the number of threads
# -l is the name prefix for output transcripts
stringtie SRR10172922_scf.sorted.bam \
 -o stringtie_SRR10172922_scf.gtf -p 48 -l STRG22
stringtie SRR10172923_scf.sorted.bam \
 -o stringtie_SRR10172923_scf.gtf -p 48 -l STRG23
stringtie SRR10172924_scf.sorted.bam \
 -o stringtie_SRR10172924_scf.gtf -p 48 -l STRG24
stringtie SRR10172925_scf.sorted.bam \
 -o stringtie_SRR10172925_scf.gtf -p 48 -l STRG25
stringtie SRR10172926_scf.sorted.bam \
 -o stringtie_SRR10172926_scf.gtf -p 48 -l STRG26
stringtie SRR10172930_scf.sorted.bam \
 -o stringtie_SRR10172930_scf.gtf -p 48 -l STRG30
stringtie SRR10172931_scf.sorted.bam \
 -o stringtie_SRR10172931_scf.gtf -p 48 -l STRG31
 
# To prepare for filtering the stringtie annotation sets with Mikado, validate splice junctions with Portcullis
# Combine separate sorted bam files for input to Portcullis
# -@ is the number of threads
samtools merge -@ 48 alioto_scf_merged.sorted.bam \
 SRR10172922_scf.sorted.bam \
 SRR10172923_scf.sorted.bam \
 SRR10172924_scf.sorted.bam \
 SRR10172925_scf.sorted.bam \
 SRR10172926_scf.sorted.bam \
 SRR10172930_scf.sorted.bam \
 SRR10172931_scf.sorted.bam

