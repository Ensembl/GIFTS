#!/bin/bash

# fetch the data files and unzip
cp /path/to/uniprot/knowledgebase/uniprot_sprot_varsplic.fasta.gz .
cp /path/to/uniprot/knowledgebase/uniprot_trembl.fasta.gz .
cp /path/to/uniprot/knowledgebase/uniprot_sprot.fasta.gz .
echo Files Copied

cat /path/to/uniprot/knowledgebase/reldate.txt

gunzip uniprot_sprot_varsplic.fasta.gz
gunzip uniprot_trembl.fasta.gz
gunzip uniprot_sprot.fasta.gz
echo Files Unzipped

# clean the headers
awk -F "|" '/^>/ { print ">"$2; next } 1' uniprot_sprot.fasta > uniprot_sp.cleaned.fa
awk -F "|" '/^>/ { print ">"$2; next } 1' uniprot_sprot_varsplic.fasta > uniprot_sp_isoforms.cleaned.fa
awk -F "|" '/^>/ { print ">"$2; next } 1' uniprot_trembl.fasta > uniprot_tr.cleaned.fa
echo Headers cleaned

# compress into block GZIP format, though for trembl we compress and chunk.
bgzip uniprot_sp.cleaned.fa
bgzip uniprot_sp_isoforms.cleaned.fa
echo Swissprot files compressed

mkdir trembl20
fastasplit --fasta uniprot_tr.cleaned.fa -c 20 --output trembl20

# bgzip the chunks
cd trembl20
for i in $( ls ); do
    bgzip $i
done
cd ..

echo trembl files split and compressed
