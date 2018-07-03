--
-- PostgreSQL database dump
--

-- Dumped from database version 10.4
-- Dumped by pg_dump version 10.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ensembl_gifts; Type: SCHEMA; Schema: -; Owner: gti
--

CREATE SCHEMA ensembl_gifts;


ALTER SCHEMA ensembl_gifts OWNER TO gti;

--
-- Name: on_update_current_timestamp_mapping_history(); Type: FUNCTION; Schema: ensembl_gifts; Owner: gti
--

CREATE FUNCTION ensembl_gifts.on_update_current_timestamp_mapping_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   NEW.time_mapped = now();
   RETURN NEW;
END;
$$;


ALTER FUNCTION ensembl_gifts.on_update_current_timestamp_mapping_history() OWNER TO gti;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: alignment; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.alignment (
    alignment_id bigint NOT NULL,
    alignment_run_id bigint NOT NULL,
    uniprot_id bigint,
    transcript_id bigint,
    mapping_id bigint,
    score1 double precision,
    report character varying(300),
    is_current boolean,
    score2 double precision
);


ALTER TABLE ensembl_gifts.alignment OWNER TO gti;

--
-- Name: alignment_alignment_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.alignment_alignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.alignment_alignment_id_seq OWNER TO gti;

--
-- Name: alignment_alignment_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.alignment_alignment_id_seq OWNED BY ensembl_gifts.alignment.alignment_id;


--
-- Name: alignment_run; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.alignment_run (
    alignment_run_id bigint NOT NULL,
    userstamp character varying(30),
    time_run timestamp with time zone DEFAULT now(),
    score1_type character varying(30),
    report_type character varying(30),
    pipeline_name character varying(30) NOT NULL,
    pipeline_comment character varying(300) NOT NULL,
    release_mapping_history_id bigint NOT NULL,
    ensembl_release bigint NOT NULL,
    uniprot_file_swissprot character varying(300),
    uniprot_file_isoform character varying(300),
    uniprot_dir_trembl character varying(300),
    logfile_dir character varying(300),
    pipeline_script character varying(300) NOT NULL,
    score2_type character varying(30)
);


ALTER TABLE ensembl_gifts.alignment_run OWNER TO gti;

--
-- Name: alignment_run_alignment_run_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.alignment_run_alignment_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.alignment_run_alignment_run_id_seq OWNER TO gti;

--
-- Name: alignment_run_alignment_run_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.alignment_run_alignment_run_id_seq OWNED BY ensembl_gifts.alignment_run.alignment_run_id;


--
-- Name: cv_entry_type; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.cv_entry_type (
    id bigint DEFAULT '0'::bigint NOT NULL,
    description character varying(20)
);


ALTER TABLE ensembl_gifts.cv_entry_type OWNER TO gti;

--
-- Name: cv_ue_label; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.cv_ue_label (
    id bigint NOT NULL,
    description character varying(20) NOT NULL
);


ALTER TABLE ensembl_gifts.cv_ue_label OWNER TO gti;

--
-- Name: cv_ue_status; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.cv_ue_status (
    id bigint NOT NULL,
    description character varying(20) NOT NULL
);


ALTER TABLE ensembl_gifts.cv_ue_status OWNER TO gti;

--
-- Name: domain; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.domain (
    domain_id bigint NOT NULL,
    isoform_id bigint,
    start bigint,
    "end" bigint,
    description character varying(45)
);


ALTER TABLE ensembl_gifts.domain OWNER TO gti;

--
-- Name: domain_domain_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.domain_domain_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.domain_domain_id_seq OWNER TO gti;

--
-- Name: domain_domain_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.domain_domain_id_seq OWNED BY ensembl_gifts.domain.domain_id;


--
-- Name: ensembl_gene; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ensembl_gene (
    gene_id bigint NOT NULL,
    ensg_id character varying(30),
    gene_name character varying(30),
    chromosome character varying(50),
    region_accession character varying(50),
    mod_id character varying(30),
    deleted boolean DEFAULT false,
    seq_region_start bigint,
    seq_region_end bigint,
    seq_region_strand bigint DEFAULT '1'::bigint,
    biotype character varying(40),
    time_loaded timestamp with time zone
);


ALTER TABLE ensembl_gifts.ensembl_gene OWNER TO gti;

--
-- Name: ensembl_gene_gene_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ensembl_gene_gene_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ensembl_gene_gene_id_seq OWNER TO gti;

--
-- Name: ensembl_gene_gene_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ensembl_gene_gene_id_seq OWNED BY ensembl_gifts.ensembl_gene.gene_id;


--
-- Name: ensembl_species_history; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ensembl_species_history (
    ensembl_species_history_id bigint NOT NULL,
    species character varying(30),
    assembly_accession character varying(30),
    ensembl_tax_id bigint,
    ensembl_release bigint,
    status character varying(30),
    time_loaded timestamp with time zone DEFAULT now()
);


ALTER TABLE ensembl_gifts.ensembl_species_history OWNER TO gti;

--
-- Name: ensembl_species_history_ensembl_species_history_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ensembl_species_history_ensembl_species_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ensembl_species_history_ensembl_species_history_id_seq OWNER TO gti;

--
-- Name: ensembl_species_history_ensembl_species_history_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ensembl_species_history_ensembl_species_history_id_seq OWNED BY ensembl_gifts.ensembl_species_history.ensembl_species_history_id;


--
-- Name: ensembl_transcript; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ensembl_transcript (
    transcript_id bigint NOT NULL,
    gene_id bigint,
    enst_id character varying(30),
    enst_version smallint,
    ccds_id character varying(30),
    uniparc_accession character varying(30),
    biotype character varying(40),
    deleted boolean DEFAULT false,
    seq_region_start bigint,
    seq_region_end bigint,
    supporting_evidence character varying(45),
    userstamp character varying(30),
    time_loaded timestamp with time zone
);


ALTER TABLE ensembl_gifts.ensembl_transcript OWNER TO gti;

--
-- Name: ensembl_transcript_transcript_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ensembl_transcript_transcript_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ensembl_transcript_transcript_id_seq OWNER TO gti;

--
-- Name: ensembl_transcript_transcript_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ensembl_transcript_transcript_id_seq OWNED BY ensembl_gifts.ensembl_transcript.transcript_id;


--
-- Name: ensp_u_cigar; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ensp_u_cigar (
    ensp_u_cigar_id bigint NOT NULL,
    cigarplus text,
    mdz text,
    uniprot_acc character varying(30) NOT NULL,
    uniprot_seq_version smallint NOT NULL,
    ensp_id character varying(30) NOT NULL
);


ALTER TABLE ensembl_gifts.ensp_u_cigar OWNER TO gti;

--
-- Name: ensp_u_cigar_ensp_u_cigar_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ensp_u_cigar_ensp_u_cigar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ensp_u_cigar_ensp_u_cigar_id_seq OWNER TO gti;

--
-- Name: ensp_u_cigar_ensp_u_cigar_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ensp_u_cigar_ensp_u_cigar_id_seq OWNED BY ensembl_gifts.ensp_u_cigar.ensp_u_cigar_id;


--
-- Name: gene_history; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.gene_history (
    ensembl_species_history_id bigint NOT NULL,
    gene_id bigint NOT NULL
);


ALTER TABLE ensembl_gifts.gene_history OWNER TO gti;

--
-- Name: isoform; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.isoform (
    isoform_id bigint NOT NULL,
    uniprot_id bigint,
    accession character varying(30),
    sequence character varying(200),
    uniparc_accession character varying(30),
    embl_acc character varying(30)
);


ALTER TABLE ensembl_gifts.isoform OWNER TO gti;

--
-- Name: isoform_isoform_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.isoform_isoform_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.isoform_isoform_id_seq OWNER TO gti;

--
-- Name: isoform_isoform_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.isoform_isoform_id_seq OWNED BY ensembl_gifts.isoform.isoform_id;


--
-- Name: mapping_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.mapping_id_seq OWNER TO gti;

--
-- Name: mapping; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.mapping (
    mapping_id bigint DEFAULT nextval('ensembl_gifts.mapping_id_seq'::regclass) NOT NULL,
    uniprot_id bigint,
    transcript_id bigint,
    grouping_id bigint
);


ALTER TABLE ensembl_gifts.mapping OWNER TO gti;

--
-- Name: mapping_history_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.mapping_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.mapping_history_id_seq OWNER TO gti;

--
-- Name: mapping_history; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.mapping_history (
    mapping_history_id bigint DEFAULT nextval('ensembl_gifts.mapping_history_id_seq'::regclass) NOT NULL,
    release_mapping_history_id bigint NOT NULL,
    sequence_version smallint NOT NULL,
    entry_type smallint NOT NULL,
    entry_version integer NOT NULL,
    enst_version smallint NOT NULL,
    mapping_id bigint NOT NULL,
    sp_ensembl_mapping_type character varying(50)
);


ALTER TABLE ensembl_gifts.mapping_history OWNER TO gti;

--
-- Name: pdb_ens; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.pdb_ens (
    pdb_ens_id bigint NOT NULL,
    pdb_acc character varying(45) NOT NULL,
    pdb_release character varying(11) NOT NULL,
    uniprot_acc character varying(30) NOT NULL,
    enst_id character varying(30) NOT NULL,
    enst_version bigint,
    ensp_id character varying(30) NOT NULL,
    ensp_start bigint,
    ensp_end bigint,
    pdb_start bigint,
    pdb_end bigint,
    pdb_chain character varying(6) NOT NULL
);


ALTER TABLE ensembl_gifts.pdb_ens OWNER TO gti;

--
-- Name: pdb_ens_pdb_ens_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.pdb_ens_pdb_ens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.pdb_ens_pdb_ens_id_seq OWNER TO gti;

--
-- Name: pdb_ens_pdb_ens_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.pdb_ens_pdb_ens_id_seq OWNED BY ensembl_gifts.pdb_ens.pdb_ens_id;


--
-- Name: ptm; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ptm (
    ptm_id bigint NOT NULL,
    domain_id bigint,
    description character varying(45),
    start bigint,
    "end" bigint
);


ALTER TABLE ensembl_gifts.ptm OWNER TO gti;

--
-- Name: ptm_ptm_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ptm_ptm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ptm_ptm_id_seq OWNER TO gti;

--
-- Name: ptm_ptm_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ptm_ptm_id_seq OWNED BY ensembl_gifts.ptm.ptm_id;


--
-- Name: release_mapping_history; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.release_mapping_history (
    release_mapping_history_id bigint NOT NULL,
    ensembl_species_history_id bigint,
    time_mapped timestamp without time zone DEFAULT now() NOT NULL,
    entries_mapped bigint,
    entries_unmapped bigint,
    uniprot_release character varying(7),
    uniprot_taxid bigint,
    status character varying(20)
);


ALTER TABLE ensembl_gifts.release_mapping_history OWNER TO gti;

--
-- Name: release_mapping_history_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.release_mapping_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.release_mapping_history_id_seq OWNER TO gti;

--
-- Name: release_mapping_history_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.release_mapping_history_id_seq OWNED BY ensembl_gifts.release_mapping_history.release_mapping_history_id;


--
-- Name: taxonomy_mapping; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.taxonomy_mapping (
    taxonomy_mapping_id bigint NOT NULL,
    ensembl_tax_id bigint,
    uniprot_tax_id bigint
);


ALTER TABLE ensembl_gifts.taxonomy_mapping OWNER TO gti;

--
-- Name: taxonomy_mapping_taxonomy_mapping_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.taxonomy_mapping_taxonomy_mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.taxonomy_mapping_taxonomy_mapping_id_seq OWNER TO gti;

--
-- Name: taxonomy_mapping_taxonomy_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.taxonomy_mapping_taxonomy_mapping_id_seq OWNED BY ensembl_gifts.taxonomy_mapping.taxonomy_mapping_id;


--
-- Name: transcript_history; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.transcript_history (
    ensembl_species_history_id bigint NOT NULL,
    transcript_id bigint NOT NULL
);


ALTER TABLE ensembl_gifts.transcript_history OWNER TO gti;

--
-- Name: ue_mapping_comment; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ue_mapping_comment (
    id bigint NOT NULL,
    time_stamp timestamp with time zone DEFAULT now() NOT NULL,
    user_stamp character varying(20) NOT NULL,
    comment text NOT NULL,
    mapping_id bigint
);


ALTER TABLE ensembl_gifts.ue_mapping_comment OWNER TO gti;

--
-- Name: ue_mapping_comment_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ue_mapping_comment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ue_mapping_comment_id_seq OWNER TO gti;

--
-- Name: ue_mapping_comment_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ue_mapping_comment_id_seq OWNED BY ensembl_gifts.ue_mapping_comment.id;


--
-- Name: ue_mapping_label; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ue_mapping_label (
    id bigint NOT NULL,
    time_stamp timestamp with time zone DEFAULT now() NOT NULL,
    user_stamp character varying(20) NOT NULL,
    label bigint NOT NULL,
    mapping_id bigint NOT NULL
);


ALTER TABLE ensembl_gifts.ue_mapping_label OWNER TO gti;

--
-- Name: ue_mapping_label_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ue_mapping_label_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ue_mapping_label_id_seq OWNER TO gti;

--
-- Name: ue_mapping_label_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ue_mapping_label_id_seq OWNED BY ensembl_gifts.ue_mapping_label.id;


--
-- Name: ue_mapping_status; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.ue_mapping_status (
    id bigint NOT NULL,
    time_stamp timestamp with time zone DEFAULT now() NOT NULL,
    user_stamp character varying(20) NOT NULL,
    status bigint NOT NULL,
    mapping_id bigint NOT NULL
);


ALTER TABLE ensembl_gifts.ue_mapping_status OWNER TO gti;

--
-- Name: ue_mapping_status_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.ue_mapping_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.ue_mapping_status_id_seq OWNER TO gti;

--
-- Name: ue_mapping_status_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.ue_mapping_status_id_seq OWNED BY ensembl_gifts.ue_mapping_status.id;


--
-- Name: uniprot_entry; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.uniprot_entry (
    uniprot_id bigint NOT NULL,
    uniprot_acc character varying(30),
    uniprot_tax_id bigint,
    userstamp character varying(30),
    "timestamp" timestamp with time zone DEFAULT now(),
    sequence_version smallint DEFAULT '1'::smallint,
    upi character(13),
    md5 character(32),
    canonical_uniprot_id integer,
    ensembl_derived boolean
);


ALTER TABLE ensembl_gifts.uniprot_entry OWNER TO gti;

--
-- Name: uniprot_entry_history; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.uniprot_entry_history (
    release_version character varying(30) DEFAULT ''::character varying NOT NULL,
    uniprot_id bigint NOT NULL
);


ALTER TABLE ensembl_gifts.uniprot_entry_history OWNER TO gti;

--
-- Name: uniprot_entry_uniprot_id_seq; Type: SEQUENCE; Schema: ensembl_gifts; Owner: gti
--

CREATE SEQUENCE ensembl_gifts.uniprot_entry_uniprot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ensembl_gifts.uniprot_entry_uniprot_id_seq OWNER TO gti;

--
-- Name: uniprot_entry_uniprot_id_seq; Type: SEQUENCE OWNED BY; Schema: ensembl_gifts; Owner: gti
--

ALTER SEQUENCE ensembl_gifts.uniprot_entry_uniprot_id_seq OWNED BY ensembl_gifts.uniprot_entry.uniprot_id;


--
-- Name: users; Type: TABLE; Schema: ensembl_gifts; Owner: gti
--

CREATE TABLE ensembl_gifts.users (
    user_id integer,
    email character varying(50),
    elixir_id character varying(50),
    is_admin boolean DEFAULT false,
    validated boolean
);


ALTER TABLE ensembl_gifts.users OWNER TO gti;

--
-- Name: alignment alignment_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment ALTER COLUMN alignment_id SET DEFAULT nextval('ensembl_gifts.alignment_alignment_id_seq'::regclass);


--
-- Name: alignment_run alignment_run_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment_run ALTER COLUMN alignment_run_id SET DEFAULT nextval('ensembl_gifts.alignment_run_alignment_run_id_seq'::regclass);


--
-- Name: domain domain_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.domain ALTER COLUMN domain_id SET DEFAULT nextval('ensembl_gifts.domain_domain_id_seq'::regclass);


--
-- Name: ensembl_gene gene_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_gene ALTER COLUMN gene_id SET DEFAULT nextval('ensembl_gifts.ensembl_gene_gene_id_seq'::regclass);


--
-- Name: ensembl_species_history ensembl_species_history_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_species_history ALTER COLUMN ensembl_species_history_id SET DEFAULT nextval('ensembl_gifts.ensembl_species_history_ensembl_species_history_id_seq'::regclass);


--
-- Name: ensembl_transcript transcript_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_transcript ALTER COLUMN transcript_id SET DEFAULT nextval('ensembl_gifts.ensembl_transcript_transcript_id_seq'::regclass);


--
-- Name: ensp_u_cigar ensp_u_cigar_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensp_u_cigar ALTER COLUMN ensp_u_cigar_id SET DEFAULT nextval('ensembl_gifts.ensp_u_cigar_ensp_u_cigar_id_seq'::regclass);


--
-- Name: isoform isoform_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.isoform ALTER COLUMN isoform_id SET DEFAULT nextval('ensembl_gifts.isoform_isoform_id_seq'::regclass);


--
-- Name: pdb_ens pdb_ens_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.pdb_ens ALTER COLUMN pdb_ens_id SET DEFAULT nextval('ensembl_gifts.pdb_ens_pdb_ens_id_seq'::regclass);


--
-- Name: ptm ptm_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ptm ALTER COLUMN ptm_id SET DEFAULT nextval('ensembl_gifts.ptm_ptm_id_seq'::regclass);


--
-- Name: release_mapping_history release_mapping_history_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.release_mapping_history ALTER COLUMN release_mapping_history_id SET DEFAULT nextval('ensembl_gifts.release_mapping_history_id_seq'::regclass);


--
-- Name: taxonomy_mapping taxonomy_mapping_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.taxonomy_mapping ALTER COLUMN taxonomy_mapping_id SET DEFAULT nextval('ensembl_gifts.taxonomy_mapping_taxonomy_mapping_id_seq'::regclass);


--
-- Name: ue_mapping_comment id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_comment ALTER COLUMN id SET DEFAULT nextval('ensembl_gifts.ue_mapping_comment_id_seq'::regclass);


--
-- Name: ue_mapping_label id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_label ALTER COLUMN id SET DEFAULT nextval('ensembl_gifts.ue_mapping_label_id_seq'::regclass);


--
-- Name: ue_mapping_status id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_status ALTER COLUMN id SET DEFAULT nextval('ensembl_gifts.ue_mapping_status_id_seq'::regclass);


--
-- Name: uniprot_entry uniprot_id; Type: DEFAULT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.uniprot_entry ALTER COLUMN uniprot_id SET DEFAULT nextval('ensembl_gifts.uniprot_entry_uniprot_id_seq'::regclass);


--
-- Name: mapping ensembl_uniprot_pk; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.mapping
    ADD CONSTRAINT ensembl_uniprot_pk PRIMARY KEY (mapping_id);


--
-- Name: alignment idx_24996_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment
    ADD CONSTRAINT idx_24996_primary PRIMARY KEY (alignment_id);


--
-- Name: alignment_run idx_25002_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment_run
    ADD CONSTRAINT idx_25002_primary PRIMARY KEY (alignment_run_id);


--
-- Name: cv_entry_type idx_25010_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.cv_entry_type
    ADD CONSTRAINT idx_25010_primary PRIMARY KEY (id);


--
-- Name: cv_ue_label idx_25014_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.cv_ue_label
    ADD CONSTRAINT idx_25014_primary PRIMARY KEY (id);


--
-- Name: cv_ue_status idx_25017_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.cv_ue_status
    ADD CONSTRAINT idx_25017_primary PRIMARY KEY (id);


--
-- Name: domain idx_25022_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.domain
    ADD CONSTRAINT idx_25022_primary PRIMARY KEY (domain_id);


--
-- Name: ensembl_gene idx_25028_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_gene
    ADD CONSTRAINT idx_25028_primary PRIMARY KEY (gene_id);


--
-- Name: ensembl_species_history idx_25036_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_species_history
    ADD CONSTRAINT idx_25036_primary PRIMARY KEY (ensembl_species_history_id);


--
-- Name: ensembl_transcript idx_25043_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_transcript
    ADD CONSTRAINT idx_25043_primary PRIMARY KEY (transcript_id);


--
-- Name: ensp_u_cigar idx_25057_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensp_u_cigar
    ADD CONSTRAINT idx_25057_primary PRIMARY KEY (ensp_u_cigar_id);


--
-- Name: gene_history idx_25064_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.gene_history
    ADD CONSTRAINT idx_25064_primary PRIMARY KEY (ensembl_species_history_id, gene_id);


--
-- Name: isoform idx_25075_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.isoform
    ADD CONSTRAINT idx_25075_primary PRIMARY KEY (isoform_id);


--
-- Name: release_mapping_history idx_25081_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.release_mapping_history
    ADD CONSTRAINT idx_25081_primary PRIMARY KEY (release_mapping_history_id);


--
-- Name: pdb_ens idx_25088_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.pdb_ens
    ADD CONSTRAINT idx_25088_primary PRIMARY KEY (pdb_ens_id);


--
-- Name: ptm idx_25094_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ptm
    ADD CONSTRAINT idx_25094_primary PRIMARY KEY (ptm_id);


--
-- Name: taxonomy_mapping idx_25100_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.taxonomy_mapping
    ADD CONSTRAINT idx_25100_primary PRIMARY KEY (taxonomy_mapping_id);


--
-- Name: ue_mapping_comment idx_25111_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_comment
    ADD CONSTRAINT idx_25111_primary PRIMARY KEY (id);


--
-- Name: ue_mapping_label idx_25121_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_label
    ADD CONSTRAINT idx_25121_primary PRIMARY KEY (id);


--
-- Name: ue_mapping_status idx_25128_primary; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_status
    ADD CONSTRAINT idx_25128_primary PRIMARY KEY (id);


--
-- Name: mapping_history mapping_history_pk; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.mapping_history
    ADD CONSTRAINT mapping_history_pk PRIMARY KEY (mapping_history_id);


--
-- Name: transcript_history transcript_history_pkey; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.transcript_history
    ADD CONSTRAINT transcript_history_pkey PRIMARY KEY (ensembl_species_history_id, transcript_id);


--
-- Name: uniprot_entry_history uniprot_entry_history_pk; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.uniprot_entry_history
    ADD CONSTRAINT uniprot_entry_history_pk PRIMARY KEY (uniprot_id, release_version);


--
-- Name: uniprot_entry uniprot_entry_pk; Type: CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.uniprot_entry
    ADD CONSTRAINT uniprot_entry_pk PRIMARY KEY (uniprot_id);


--
-- Name: idx_24996_alignment_run_id; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_24996_alignment_run_id ON ensembl_gifts.alignment USING btree (alignment_run_id);


--
-- Name: idx_24996_transcript_id_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_24996_transcript_id_idx ON ensembl_gifts.alignment USING btree (transcript_id);


--
-- Name: idx_24996_uniprot_id_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_24996_uniprot_id_idx ON ensembl_gifts.alignment USING btree (uniprot_id);


--
-- Name: idx_25002_mapping_history_id; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_25002_mapping_history_id ON ensembl_gifts.alignment_run USING btree (release_mapping_history_id);


--
-- Name: idx_25022_isoform_id; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_25022_isoform_id ON ensembl_gifts.domain USING btree (isoform_id);


--
-- Name: idx_25043_enst_id_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE UNIQUE INDEX idx_25043_enst_id_idx ON ensembl_gifts.ensembl_transcript USING btree (enst_id);


--
-- Name: idx_25043_gene_id_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_25043_gene_id_idx ON ensembl_gifts.ensembl_transcript USING btree (gene_id);


--
-- Name: idx_25064_gh_g_id; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_25064_gh_g_id ON ensembl_gifts.gene_history USING btree (gene_id);


--
-- Name: idx_25075_uniform_isoform_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_25075_uniform_isoform_idx ON ensembl_gifts.isoform USING btree (uniprot_id);


--
-- Name: idx_25094_ptm_domain; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX idx_25094_ptm_domain ON ensembl_gifts.ptm USING btree (domain_id);


--
-- Name: idx_stable_id_gene; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE UNIQUE INDEX idx_stable_id_gene ON ensembl_gifts.ensembl_gene USING btree (ensg_id);


--
-- Name: mapping_history_mapping_id_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE INDEX mapping_history_mapping_id_idx ON ensembl_gifts.mapping_history USING btree (mapping_id);


--
-- Name: uniprot_entry_uniprot_acc_idx; Type: INDEX; Schema: ensembl_gifts; Owner: gti
--

CREATE UNIQUE INDEX uniprot_entry_uniprot_acc_idx ON ensembl_gifts.uniprot_entry USING btree (uniprot_acc, sequence_version);


--
-- Name: release_mapping_history on_update_current_timestamp; Type: TRIGGER; Schema: ensembl_gifts; Owner: gti
--

CREATE TRIGGER on_update_current_timestamp BEFORE UPDATE ON ensembl_gifts.release_mapping_history FOR EACH ROW EXECUTE PROCEDURE ensembl_gifts.on_update_current_timestamp_mapping_history();


--
-- Name: alignment alignment_ensembl_uniprot_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment
    ADD CONSTRAINT alignment_ensembl_uniprot_fk FOREIGN KEY (mapping_id) REFERENCES ensembl_gifts.mapping(mapping_id);


--
-- Name: alignment alignment_run_id; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment
    ADD CONSTRAINT alignment_run_id FOREIGN KEY (alignment_run_id) REFERENCES ensembl_gifts.alignment_run(alignment_run_id);


--
-- Name: ptm domain_id; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ptm
    ADD CONSTRAINT domain_id FOREIGN KEY (domain_id) REFERENCES ensembl_gifts.domain(domain_id);


--
-- Name: mapping ensembl_uniprot_ensembl_transcript_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.mapping
    ADD CONSTRAINT ensembl_uniprot_ensembl_transcript_fk FOREIGN KEY (transcript_id) REFERENCES ensembl_gifts.ensembl_transcript(transcript_id);


--
-- Name: mapping ensembl_uniprot_uniprot_entry_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.mapping
    ADD CONSTRAINT ensembl_uniprot_uniprot_entry_fk FOREIGN KEY (uniprot_id) REFERENCES ensembl_gifts.uniprot_entry(uniprot_id);


--
-- Name: ensembl_transcript g_id; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ensembl_transcript
    ADD CONSTRAINT g_id FOREIGN KEY (gene_id) REFERENCES ensembl_gifts.ensembl_gene(gene_id);


--
-- Name: gene_history gh_g_id; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.gene_history
    ADD CONSTRAINT gh_g_id FOREIGN KEY (gene_id) REFERENCES ensembl_gifts.ensembl_gene(gene_id);


--
-- Name: gene_history gh_h_id; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.gene_history
    ADD CONSTRAINT gh_h_id FOREIGN KEY (ensembl_species_history_id) REFERENCES ensembl_gifts.ensembl_species_history(ensembl_species_history_id);


--
-- Name: domain isoform_idx; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.domain
    ADD CONSTRAINT isoform_idx FOREIGN KEY (isoform_id) REFERENCES ensembl_gifts.isoform(isoform_id);


--
-- Name: alignment_run mapping_history_id; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment_run
    ADD CONSTRAINT mapping_history_id FOREIGN KEY (release_mapping_history_id) REFERENCES ensembl_gifts.release_mapping_history(release_mapping_history_id);


--
-- Name: mapping_history mapping_history_mapping_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.mapping_history
    ADD CONSTRAINT mapping_history_mapping_fk FOREIGN KEY (mapping_id) REFERENCES ensembl_gifts.mapping(mapping_id) ON DELETE CASCADE;


--
-- Name: mapping_history mapping_history_release_mapping_history_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.mapping_history
    ADD CONSTRAINT mapping_history_release_mapping_history_fk FOREIGN KEY (release_mapping_history_id) REFERENCES ensembl_gifts.release_mapping_history(release_mapping_history_id);


--
-- Name: release_mapping_history release_mapping_history_ensembl_species_history_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.release_mapping_history
    ADD CONSTRAINT release_mapping_history_ensembl_species_history_fk FOREIGN KEY (ensembl_species_history_id) REFERENCES ensembl_gifts.ensembl_species_history(ensembl_species_history_id);


--
-- Name: transcript_history transcript_history_ensembl_species_history_id_fkey; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.transcript_history
    ADD CONSTRAINT transcript_history_ensembl_species_history_id_fkey FOREIGN KEY (ensembl_species_history_id) REFERENCES ensembl_gifts.ensembl_species_history(ensembl_species_history_id);


--
-- Name: transcript_history transcript_history_transcript_id_fkey; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.transcript_history
    ADD CONSTRAINT transcript_history_transcript_id_fkey FOREIGN KEY (transcript_id) REFERENCES ensembl_gifts.ensembl_transcript(transcript_id);


--
-- Name: alignment transcript_id_idx; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.alignment
    ADD CONSTRAINT transcript_id_idx FOREIGN KEY (transcript_id) REFERENCES ensembl_gifts.ensembl_transcript(transcript_id);


--
-- Name: ue_mapping_comment ue_mapping_comment_ensembl_uniprot_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_comment
    ADD CONSTRAINT ue_mapping_comment_ensembl_uniprot_fk FOREIGN KEY (mapping_id) REFERENCES ensembl_gifts.mapping(mapping_id);


--
-- Name: ue_mapping_label ue_mapping_label_ensembl_uniprot_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_label
    ADD CONSTRAINT ue_mapping_label_ensembl_uniprot_fk FOREIGN KEY (mapping_id) REFERENCES ensembl_gifts.mapping(mapping_id);


--
-- Name: ue_mapping_status ue_mapping_status_ensembl_uniprot_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.ue_mapping_status
    ADD CONSTRAINT ue_mapping_status_ensembl_uniprot_fk FOREIGN KEY (mapping_id) REFERENCES ensembl_gifts.mapping(mapping_id);


--
-- Name: uniprot_entry_history uniprot_entry_history_uniprot_entry_fk; Type: FK CONSTRAINT; Schema: ensembl_gifts; Owner: gti
--

ALTER TABLE ONLY ensembl_gifts.uniprot_entry_history
    ADD CONSTRAINT uniprot_entry_history_uniprot_entry_fk FOREIGN KEY (uniprot_id) REFERENCES ensembl_gifts.uniprot_entry(uniprot_id);


--
-- PostgreSQL database dump complete
--

