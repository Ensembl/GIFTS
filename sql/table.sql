
--
-- Table structure for table `ensembl_species_history`
--

DROP TABLE IF EXISTS `ensembl_species_history`;

CREATE TABLE `ensembl_species_history` (
  `ensembl_species_history_id` int(11) NOT NULL AUTO_INCREMENT,
  `species` varchar(30) DEFAULT NULL,
  `assembly_accession` varchar(30) DEFAULT NULL,
  `ensembl_tax_id` int(11) DEFAULT NULL,
  `ensembl_release` int(11) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `time_loaded` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ensembl_species_history_id`)
) ENGINE=InnoDB ;




--
-- Table structure for table `ensembl_gene`
--

DROP TABLE IF EXISTS `ensembl_gene`;
CREATE TABLE `ensembl_gene` (
  `gene_id` int(11) NOT NULL AUTO_INCREMENT,
  `ensg_id` varchar(30) DEFAULT NULL,
  `gene_name` varchar(30) DEFAULT NULL,
  `chromosome` varchar(20) DEFAULT NULL,
  `region_accession` varchar(30) DEFAULT NULL,
  `assembly_accession` varchar(30) DEFAULT NULL,
  `mod_id` varchar(30) DEFAULT NULL,
  `species` varchar(30) DEFAULT NULL,
  `deleted` tinyint(1) DEFAULT '0',
  `ensembl_tax_id` int(11) DEFAULT NULL,
  `seq_region_start` int(11) DEFAULT NULL,
  `seq_region_end` int(11) DEFAULT NULL,
  `seq_region_strand` int(11) DEFAULT '1',
  `biotype` varchar(40) DEFAULT NULL,
  `ensembl_release` int(11) DEFAULT NULL,
  `userstamp` varchar(30) DEFAULT NULL,
  `time_loaded` datetime DEFAULT NULL,
  PRIMARY KEY (`gene_id`)
) ENGINE=InnoDB ;


--
-- Table structure for table `ensembl_transcript`
--

DROP TABLE IF EXISTS `ensembl_transcript`;
CREATE TABLE `ensembl_transcript` (
  `transcript_id` int(11) NOT NULL AUTO_INCREMENT,
  `gene_id` int(11) DEFAULT NULL,
  `enst_id` varchar(30) DEFAULT NULL,
  `enst_version` smallint(11) DEFAULT NULL,
  `ccds_id` varchar(30) DEFAULT NULL,
  `uniparc_accession` varchar(30) DEFAULT NULL,
  `biotype` varchar(40) DEFAULT NULL,
  `deleted` tinyint(1) DEFAULT '0',
  `seq_region_start` int(11) DEFAULT NULL,
  `seq_region_end` int(11) DEFAULT NULL,
  `supporting_evidence` varchar(45) DEFAULT NULL,
  `ensembl_release` int(11) DEFAULT NULL,
  `userstamp` varchar(30) DEFAULT NULL,
  `time_loaded` datetime DEFAULT NULL,
  PRIMARY KEY (`transcript_id`),
  KEY `gene_id_idx` (`gene_id`),
  CONSTRAINT `G_ID` FOREIGN KEY (`gene_id`) REFERENCES `ensembl_gene` (`gene_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB ;



--
-- Table structure for table `uniprot`
--

DROP TABLE IF EXISTS `uniprot`;
CREATE TABLE `uniprot` (
  `uniprot_id` int(11) NOT NULL AUTO_INCREMENT,
  `uniprot_acc` varchar(30) DEFAULT NULL,
  `protein_existence_id` int(11) DEFAULT NULL,
  `species` varchar(30) DEFAULT NULL,
  `uniprot_tax_id` int(11) DEFAULT NULL,
  `ensembl_derived` tinyint(1) DEFAULT NULL,
  `is_isoform` tinyint(1) DEFAULT NULL,
  `entry_type` varchar(30) DEFAULT NULL,
  `release_version` varchar(30) DEFAULT NULL,
  `userstamp` varchar(30) DEFAULT NULL,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `entry_version` int(11) DEFAULT NULL,
  `mapping_history_id` int(11) DEFAULT NULL,
  `sequence_version` smallint(6) DEFAULT '1',
  `is_canonical` int(11) DEFAULT '0',
  PRIMARY KEY (`uniprot_id`)
) ENGINE=InnoDB ;



--
-- Table structure for table `ensembl_uniprot`
--

DROP TABLE IF EXISTS `ensembl_uniprot`;
CREATE TABLE `ensembl_uniprot` (
  `mapping_id` int(11) NOT NULL AUTO_INCREMENT,
  `uniprot_id` int(11) DEFAULT NULL,
  `userstamp` varchar(30) DEFAULT NULL,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `mapping_history_id` int(11) DEFAULT NULL,
  `transcript_id` int(11) DEFAULT NULL,
  `sp_ensembl_mapping_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`mapping_id`),
  KEY `uniprot_idx_idx` (`uniprot_id`),
  KEY `ensembl_transcript_idx` (`transcript_id`),
  CONSTRAINT `ensembl_transcript_idx` FOREIGN KEY (`transcript_id`) REFERENCES `ensembl_transcript` (`transcript_id`),
  CONSTRAINT `uniprot_aln_idx` FOREIGN KEY (`uniprot_id`) REFERENCES `uniprot` (`uniprot_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;


--
-- Table structure for table `gene_name`
--

DROP TABLE IF EXISTS `gene_name`;
CREATE TABLE `gene_name` (
  `gene_name_id` int(11) NOT NULL AUTO_INCREMENT,
  `uniprot_id` int(11) DEFAULT NULL,
  `gene_symbol` varchar(45) DEFAULT NULL,
  `gene_name_type_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`gene_name_id`),
  KEY `uniprot_name_idx` (`uniprot_id`),
  CONSTRAINT `uniprot_name_idx` FOREIGN KEY (`uniprot_id`) REFERENCES `uniprot` (`uniprot_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB ;


--
-- Table structure for table `isoform`
--

DROP TABLE IF EXISTS `isoform`;
CREATE TABLE `isoform` (
  `isoform_id` int(11) NOT NULL AUTO_INCREMENT,
  `uniprot_id` int(11) DEFAULT NULL,
  `accession` varchar(30) DEFAULT NULL,
  `sequence` varchar(200) DEFAULT NULL,
  `uniparc_accession` varchar(30) DEFAULT NULL,
  `EMBL_acc` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`isoform_id`),
  KEY `uniform_isoform_idx` (`uniprot_id`),
  CONSTRAINT `uniprot_idx` FOREIGN KEY (`uniprot_id`) REFERENCES `uniprot` (`uniprot_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;


--
-- Table structure for table `mapping_history`
--

DROP TABLE IF EXISTS `mapping_history`;
CREATE TABLE `mapping_history` (
  `mapping_history_id` int(11) NOT NULL AUTO_INCREMENT,
  `ensembl_species_history_id` int(20) DEFAULT NULL,
  `time_mapped` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `entries_mapped` int(11) DEFAULT NULL,
  `entries_unmapped` int(11) DEFAULT NULL,
  `uniprot_release` varchar(7) DEFAULT NULL,
  `uniprot_taxid` int(11) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`mapping_history_id`)
) ENGINE=InnoDB ;


--
-- Table structure for table `domain`
--

DROP TABLE IF EXISTS `domain`;
CREATE TABLE `domain` (
  `domain_id` int(11) NOT NULL AUTO_INCREMENT,
  `isoform_id` int(11) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `end` int(11) DEFAULT NULL,
  `description` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`domain_id`),
  KEY `isoform_id` (`isoform_id`),
  CONSTRAINT `isoform_idx` FOREIGN KEY (`isoform_id`) REFERENCES `isoform` (`isoform_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB ;



--
-- Table structure for table `pdb`
--

DROP TABLE IF EXISTS `pdb_ens`;
CREATE TABLE `pdb_ens` (
    `pdb_ens_id` int(11) NOT NULL AUTO_INCREMENT,
    `pdb_acc` varchar(45) DEFAULT NULL,
    `pdb_release` char(11) DEFAULT NULL,
    `uniprot_acc` int(11) DEFAULT NULL,
    `enst_id` int(11) DEFAULT NULL,
    `enst_version` int(11) DEFAULT NULL,
    `ensp_id` int(11) DEFAULT NULL,
    `ensp_start` int(11) DEFAULT NULL,
    `ensp_end` int(11) DEFAULT NULL,
    `pdb_start` int(11) DEFAULT NULL,
    `pdb_end` int(11) DEFAULT NULL,
    `pdb_chain` char(6) DEFAULT NULL,
    PRIMARY KEY (`pdb_ens_id`)
  ) ENGINE=InnoDB;

CREATE TABLE `pdb` (
  `pdb_id` int(11) NOT NULL AUTO_INCREMENT,
  `domain_id` int(11) DEFAULT NULL,
  `pdb_acc` varchar(45) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `end` int(11) DEFAULT NULL,
  PRIMARY KEY (`pdb_id`),
  KEY `pdb_domain` (`domain_id`),
  CONSTRAINT `pdb_domain` FOREIGN KEY (`domain_id`) REFERENCES `domain` (`domain_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB;


--
-- Table structure for table `ptm`
--

DROP TABLE IF EXISTS `ptm`;
CREATE TABLE `ptm` (
  `ptm_id` int(11) NOT NULL AUTO_INCREMENT,
  `domain_id` int(11) DEFAULT NULL,
  `description` varchar(45) DEFAULT NULL,
  `start` int(11) DEFAULT NULL,
  `end` int(11) DEFAULT NULL,
  PRIMARY KEY (`ptm_id`),
  KEY `ptm_domain` (`domain_id`),
  CONSTRAINT `domain_id` FOREIGN KEY (`domain_id`) REFERENCES `domain` (`domain_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB ;


--
-- Table structure for table `taxonomy_mapping`
--

DROP TABLE IF EXISTS `taxonomy_mapping`;
CREATE TABLE `taxonomy_mapping` (
  `taxonomy_mapping_id` int(11) NOT NULL AUTO_INCREMENT,
  `ensembl_tax_id` int(11) DEFAULT NULL,
  `uniprot_tax_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`taxonomy_mapping_id`)
) ENGINE=InnoDB ;




--
-- Table structure for table `alignment_run`
--

DROP TABLE IF EXISTS `alignment_run`;

CREATE TABLE `alignment_run` (
          `alignment_run_id` int(11) NOT NULL AUTO_INCREMENT,
				  `userstamp` varchar(30) DEFAULT NULL,
				  `time_run` datetime DEFAULT CURRENT_TIMESTAMP,
				  `score1_type` varchar(30) DEFAULT NULL,
				  `score2_type` varchar(30) DEFAULT NULL,
				  `report_type` varchar(30) DEFAULT NULL,
				  `pipeline_name` varchar(30) NOT NULL,
				  `mapping_history_id` int(11) NOT NULL,
				  `pipeline_script` varchar(300) NOT NULL,
				  `pipeline_comment` varchar(300) NOT NULL,
				  `uniprot_file_swissprot` varchar(300) DEFAULT NULL,
				  `uniprot_file_isoform` varchar(300) DEFAULT NULL,
				  `uniprot_dir_trembl` varchar(300) DEFAULT NULL,
				  `logfile_dir` varchar(300) DEFAULT NULL,
				  `ensembl_release` int(11) DEFAULT NULL,
				  PRIMARY KEY (`alignment_run_id`),
  CONSTRAINT `mapping_history_id` FOREIGN KEY (`mapping_history_id`) REFERENCES `mapping_history` (`mapping_history_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB ;



--
-- Table structure for table `alignment`
--

DROP TABLE IF EXISTS `alignment`;
CREATE TABLE `alignment` (
  `alignment_id` int(11) NOT NULL AUTO_INCREMENT,
  `alignment_run_id` int(11) NOT NULL,
  `uniprot_id` int(11) DEFAULT NULL,
  `transcript_id` int(11) DEFAULT NULL,
  `mapping_id` int(11) DEFAULT NULL,
  `score1` float DEFAULT NULL,
  `score2` float DEFAULT NULL,
  `report` varchar(300) DEFAULT NULL,
  `is_current` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`alignment_id`),
  KEY `uniprot_id_idx` (`uniprot_id`),
  KEY `transcript_id_idx` (`transcript_id`),
  KEY `mapping_id` (`mapping_id`),
  KEY `alignment_run_id` (`alignment_run_id`),
  CONSTRAINT `alignment_run_id` FOREIGN KEY (`alignment_run_id`) REFERENCES `alignment_run` (`alignment_run_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `mapping_id` FOREIGN KEY (`mapping_id`) REFERENCES `ensembl_uniprot` (`mapping_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `transcript_id_idx` FOREIGN KEY (`transcript_id`) REFERENCES `ensembl_transcript` (`transcript_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `uniprot_id_idx` FOREIGN KEY (`uniprot_id`) REFERENCES `uniprot` (`uniprot_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS `protein_genomic_position`;
CREATE TABLE `protein_genomic_position` (
  `pg_id` int(11) NOT NULL AUTO_INCREMENT,
  `mapping_id` int(11) DEFAULT NULL,
  `alignment_id` int(11) DEFAULT NULL,
  `region_accession` varchar(30) DEFAULT NULL,
  `seq_region_strand` int(11) DEFAULT '1',
  `is_current` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`pg_id`),
  CONSTRAINT `mapping_id` FOREIGN KEY (`mapping_id`) REFERENCES `ensembl_uniprot` (`mapping_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `alignment_id` FOREIGN KEY (`alignment_id`) REFERENCES `alignment` (`alignment_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
) ENGINE=InnoDB ;

DROP TABLE IF EXISTS `codon_genomic_position`;
CREATE TABLE `codon_genomic_position` (
  `cg_id` int(11) NOT NULL AUTO_INCREMENT,
  `pg_id` int(11) NOT NULL,
  `codon_in_protein_index` int(11) NOT NULL,
  `base1_position` int(11) DEFAULT NULL,
  `base2_position` int(11) DEFAULT NULL,
  `base3_position` int(11) DEFAULT NULL,
  `base1_actual` char(1) DEFAULT NULL,
  `base2_actual` char(1) DEFAULT NULL,
  `base3_actual` char(1) DEFAULT NULL,
  `base1_diff` varchar(30) DEFAULT NULL,
  `base2_diff` char(30) DEFAULT NULL,
  `base3_diff` char(30) DEFAULT NULL,

  `split_exon_base` int(11) DEFAULT NULL,
  PRIMARY KEY (`cg_id`),
) ;


DROP TABLE IF EXISTS `ensp_u_cigar`;
CREATE TABLE `ensp_u_cigar` (
  `ensp_u_cigar_id` int(11) NOT NULL AUTO_INCREMENT,
  `cigarplus` text DEFAULT NULL,
  `mdz` text DEFAULT NULL,
  `uniprot_acc` varchar(30) NOT NULL,
  `uniprot_seq_version` smallint(6) NOT NULL,
  `ensp_id`  varchar(30) NOT NULL,
  PRIMARY KEY (`ensp_u_cigar_id`)
)  ENGINE=InnoDB ;


CREATE TABLE `uniprot_unmapped` (
  `uniprot_id` int(11) NOT NULL AUTO_INCREMENT,
  `uniprot_acc` varchar(30) DEFAULT NULL,
  `protein_existence_id` int(11) DEFAULT NULL,
  `species` varchar(30) DEFAULT NULL,
  `uniprot_tax_id` int(11) DEFAULT NULL,
  `entry_type` varchar(30) DEFAULT NULL,
  `release_version` varchar(30) DEFAULT NULL,
  `userstamp` varchar(30) DEFAULT NULL,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `entry_version` int(11) DEFAULT NULL,
  `mapping_history_id` int(11) DEFAULT NULL,
  `sequence_version` smallint(6) DEFAULT '1',
  PRIMARY KEY (`uniprot_id`)
) ENGINE=InnoDB;
