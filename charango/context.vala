/*  Charango
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

using Rdf;

public errordomain Charango.ParseError {
	PARSE_ERROR,
	ONTOLOGY_ERROR,
	INVALID_URI,
	DUPLICATED_ONTOLOGY,
	UNKNOWN_NAMESPACE
}

/**
 * Charango.Context: global state object
 *
 * Object representing the state of all Charango data. Holds all the ontology
 * graphs etc.
 */
public class Charango.Context: GLib.Object {

/* FIXME: currently we cannot allow the world to be freed. The issue is that rdf_free_world()
 * causes the destruction of all librdf objects. However, Vala frees the Charango.Context data
 * in some order which has the World freed first, and then things which still have librdf
 * objects. Thus, everything is double freed :(
 */
internal Rdf.World *redland;

bool loading = false;

List<string>   local_sources = null;
List<Ontology> ontology_list = null;

internal int max_class_id = 0;

public Context() {
	redland = new Rdf.World();

	ontology_list.prepend (new RdfOntology (this));
	ontology_list.prepend (new RdfsOntology (this));
	ontology_list.prepend (new TrackerOntology (this));
}

/**
 * add_local_ontology_source():
 * @path: location to search for files
 *
 * Adds @path as a location to search for RDF ontology files when Context.load()
 * is called.
 */
public void add_local_ontology_source (string path)
            throws FileError {
	if (! FileUtils.test (path, FileTest.EXISTS))
		throw new FileError.NOENT ("%s not found", path);
	if (! FileUtils.test (path, FileTest.IS_DIR))
		throw new FileError.NOTDIR ("%s is not a directory", path);

	local_sources.prepend (path);
}

/** set_ontology_prefix:
 * @uri_string: URI of an ontology known to Charango
 * @prefix: short prefix by which you would like to refer to the ontology
 * 
 * Add a prefix for ontology at @uri_string, in case it didn't specify one
 * itself using for example tracker:prefix. You can't call this before calling
 * Context.load() because the ontology will not yet be known to Charango.
 */
public void set_ontology_prefix (string uri_string,
                                 string prefix) {
	Ontology ontology = get_ontology_by_namespace (uri_string);

	if (ontology == null) {
		warning ("Unknown ontology %s", uri_string);
		return;
	}

	ontology.prefix = prefix;
}

string get_parser_name_for_file (string file_name) {
	// FIXME: redland seems to be broken on this front; internally,
	// raptor_guess_parser_name_v2() is passed a world of 0 from
	// raptor_guess_parser_name() and thus segfaults.

	/*string parser_name = Rdf.Parser.guess_name (redland, "/foo", "fuck", "you");
	print ("Got parser: %s\n", parser_name);*/

	// A dumb guessing game. We default to turtle.
	//
	int dot_index = file_name.last_index_of_char ('.');	
	if (dot_index == -1)
		return "turtle";

	string extension = file_name[dot_index+1:file_name.length];

	if (extension == "rdf" || extension == "xml" || extension == "owl")
		return "rdfxml";

	// this is what works, not sure why .. 
	if (extension == "n3")
		return "turtle";

	return "turtle";
}

/**
 * load_ontology_file():
 * @file_name: ontology file to load
 *
 * Intended for testing only. Loads a single ontology file only.
 */
public void load_ontology_file (string   file_path,
                                Rdf.Uri? base_uri = null)
            throws ParseError                       {
	var parser_name = get_parser_name_for_file (file_path);

	var parser = new Rdf.Parser (redland, parser_name, null, null);
	var storage = new Rdf.Storage (redland, null, null, null);
	var model = new Rdf.Model (redland, storage, null);

	var file_uri = new Rdf.Uri.from_filename (redland, file_path);

	parser.parse_into_model (file_uri, base_uri, model);

	bool ignore = false;
	var ontology_node = get_ontology_node_from_model (redland, model, file_path, out ignore);

	if (ignore)
		return;

	var ontology = get_ontology_by_namespace (ontology_node.get_uri().as_string());

	// It's allowed for an ontology to already exist when we find it in
	// a file, but only if it's built in! Otherwise, we have duplicate
	// and possibly conflicting definitions.

	if (ontology == null) {
		ontology = new Ontology (this);
		ontology_list.prepend (ontology);
	} else
		if (ontology.builtin == false)
			throw new ParseError.DUPLICATED_ONTOLOGY
			            ("%s: ontology %s is already defined\n",
			             file_path, ontology.uri);

	ontology.load_from_model ((owned)model, file_path, ontology_node);
}

/*
 * add_external_ontology():
 *
 * Internal function used when an ontology references another that we do not
 * have an actual definition of.
 */
internal Charango.Ontology add_external_ontology (string            namespace_uri,
                                                  Charango.Ontology creator) {
	Ontology ontology = new Ontology (this);
	ontology.external = true;
	ontology.source_file_name = "<external from %s>".printf(creator.source_file_name);
	ontology.uri = namespace_uri;
	ontology_list.prepend (ontology);
	return ontology;
}

/**
 * load():
 *
 * Loads on-disk ontologies into memory.
 */
public void load ()
            throws FileError, ParseError {
	loading = true;

	// Step 1: find the ontology definitions in our list of files
	foreach (string base_path in local_sources) {
		var dir = Dir.open (base_path);

		do {
			var file_name = dir.read_name();
			if (file_name == null)
				break;

			var file_path = GLib.Path.build_filename (base_path, file_name, null);
			var base_uri = new Rdf.Uri.from_filename (redland, base_path);

			load_ontology_file (file_path, base_uri);
		} while (true);
	}

	// Step 2: load classes and property definitions from the files
	foreach (Ontology ontology in ontology_list) {
		if (ontology.has_data ())
			ontology.initial_load ();
	}

	// Step 3: read class and property data from the files
	foreach (Ontology ontology in ontology_list) {
		if (ontology.has_data ())
			ontology.complete_load ();
	}

	loading = false;
}

internal Ontology? get_ontology_by_prefix (string prefix) {
	/* FIXME: there must be a better way to search lists in vala */
	foreach (Ontology c in ontology_list) {
		if (c.prefix == prefix)
			return c;
	}
	return null;
}

public Ontology? get_ontology_by_namespace (string namespace_string) {
	/* FIXME: there must be a better way to search lists in vala */
	foreach (Ontology c in ontology_list) {
		if (c.uri == namespace_string)
			return c;
	}
	return null;
}

public Charango.Class? get_class_by_uri (Rdf.Uri uri)
                       throws ParseError              {
	return get_class_by_uri_string (uri.as_string ());
}

public Charango.Class get_class_by_uri_string (string uri_string)
                       throws ParseError                           {
	Charango.Ontology o;
	Charango.Class    c;
	string name;

	parse_string_as_resource (this, uri_string, out o, out name);

	c = o.get_class_by_name (name);

	if (c == null) {
		if (o.external)
			// User needs to actually supply this ontology, we have got in this
			// state because one ontology defined it as an external ontology to
			// have a soft dep on it, but now we have found something with a
			// hard dep
			throw new ParseError.ONTOLOGY_ERROR ("Missing ontology %s", o.uri);
		else
			throw new ParseError.ONTOLOGY_ERROR ("Unknown class %s:%s", o.uri, name);
	}

	return c;
}

public Charango.Class? get_class_by_uri_string_noerror (string uri_string) {
	try {
		return get_class_by_uri_string (uri_string);
	}
	catch (Error e) {
		warning ("%s", e.message);
	}
	return null;
}

public void dump () {
}

}