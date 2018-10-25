#!/bin/bash

PATHTOUNIPROTKNOWLEDGEBASE=$1
OUTPUTDIR=$2

# fetch the data files and unzip
mkdir -p $OUTPUTDIR
cp $PATHTOUNIPROTKNOWLEDGEBASE/uniprot_sprot_varsplic.fasta.gz $OUTPUTDIR/
cp $PATHTOUNIPROTKNOWLEDGEBASE/uniprot_trembl.fasta.gz $OUTPUTDIR/
cp $PATHTOUNIPROTKNOWLEDGEBASE/uniprot_sprot.fasta.gz $OUTPUTDIR/
echo Files Copied

cat $PATHTOUNIPROTKNOWLEDGEBASE/reldate.txt

gunzip $OUTPUTDIR/uniprot_sprot_varsplic.fasta.gz
gunzip $OUTPUTDIR/uniprot_trembl.fasta.gz
gunzip $OUTPUTDIR/uniprot_sprot.fasta.gz
echo Files Unzipped

# clean the headers
awk -F "|" '/^>/ { print ">"$2; next } 1' $OUTPUTDIR/uniprot_sprot.fasta > $OUTPUTDIR/uniprot_sp.cleaned.fa
awk -F "|" '/^>/ { print ">"$2; next } 1' $OUTPUTDIR/uniprot_sprot_varsplic.fasta > $OUTPUTDIR/uniprot_sp_isoforms.cleaned.fa
awk -F "|" '/^>/ { print ">"$2; next } 1' $OUTPUTDIR/uniprot_trembl.fasta > $OUTPUTDIR/uniprot_tr.cleaned.fa
echo Headers cleaned

# compress into block GZIP format, though for trembl we compress and chunk.
bgzip $OUTPUTDIR/uniprot_sp.cleaned.fa
bgzip $OUTPUTDIR/uniprot_sp_isoforms.cleaned.fa
echo Swissprot files compressed

mkdir $OUTPUTDIR/trembl20
fastasplit --fasta $OUTPUTDIR/uniprot_tr.cleaned.fa -c 20 --output $OUTPUTDIR/trembl20

# bgzip the chunks
cd $OUTPUTDIR/trembl20
for i in $( ls ); do
    bgzip $i
done
cd ..

echo trembl files split and compressed
