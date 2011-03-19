/*  redland.vapi
 *
 *  Copyright 2011 Sam Thursfield <ssssam@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

[CCode (cheader_filename = "librdf.h")]
namespace Rdf {
	/***************************************************************************
	 * World
	 */

	[Compact]
	[CCode (cname = "librdf_world", free_function = "librdf_free_world")]
	public class World {
		static const string FEATURE_GENID_BASE;
		static const string FEATURE_GENID_COUNTER;

		[CCode (cname = "librdf_new_world")]
		public World();
		[CCode (cname = "librdf_world_open")]
		public void open();

		/* Missing: set_rasqal, get_rasqal */

		/* Missing: init_mutex (internal) */

		[CCode (cname = "librdf_world_set_error")]
		public void set_error ([CCode (delegate_target_pos = 0.9)] LogLevelFunc error_handler);
		[CCode (cname = "librdf_world_set_warning")]
		public void set_warning ([CCode (delegate_target_pos = 0.9)] LogLevelFunc warning_handler);
		[CCode (cname = "librdf_world_set_logger")]
		public void set_logger ([CCode (delegate_target_pos = 0.9)] LogFunc log_handler);
		[CCode (cname = "librdf_world_set_digest")]
		public void set_digest (string name);

		/* Missing: get/set feature */
		/*REDLAND_API
		librdf_node* librdf_world_get_feature(librdf_world* world, librdf_uri *feature);
		REDLAND_API
		int librdf_world_set_feature(librdf_world* world, librdf_uri *feature, librdf_node* value);*/

		[CCode (cname = "librdf_get_concept_resource_by_index")]
		public unowned Node get_concept_resource_by_index (Concept idx);
		[CCode (cname = "librdf_get_concept_uri_by_index")]
		public unowned Uri get_concept_uri_by_index (Concept idx);

		[CCode (cname = "librdf_get_concept_ms_namespace")]
		public unowned Uri get_concept_ms_namespace ();
		[CCode (cname = "librdf_get_concept_schema_namespace")]
		public unowned Uri get_concept_schema_namespace ();
	}

	/***************************************************************************
	 * Concepts
	 */

	[CCode (cprefix="LIBRDF_CONCEPT_")]
	public enum Concept {
		MS_Alt,
		MS_Bag,
		MS_Property,
		MS_Seq,
		MS_Statement,
		MS_object,
		MS_predicate,
		MS_subject,
		MS_type,
		MS_value,
		MS_li,

		MS_RDF,
		MS_Description,

		MS_aboutEach,
		MS_aboutEachPrefix,

		RS_nodeID,
		RS_List,
		RS_first,
		RS_rest,
		RS_nil,
		RS_XMLLiteral,

		/* RDF Schema concepts defined in prose at
		*   http://www.w3.org/TR/2000/CR-rdf-schema-20000327/
		* and in RDF Schema form at 
		*   http://www.w3.org/2000/01/rdf-schema
		*/
		S_Class,
		S_ConstraintProperty,
		S_ConstraintResource,
		S_Container,
		S_ContainerMembershipProperty,
		S_Literal,
		S_Resource,
		S_comment,
		S_domain,
		S_isDefinedBy,
		S_label,
		S_range,
		S_seeAlso,
		S_subClassOf,
		S_subPropertyOf,

		FIRST_S_ID,
		LAST
	}


	/***************************************************************************
	 * Iterator
	 */

	[Compact]
	[CCode (cname = "librdf_iterator",
	        free_function = "librdf_free_iterator")]
	public class Iterator {
		[Flags]
		public enum GetMethod {
			GET_OBJECT,
			GET_CONTEXT,
			GET_KEY,
			GET_VALUE
		}

		[CCode (cname = "librdf_new_empty_iterator")]
		public Iterator.empty (World world);

		/*[CCode (cname = "librdf_iterator_map_handler")]
		public Delegate void *MapHandler ([CCode delegate_target_pos = 1.9], Iterator iterator, void *item);*/
		/* typedef void (*librdf_iterator_map_free_context_handler)(void *map_context); */

		/* void librdf_new_iterator ((librdf_world *world, void *context, int (*is_end_method)(void*), int (*next_method)(void*), void* (*get_method)(void*, int), void (*finished_method)(void*)); */

		[CCode (cname = "librdf_iterator_end")]
		public bool end ();
		[CCode (cname = "librdf_iterator_next")]
		public int next ();
		[CCode (cname = "librdf_iterator_get_object")]
		public unowned Node get_object ();
		[CCode (cname = "librdf_iterator_get_context")]
		public unowned Node get_context ();
		[CCode (cname = "librdf_iterator_get_key")]
		public unowned void *get_key ();
		[CCode (cname = "librdf_iterator_get_value")]
		public unowned void *get_value ();

		/*REDLAND_API
		int librdf_iterator_add_map(librdf_iterator* iterator, librdf_iterator_map_handler map_function, librdf_iterator_map_free_context_handler free_context, void *map_context);*/
	}


	/***************************************************************************
	 * Log
	 */
	[Compact]
	[CCode (cname = "librdf_log_message")]
	public class LogMessage {
		public int code;
		/* Missing: public LogLevel level; */
		/* Missing: public LogFacility facility; */
		/* Missing: public string message; */
		/* Missing: Locator locator; */
	}

	[CCode (cname = "librdf_log_level_func", instance_pos = 0)]
	public delegate int LogLevelFunc (string message, va_list arguments);
	[CCode (cname = "librdf_log_func", instance_pos = 0)]
	public delegate int LogFunc (LogMessage message);

	/***************************************************************************
	 * Model (graph)
	 */

	/*REDLAND_API
	int librdf_model_enumerate(librdf_world* world, const unsigned int counter, const char **name, const char **label);*/

	[Compact]
	[CCode (cname = "librdf_model",
	        copy_function = "librdf_new_model_from_model",
	        free_function = "librdf_free_model")]
	public class Model {
		[CCode (cname = "librdf_new_model")]
		public Model (World world, Storage storage, string? options_string);
		/*[CCode (cname = "librdf_new_model_with_options")]
		public Model.with_options (World world, Storage storage, Hash options);*/

		[CCode (cname = "librdf_model_size")]
		public int size ();

		[CCode (cname = "librdf_model_add")]
		public int add (Node subject, Node predicate, Node object);
		[CCode (cname = "librdf_model_add_string_literal_statement")]
		public int add_string_literal_statement (Node subject, Node predicate, string literal, string? xml_language, bool is_wf_xml);
		[CCode (cname = "librdf_model_add_typed_literal_statement")]
		public int add_typed_literal_statement (Node subject, Node predicate, string literal, string? xml_language, Uri datatype_uri);
		[CCode (cname = "librdf_model_add_statement")]
		public int add_statement (Statement statement);
		[CCode (cname = "librdf_model_add_statements")]
		public int add_statements (Stream statement_stream);

		[CCode (cname = "librdf_model_remove_statement")]
		public int remove_statement (Statement statement);

		[CCode (cname = "librdf_model_contains_statement")]
		public bool contains_statement (Statement statement);
		[CCode (cname = "librdf_model_has_arc_in")]
		public bool has_arc_in (Node node, Node property);
		[Ccode (cname = "librdf_model_has_arc_out")]
		public bool has_arc_out (Node node, Node property);

		[CCode (cname = "librdf_model_as_stream")]
		public unowned Stream /* FIXME: is it unowned? Docs are unclear */ as_stream ();

		[CCode (cname = "librdf_model_find_statements")]
		public Stream? find_statements (Statement statement);

		[CCode (cname = "LIBRDF_MODEL_FIND_OPTION_MATCH_SUBSTRING_LITERAL")]
		public static const string FIND_OPTION_MATCH_SUBSTRICT_LITERAL;

		/* [CCode (cname = "librdf_model_find_statements_with_options")]
		public Stream? find_statements_with_options (Statement statement, Node context_node, Hash options); */

		[CCode (cname = "librdf_model_get_sources")]
		public Iterator? get_sources (Node arc, Node target);
		[CCode (cname = "librdf_model_get_arcs")]
		public Iterator? get_arcs (Node source, Node target);
		[CCode (cname = "librdf_model_get_targets")]
		public Iterator? get_targets (Node source, Node arc);
		[CCode (cname = "librdf_model_get_source")]
		public unowned Node get_source (Node arc, Node target);
		[CCode (cname = "librdf_model_get_arc")]
		public unowned Node get_arc (Node source, Node target);
		[CCode (cname = "librdf_model_get_target")]
		public unowned Node get_target (Node source, Node arc);

		[CCode (cname = "librdf_model_get_arcs_in")]
		public Iterator? get_arcs_in (Node node);
		[CCode (cname = "librdf_model_get_arcs_out")]
		public Iterator? get_arcs_out (Node node);

		/* From the manual: "FIXME: not tested"
		[CCode (cname = "librdf_model_add_submodel")]
		public int add_submodel (Model submodel);
		[CCode (cname = "librdf_model_remove_submodel")]
		public int remove_submodel (Model submodel);
		*/

		[CCode (cname = "librdf_model_print")]
		public void print (FileStream file_stream);

		[CCode (cname = "librdf_model_context_add_statement")]
		public int context_add_statement (Node? context, Statement statement);
		[CCode (cname = "librdf_model_context_add_statements")]
		public int context_add_statements (Node? context, Stream stream);
		[CCode (cname = "librdf_model_context_remove_statement")]
		public int context_remove_statement (Node? context, Statement statement);
		[CCode (cname = "librdf_model_context_remove_statements")]
		public int context_remove_statements (Node context);

		[CCode (cname = "librdf_model_context_as_stream")]
		public unowned Stream? /* FIXME: is it unowned? Docs are unclear */ context_as_stream (Node context);
		[CCode (cname = "librdf_model_contains_context")]
		public bool contains_context (Node context);

		/* query language */
		/*REDLAND_API
		librdf_query_results* librdf_model_query_execute(librdf_model* model, librdf_query* query);*/

		[CCode (cname = "librdf_model_sync")]
		public int sync ();
		[CCode (cname = "librdf_model_get_storage")]
		public unowned Storage get_storage ();
		[CCode (cname = "librdf_model_load")]
		public int load (Uri uri, string? name, string? mime_type, Uri? type_uri);
		/*[CCode (cname = "librdf_model_to_counted_string")]
		public string to_counted_string (librdf_model* model, librdf_uri *uri, const char *name, const char *mime_type, librdf_uri *type_uri, size_t* string_length_p);*/
		[CCode (cname = "librdf_model_to_string")]
		public string? to_string (Uri? uri, string? name, string? mime_type, Uri? type_uri);

		[CCode (cname = "librdf_model_find_statements_in_context")]
		public Stream? find_statements_in_context (Statement statement, Node context_node);

		[CCode (cname = "librdf_model_get_contexts")]
		public Iterator? get_contexts ();

		[CCode (cname = "librdf_model_transaction_start")]
		public int transaction_start ();
		[CCode (cname = "librdf_model_transaction_start_with_handle")]
		public int transaction_start_with_handle (void *handle);
		[CCode (cname = "librdf_model_transaction_commit")]
		public int transaction_commit ();
		[CCode (cname = "librdf_model_transaction_rollback")]
		public int transaction_rollback ();
		[CCode (cname = "librdf_model_transaction_get_handle")]
		public void *transaction_get_handle ();

		[CCode (cname = "LIBRDF_MODEL_FEATURE_CONTEXTS")]
		public static const string FEATURE_CONTEXTS;

		[CCode (cname = "librdf_model_get_feature")]
		public unowned Node? get_feature (Uri feature);
		[CCode (cname = "librdf_model_set_feature")]
		public int set_feature (Uri feature, Node feature_value);
	}

	/***************************************************************************
	 * Node
	 */

	public enum NodeType {
		UNKNOWN,
		RESOURCE,
		LITERAL,
		BLANK,
		LAST
	}

	[Compact]
	[CCode (cname = "librdf_node",
	        copy_function = "librdf_new_node_from_node",
	        free_function = "librdf_free_node")]
	public class Node {
		[CCode (cname = "librdf_new_node")]
		public Node (World world);
		[CCode (cname = "librdf_new_node_from_blank_identifier")]
		public Node.from_blank_identifier (World world, string? identifier);
		[CCode (cname = "librdf_new_node_from_uri_string")]
		public Node.from_uri_string (World world, string uri_string);
		[CCode (cname = "librdf_new_node_from_uri")]
		public Node.from_uri (World world, Uri uri);
		[CCode (cname = "librdf_new_node_from_uri_local_name")]
		public Node.from_uri_local_name (World world, Uri uri, string local_name);
		[CCode (cname = "librdf_new_node_from_normalised_uri_string")]
		public Node.from_normalised_uri_string (World world, string uri_string, Uri source_uri,
		                                        Uri base_uri);
		[CCode (cname = "librdf_new_node_from_literal")]
		public Node.from_literal (World world, string literal_string, string? xml_language,
		                          bool is_wf_xml);
		[CCode (cname = "librdf_new_node_from_typed_literal")]
		public Node.from_typed_literal (World world, string literal_value, string? xml_language,
		                                Uri? datatype_uri);
		/* Missing: (because all other 'counted' variants are)
		[CCode (cname = "librdf_new_node_from_typed_counted_literal")]
		public Node.from_typed_counted_literal (World world, string literal_value,
		                                        size_t value_len, string xml_language,
		                                        size_t xml_language_len, Uri datatype_uri); */

		[CCode (cname = "librdf_node_get_uri")]
		public unowned Uri? get_uri ();
		[CCode (cname = "librdf_node_get_type")]
		public NodeType get_type ();
		[CCode (cname = "librdf_node_get_literal_value")]
		public unowned string? get_literal_value ();
		/* Missing (as all 'counted' variants):
		[CCode (cname = "librdf_node_get_literal_value_as_counted_string")]
		public string get_literal_value_as_counted_string (out size_t len_p); */
		[CCode (cname = "librdf_node_get_literal_value_as_latin1")]
		public string? get_literal_value_as_latin1 ();
		[CCode (cname = "librdf_node_get_literal_value_language")]
		public string? get_literal_value_language ();
		[CCode (cname = "librdf_node_get_literal_value_is_wf_xml")]
		public bool get_literal_value_is_wf_xml ();
		[CCode (cname = "librdf_node_get_literal_value_datatype_uri")]
		public unowned Uri? get_literal_value_datatype_uri ();

		[CCode (cname = "librdf_node_get_li_ordinal")]
		public int get_li_ordinal ();
		[CCode (cname = "librdf_node_get_blank_identifier")]
		public unowned string get_blank_indentifier ();

		[CCode (cname = "librdf_node_is_resource")]
		public bool is_resource ();
		[CCode (cname = "librdf_node_is_literal")]
		public bool is_literal ();
		[CCode (cname = "librdf_node_is_blank")]
		public bool is_blank ();

		/* Missing:
		REDLAND_API
		size_t librdf_node_encode(librdf_node* node, unsigned char *buffer, size_t length);
		REDLAND_API
		librdf_node* librdf_node_decode(librdf_world *world, size_t* size_p, unsigned char *buffer, size_t length);
		*/

		[CCode (cname = "librdf_node_to_string")]
		public string? to_string ();

		/* Missing:
		REDLAND_API
		unsigned char* librdf_node_to_counted_string(librdf_node* node, size_t* len_p);
		*/

		[CCode (cname = "librdf_node_print")]
		public void print (FileStream file_stream);

		[CCode (cname = "librdf_node_equals")]
		public bool equals (Node other);
	}

	/***************************************************************************
	 * Parser
	 */

	/* Missing:
	REDLAND_API
	void librdf_parser_register_factory(librdf_world *world, const char *name, const char *label, const char *mime_type, const unsigned char *uri_string, void (*factory) (librdf_parser_factory*));

	REDLAND_API
	int librdf_parser_enumerate(librdf_world* world, const unsigned int counter, const char **name, const char **label);
	REDLAND_API
	int librdf_parser_check_name(librdf_world* world, const char *name);
	*/

	[Compact]
	[CCode (cname = "librdf_parser_factory")]
	public class ParserFactory {
	}

	[Compact]
	[CCode (cname = "librdf_parser", free_function="librdf_free_parser")]
	public class Parser {
		[CCode (cname = "LIBRDF_PARSER_FEATURE_ERROR_COUNT")]
		public static const string FEATURE_ERROR_COUNT;
		[CCode (cname = "LIBRDF_PARSER_FEATURE_WARNING_COUNT")]
		public static const string FEATURE_WARNING_COUNT;

		[CCode (cname = "librdf_new_parser")]
		public Parser (World world, string? name, string? mime_type, Uri? type_uri);
		[CCode (cname = "librdf_new_parser_from_factory")]
		public Parser.from_factory (World world, ParserFactory factory);

		/* REDLAND_API
		librdf_stream* librdf_parser_parse_as_stream(librdf_parser* parser, librdf_uri* uri, librdf_uri* base_uri);
		*/
		[CCode (cname = "librdf_parser_parse_into_model")]
		public int parse_into_model (Uri uri, Uri? base_uri, Model model);
		/* REDLAND_API
		librdf_stream* librdf_parser_parse_string_as_stream(librdf_parser* parser, const unsigned char* string, librdf_uri* base_uri);
		*/
		[CCode (cname = "librdf_parser_parse_string_into_model")]
		public int parse_string_into_model (string data, Uri? base_uri, Model model);
		/* REDLAND_API
		librdf_stream* librdf_parser_parse_file_handle_as_stream(librdf_parser* parser, FILE* fh, int close_fh, librdf_uri* base_uri);
		*/
		[CCode (cname = "librdf_parser_parse_file_handle_into_model")]
		public int parse_file_stream_into_model (FileStream file_stream, int close_fh,
		                                         Uri? base_uri, Model model);

		/*REDLAND_API
		librdf_stream* librdf_parser_parse_counted_string_as_stream(librdf_parser* parser, const unsigned char *string, size_t length, librdf_uri* base_uri);
		*/
		/*REDLAND_API
		int librdf_parser_parse_counted_string_into_model(librdf_parser* parser, const unsigned char *string, size_t length, librdf_uri* base_uri, librdf_model* model);
		*/

		[CCode (cname = "librdf_parser_set_uri_filter")]
		public void set_uri_filter ([CCode (delegate_target_pos = 1.1)] UriFilterFunc filter);
		/*REDLAND_API
		librdf_uri_filter_func librdf_parser_get_uri_filter(librdf_parser* parser, void** user_data_p);
		*/

		[CCode (cname = "librdf_parser_get_feature")]
		public unowned Node? get_feature (Uri feature);
		[CCode (cname = "librdf_parser_set_feature")]
		public int set_feature (Uri feature, Node feature_value);
		[CCode (cname = "librdf_parser_get_accept_header")]
		public unowned string? get_accept_header ();

		/*REDLAND_API
		const char* librdf_parser_guess_name2(librdf_world* world, const char *mime_type, const unsigned char *buffer, const unsigned char *identifier);
		*/

		[CCode (cname = "librdf_parser_get_namespaces_seen_prefix")]
		public unowned string? get_namespaces_seen_prefix (int namespace_index);
		[CCode (cname = "librdf_parser_get_namespaces_seen_uri")]
		public unowned Uri? get_namespaces_seen_uri (int namespace_index);
		[CCode (cname = "librdf_parser_get_namespaces_seen_count")]
		public int get_namespaces_seen_count ();
	}

	/***************************************************************************
	 * Statement (triple)
	 */

	[Compact]
	[CCode (cname = "librdf_statement",
	        copy_function = "librdf_new_statement_from_statement",
	        free_function = "librdf_free_statement")]
	public class Statement {
		public enum Part {
			SUBJECT,
			PREDICATE,
			OBJECT,
			ALL
		}

		[CCode (cname = "librdf_new_statement")]
		public Statement (World world);
		[CCode (cname = "librdf_new_statement_from_nodes")]
		public Statement.from_nodes (World world, Node? subject, Node? predicate, Node? object);

		/* Static allocation stuff .. 
		REDLAND_API
		void librdf_statement_init(librdf_world *world, librdf_statement *statement);
		REDLAND_API
		void librdf_statement_clear(librdf_statement *statement);*/

		[CCode (cname = "librdf_statement_get_subject")]
		public /* const */ Node get_subject ();
		[CCode (cname = "librdf_statement_set_subject")]
		public void set_subject (Node node);

		[CCode (cname = "librdf_statement_get_predicate")]
		public /* const */ Node get_predicate ();
		[CCode (cname = "librdf_statement_set_predicate")]
		public void set_predicate (Node node);

		[CCode (cname = "librdf_statement_get_object")]
		public unowned Node get_object ();
		[CCode (cname = "librdf_statement_set_object")]
		public void set_object (Node node);

		[CCode (cname = "librdf_statement_is_complete")]
		public bool is_complete ();

		/*REDLAND_API
		unsigned char *librdf_statement_to_string(librdf_statement *statement);*/
		[CCode (cname = "librdf_statement_print")]
		public void print (FileStream file_stream);

		[CCode (cname = "librdf_statement_equals")]
		public int equals (Statement other);
		[CCode (cname = "librdf_statement_match")]
		public int match (Statement other);

		/*REDLAND_API
		size_t librdf_statement_encode(librdf_statement* statement, unsigned char *buffer, size_t length);
		REDLAND_API
		size_t librdf_statement_encode_parts(librdf_statement* statement, librdf_node* context_node, unsigned char *buffer, size_t length, librdf_statement_part fields);
		REDLAND_API
		size_t librdf_statement_decode(librdf_statement* statement, unsigned char *buffer, size_t length);
		REDLAND_API
		size_t librdf_statement_decode_parts(librdf_statement* statement, librdf_node** context_node, unsigned char *buffer, size_t length);*/
	}

	/***************************************************************************
	 * Storage
	 */

	/*REDLAND_API
	int librdf_storage_register_factory(librdf_world *world, const char *name, const char *label, void (*factory) (librdf_storage_factory*));*/

	/*REDLAND_API
	int librdf_storage_enumerate(librdf_world* world, const unsigned int counter, const char **name, const char **label);*/

	[Compact]
	[CCode (cname = "librdf_storage",
	        copy_function = "librdf_new_storage_from_storage",
	        free_function = "librdf_free_storage")]
	public class Storage {
		[CCode (cname = "librdf_new_storage")]
		public Storage (World world, string? storage_name, string? name, string? options_string);
		/*[CCode (cname = "librdf_new_storage_with_options")]
		public Storage (World world, string storage_name, string name, Hash options);*/
		/*REDLAND_API
		librdf_storage* librdf_new_storage_from_factory(librdf_world *world, librdf_storage_factory* factory, const char *name, librdf_hash* options);*/

		/* "Indended to be internal to librdf storage modules"
		REDLAND_API
		void librdf_storage_add_reference(librdf_storage *storage);
		REDLAND_API
		void librdf_storage_remove_reference(librdf_storage *storage); 

		REDLAND_API
		void librdf_storage_set_instance(librdf_storage *storage, librdf_storage_instance instance);
		REDLAND_API
		librdf_storage_instance librdf_storage_get_instance(librdf_storage *storage);*/

		[CCode (cname = "librdf_storage_get_world")]
		public unowned World get_world ();

		[CCode (cname = "librdf_storage_open")]
		public int open (Model model);
		[CCode (cname = "librdf_storage_close")]
		public int close ();

		[CCode (cname = "librdf_storage_size")]
		public int size ();

		[CCode (cname = "librdf_storage_add_statement")]
		public int add_statement (Statement statement);
		/*[CCode (cname = "librdf_storage_add_statements")]
		public int add_statements (Stream statement_stream);*/
		[CCode (cname = "librdf_storage_remove_statement")]
		public int remove_statement (Statement statement);
		[CCode (cname = "librdf_storage_contains_statement")]
		public bool contains_statement (Statement statement);

		/*REDLAND_API
		librdf_stream* librdf_storage_serialise(librdf_storage* storage);
		REDLAND_API
		librdf_stream* librdf_storage_find_statements(librdf_storage* storage, librdf_statement* statement);
		REDLAND_API
		librdf_stream* librdf_storage_find_statements_with_options(librdf_storage* storage, librdf_statement* statement, librdf_node* context_node, librdf_hash* options);
		REDLAND_API
		librdf_iterator* librdf_storage_get_sources(librdf_storage *storage, librdf_node *arc, librdf_node *target);
		REDLAND_API
		librdf_iterator* librdf_storage_get_arcs(librdf_storage *storage, librdf_node *source, librdf_node *target);
		REDLAND_API
		librdf_iterator* librdf_storage_get_targets(librdf_storage *storage, librdf_node *source, librdf_node *arc);*/

		/*REDLAND_API
		librdf_iterator* librdf_storage_get_arcs_in(librdf_storage *storage, librdf_node *node);
		REDLAND_API
		librdf_iterator* librdf_storage_get_arcs_out(librdf_storage *storage, librdf_node *node);*/

		[CCode (cname = "librdf_storage_has_arc_in")]
		public int has_arc_in (Node node, Node property);
		[CCode (cname = "librdf_storage_has_arc_out")]
		public int has_arc_out (Node node, Node property);

		[CCode (cname = "librdf_storage_context_add_statement")]
		public int context_add_statement (Node context, Statement statement);
		/*[CCode (cname = "librdf_storage_context_add_statements")]
		public int context_add_statements (Node context, Stream stream);*/
		[CCode (cname = "librdf_storage_context_remove_statement")]
		public int context_remove_statement (Node context, Statement statement);
		[CCode (cname = "librdf_storage_context_remove_statements")]
		public int context_remove_statements (Node context);
		/*REDLAND_API
		librdf_stream* librdf_storage_context_as_stream(librdf_storage* storage, librdf_node* context);
		REDLAND_API REDLAND_DEPRECATED
		librdf_stream* librdf_storage_context_serialise(librdf_storage* storage, librdf_node* context);*/
  
		/*REDLAND_API
		int librdf_storage_supports_query(librdf_storage* storage, librdf_query *query);
		REDLAND_API
		librdf_query_results* librdf_storage_query_execute(librdf_storage* storage, librdf_query *query);*/

		[CCode (cname = "librdf_storage_sync")]
		public int sync ();

		/*REDLAND_API
		librdf_stream* librdf_storage_find_statements_in_context(librdf_storage* storage, librdf_statement* statement, librdf_node* context_node);

		REDLAND_API
		librdf_iterator* librdf_storage_get_contexts(librdf_storage* storage);*/

		[CCode (cname = "librdf_storage_get_feature")]
		public unowned Node? get_feature (Uri feature);
		[CCode (cname = "librdf_storage_set_feature")]
		public int set_feature (Uri feature, Node feature_value);

		[CCode (cname = "librdf_storage_transaction_start")]
		public int transaction_start ();
		[CCode (cname = "librdf_storage_transaction_start_with_handle")]
		public int transaction_start_with_handle (void *handle);
		[CCode (cname = "librdf_storage_transaction_commit")]
		public int transaction_commit ();
		[CCode (cname = "librdf_storage_transaction_rollback")]
		public int transaction_rollback ();
		[CCode (cname = "librdf_storage_transaction_get_handle")]
		public void *transaction_get_handle ();
	}

	/***************************************************************************
	 * Stream
	 */

	/* typedef librdf_statement* (*librdf_stream_map_handler)(librdf_stream *stream, void *map_context, librdf_statement *item); */
	/* typedef void (*librdf_stream_map_free_context_handler)(void *map_context); */

	[Compact]
	[CCode (cname = "librdf_stream",
	        free_function = "librdf_free_stream")]
	public class Stream {
		[Flags]
		[CCode (cprefix="LIBRDF_STREAM_GET_METHOD")]
		public enum GetMethod {
			GET_OBJECT,
			GET_CONTEXT
		}

		/* REDLAND_API
		librdf_stream* librdf_new_stream(librdf_world *world, void* context, int (*is_end_method)(void*), int (*next_method)(void*), void* (*get_method)(void*, int), void (*finished_method)(void*)); */
		[CCode (cname = "librdf_new_empty_stream")]
		public Stream.empty (World world);
		[CCode (cname = "librdf_new_stream_from_node_iterator")]
		public Stream.from_node_iterator (Iterator iterator, Statement statement, Statement.Part field);

		[CCode (cname = "librdf_stream_end")]
		public bool end ();
		[CCode (cname = "librdf_stream_next")]
		public int next ();
		[CCode (cname = "librdf_stream_get_object")]
		public unowned Statement get_object ();
		[CCode (cname = "librdf_stream_get_context")]
		public void *get_context ();

		/*REDLAND_API
		int librdf_stream_add_map(librdf_stream* stream, librdf_stream_map_handler map_function, librdf_stream_map_free_context_handler free_context, void *map_context);*/

		[CCode (cname = "librdf_stream_print")]
		public void print (FileStream file_stream);
	}

	/***************************************************************************
	 * Uri
	 */

	[CCode (cname = "librdf_uri_filter_func", instance_pos = 0)]
	public delegate int UriFilterFunc (Uri uri);

	[Compact]
	[CCode (cname = "librdf_uri",
	        copy_function = "librdf_new_uri_from_uri",
	        free_function = "librdf_free_uri")]
	public class Uri {
		[CCode (cname = "librdf_new_uri")]
		public Uri (World world, string uri_string);
		[CCode (cname = "librdf_new_uri_from_uri")]
		public Uri.from_uri (Uri old_uri);
		[CCode (cname = "librdf_new_uri_from_uri_local_name")]
		public Uri.from_uri_local_name (Uri old_uri, string local_name);
		[CCode (cname = "librdf_new_uri_normalised_to_base")]
		public Uri.normalised_to_base (string uri_string, Uri source_uri, Uri base_uri);
		[CCode (cname = "librdf_new_uri_relative_to_base")]
		public Uri.relative_to_base (Uri base_uri, string uri_string);
		[CCode (cname = "librdf_new_uri_from_filename")]
		public Uri.from_filename (World world, string filename);

		/* FIXME: only present due to vala not using the free_function correctly */
		[CCode (cname = "librdf_free_uri")]
		public void free ();

		[CCode (cname = "librdf_uri_as_string")]
		public unowned string as_string();
		/*[CCode (cname = "librdf_uri_as_counted_string")] (librdf_uri *uri, size_t *len_p); */
		[CCode (cname = "librdf_uri_print")]
		public void print (FileStream file_stream);
		[CCode (cname = "librdf_uri_to_string")]
		public string to_string ();
		/*REDLAND_API
		unsigned char* librdf_uri_to_counted_string (librdf_uri* uri, size_t* len_p);*/

		[CCode (cname = "librdf_uri_equals")]
		public bool equals (Uri other);
		[CCode (cname = "librdf_uri_compare")]
		public int compare (Uri other);
		[CCode (cname = "librdf_uri_is_file_uri")]
		public bool is_file_uri ();
		[CCode (cname = "librdf_uri_to_filename")]
		public string to_filename ();
	}
}