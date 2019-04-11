#!/bin/bash

PATH_TO_UNIPROT_KNOWLEDGEBASE=$1;
OUTPUT_DIR=$2

# fetch the data files and unzip

if [ ! -f $PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_sprot_varsplic.fasta.gz ]; then
  >&2 echo "$PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_sprot_varsplic.fasta.gz does not exist.";
  exit -1;
fi

if [ ! -f $PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_trembl.fasta.gz ]; then
  >&2 echo "$PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_trembl.fasta.gz does not exist.";
  exit -1;
fi

if [ ! -f $PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_sprot.fasta.gz ]; then
  >&2 echo "$PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_sprot.fasta.gz does not exist.";
  exit -1;
fi

cp $PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_sprot_varsplic.fasta.gz $OUTPUT_DIR/
cp $PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_trembl.fasta.gz $OUTPUT_DIR/
cp $PATH_TO_UNIPROT_KNOWLEDGEBASE/uniprot_sprot.fasta.gz $OUTPUT_DIR/

if [ ! -f $OUTPUT_DIR/uniprot_sprot_varsplic.fasta.gz ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sprot_varsplic.fasta.gz has not been copied successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_trembl.fasta.gz ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_trembl.fasta.gz has not been copied successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_sprot.fasta.gz ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sprot.fasta.gz has not been copied successfully.";
  exit -1;
fi

echo Files Copied

gunzip $OUTPUT_DIR/uniprot_sprot_varsplic.fasta.gz
gunzip $OUTPUT_DIR/uniprot_trembl.fasta.gz
gunzip $OUTPUT_DIR/uniprot_sprot.fasta.gz

if [ ! -f $OUTPUT_DIR/uniprot_sprot_varsplic.fasta ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sprot_varsplic.fasta.gz has not been unzipped successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_trembl.fasta ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_trembl.fasta.gz has not been unzipped successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_sprot.fasta ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sprot.fasta.gz has not been unzipped successfully.";
  exit -1;
fi

echo Files unzipped

# clean the headers
awk -F "|" '/^>/ { print ">"$2; next } 1' $OUTPUT_DIR/uniprot_sprot.fasta > $OUTPUT_DIR/uniprot_sp.cleaned.fa
awk -F "|" '/^>/ { print ">"$2; next } 1' $OUTPUT_DIR/uniprot_sprot_varsplic.fasta > $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa
awk -F "|" '/^>/ { print ">"$2; next } 1' $OUTPUT_DIR/uniprot_trembl.fasta > $OUTPUT_DIR/uniprot_tr.cleaned.fa

if [ ! -f $OUTPUT_DIR/uniprot_sp.cleaned.fa ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sprot_varsplic.fasta has not been cleaned successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_trembl.fasta has not been cleaned successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_tr.cleaned.fa ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sprot.fasta has not been cleaned successfully.";
  exit -1;
fi

echo Headers cleaned

# compress into block GZIP format, though for trembl we compress and chunk.
bgzip $OUTPUT_DIR/uniprot_sp.cleaned.fa
bgzip $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa

if [ ! -f $OUTPUT_DIR/uniprot_sp.cleaned.fa.gz ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sp.cleaned.fa has not been compressed successfully.";
  exit -1;
fi

if [ ! -f $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz ]; then
  >&2 echo "$OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa has not been compressed successfully.";
  exit -1;
fi

# delete the fasta index files (if any from a previous run)
rm $OUTPUT_DIR/uniprot_sp.cleaned.fa.gz.fai $OUTPUT_DIR/uniprot_sp.cleaned.fa.gz.gzi $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz.fai $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz.gzi
if [ -f $OUTPUT_DIR/uniprot_sp.cleaned.fa.gz.fai ]; then
      >&2 echo "$OUTPUT_DIR/uniprot_sp.cleaned.fa.gz.fai has not been deleted successfully.";
      exit -1;
fi
if [ -f $OUTPUT_DIR/uniprot_sp.cleaned.fa.gz.gzi ]; then
      >&2 echo "$OUTPUT_DIR/uniprot_sp.cleaned.fa.gz.gzi has not been deleted successfully.";
      exit -1;
fi
if [ -f $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz.fai ]; then
      >&2 echo "$OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz.fai has not been deleted successfully.";
      exit -1;
fi
if [ -f $OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz.gzi ]; then
      >&2 echo "$OUTPUT_DIR/uniprot_sp_isoforms.cleaned.fa.gz.gzi has not been deleted successfully.";
      exit -1;
fi

echo Swissprot files compressed

mkdir $OUTPUT_DIR/trembl20
fastasplit --fasta $OUTPUT_DIR/uniprot_tr.cleaned.fa -c 20 --output $OUTPUT_DIR/trembl20

# bgzip the chunks
cd $OUTPUT_DIR/trembl20
for i in $( ls ); do
    bgzip $i
    if [ ! -f $i.gz ]; then
      >&2 echo "$OUTPUT_DIR/trembl20/$i has not been compressed successfully.";
      exit -1;
    fi

    # delete the fasta index files (if any from a previous run)
    rm $i.gz.fai $i.gz.gzi;
    if [ -f $i.gz.fai ]; then
      >&2 echo "$OUTPUT_DIR/trembl20/$i.gz.fai has not been deleted successfully.";
      exit -1;
    fi
    if [ -f $i.gz.gzi ]; then
      >&2 echo "$OUTPUT_DIR/trembl20/$i.gz.gzi has not been deleted successfully.";
      exit -1;
    fi
done
cd ..

# delete the fasta index files (if any from a previous run)
rm $OUTPUT_DIR/*.*i
rm $OUTPUT_DIR/trembl20/*.*i



echo trembl files split and compressed
