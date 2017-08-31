# GIFTS
Improve the flow of annotation between Ensembl and UniProt.

## Setup

Set the ENSCODE environmental variable to be the directory where your code will be located.

```
mkdir $ENSCODE
cd $ENSCODE
git clone https://github.com/Ensembl/ensembl.git
git clone https://github.com/Ensembl/GIFTS.git
export PERL5LIB=$ENSCODE/ensembl/modules:$ENSCODE/ensembl-analysis/modules:$ENSCODE/GIFTS/modules:$BIOPERL_LIB
```
If this is not being run on the EMBL-EBI cluster you will need to obtain a copy of
1. BioPerl
2. HTSlib/Bio::DB::HTS (see instructions below)
 and set the PERL5LIB appropriately.

```
cd $ENSCODE
git clone -b 1.3.2 https://github.com/samtools/htslib.git
cd htslib
export HTSLIB_DIR=${PWD}
make
cd ..
git clone https://github.com/Ensembl/Bio-DB-HTS.git
cd Bio-DB-HTS
perl Build.PL
./Build
export PERL5LIB=$ENSCODE/ensembl/modules:/path/to/bioperl/1.6.1:$ENSCODE/Bio-DB-HTS/lib
```

You can look at env.sh to see what else can be set.

## Per Ensembl Release Scripts

### Load EnsEMBL data

Typically we currently run updates every EnsEMBL release for human, mouse, rat, chicken and vervet-agm.

```
cd $ENSCODE/GIFTS/scripts
bsub perl ensembl_import_species_data.pl --release=ER --user=YOURNAME --species=YOURSPECIES --giftsdb_host=GIFTSHOST --giftsdb_user=GIFTSUSER --giftsdb_pass=GIFTSPASS --giftsdb_name=GIFTSDBNAME --giftsdb_port=GIFTSPORT --registry_host=REGISTRYHOST --registry_user=REGISTRYUSER [--registry_pass=REGISTRYPASS] --registry_port=REGISTRYPORT
```
Once this has occured record the value in the ensembl_species_history table for the species/release of interest. Check the ensembl_transcript table.

## Per UniProt Release Scripts

The mapping_history and ensembl_uniprot table will then need to be populated by UniProt. Once this has occured check the mapping_history and ensembl_uniprot tables in the GIFTS database and record the mapping_history IDs for the species of interest.

### Obtain and Prepare the UniProt Sequence files

The sequence files are needed when generating alignments. The files need to be copied over, and converted to BGZIP format to allow access using Bio::DB::HTS routines.

Check the release version is as expected in /ebi/ftp/private/path/to/uniprot/knowledgebase/reldate.txt
```
mkdir /path/to/uniprot_YYYY_MM
cd /path/to/uniprot_YYYY_MM
export UNIPROT_DIR=/path/to/uniprot_YYYY_MM
$ENSCODE/gifts/scripts/uniprot_fasta_prep.sh
```

### Alignments

There are a number of alignment scripts. The first stage is to run a perfect match alignment. Record the alignment_run_id for this - it should be in the bsub output file, or can be viewed in the alignement_run table in the GIFTS database. A subsequent script can generate alignments scores and/or cigar lines. At the moment various log files are generated to facilitate error hunting.

```
bsub -o $LOGS/pm_alignment.out -e $LOGS/pm_alignment.err -M 10000 -R "rusage[mem=10000]"  perl $ENSCODE/GIFTS/scripts/eu_alignment_perfect_match.pl  --output_dir $LOGS/eER --output_prefix eERspecies --user USERNAME --release ER --species SPECIES --mapping_history_id MH --pipeline_comment "eER species cf with uniprot_YYYY_MM" --uniprot_sp_file $UNIPROT_DIR/uniprot_sp.cleaned.fa.gz --uniprot_sp_isoform_file $UNIPROT_DIR/uniprot_sp_isoforms.cleaned.fa.gz --giftsdb_host=GIFTSHOST --giftsdb_user=GIFTSUSER --giftsdb_pass=GIFTSPASS --giftsdb_name=GIFTSDBNAME --giftsdb_port=GIFTSPORT --registry_host=REGISTRYHOST --registry_user=REGISTRYUSER [--registry_pass=REGISTRYPASS] --registry_port=REGISTRYPORT

bsub -o $LOGS/bc_alignment.out -e $LOGS/bc_alignment.err -M 10000 -R "rusage[mem=10000]" perl $ENSCODE/GIFTS/scripts/eu_alignment_blast_cigar.pl --user USERNAME --perfect_match_alignment_run_id PM --pipeline_comment "species eER vs uniprot_YYYY_MM blasts and cigars (ar PM)" --output_dir /path/to/output_dir --giftsdb_host=GIFTSHOST --giftsdb_user=GIFTSUSER --giftsdb_pass=GIFTSPASS --giftsdb_name=GIFTSDBNAME --giftsdb_port=GIFTSPORT --registry_host=REGISTRYHOST --registry_user=REGISTRYUSER [--registry_pass=REGISTRYPASS] --registry_port=REGISTRYPORT
```



# TGMI project

The TGMI project requires the script

The data needs to be transformed into a one EnsEMBL transcript ID line, which can probably be done using awk. There is then a script to determine if the specified transcript has a UniProt match, if the match is perfect or non-perfect (if no perfect match found), and if the specified UniProt is selected as the canonical or transcript.

```
awk '{ print $2  }' $DATA/tgmi/tgmi_fileset.txt > $DATA/tgmi/enst_version_ids.txt
bsub "perl enst_match_checker.pl --tidfile $DATA/tgmi/enst_version_ids.txt -e EE -u YYYY_MM > $LOGS/tgmi_eu_maps.csv"
```
