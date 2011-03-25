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
	/* FIXME: test for existance */

	local_sources.prepend (path);
}

/**
 * load():
 *
 * Loads on-disk ontologies into memory.
 */
public void load ()
            throws FileError, ParseError {
	var parser = new Rdf.Parser (redland, "turtle", null, null);

	loading = true;

	foreach (string base_path in local_sources) {
		var dir = Dir.open (base_path);

		do {
			var file_name = dir.read_name();
			if (file_name == null)
				break;

			var storage = new Rdf.Storage (redland, null, null, null);
			var model = new Rdf.Model (redland, storage, null);

			var file_path = GLib.Path.build_filename (base_path, file_name, null);
			var file_uri = new Rdf.Uri.from_filename (redland, file_path),
			    base_uri = new Rdf.Uri.from_filename (redland, base_path);

			parser.parse_into_model (file_uri, base_uri, model);

			var ontology_node = get_ontology_node_from_model (redland, model, file_name);

			if (ontology_node == null)
				// Ignored
				continue;

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

			ontology.load_from_model ((owned)model, ontology_node);
		} while (true);
	}

	// Resolve all URI's
	foreach (Ontology ontology in ontology_list)
		ontology.complete_load ();

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
		if (c.uri == namespace_string) {
			return c;
		}
	}
	return null;
}

public Charango.Class? get_class_by_uri (Rdf.Uri uri) {
	return get_class_by_uri_string (uri.as_string ());
}

public Charango.Class? get_class_by_uri_string (string uri_string)
                       throws ParseError                           {
	Ontology ontology;
	string   name;

	parse_string_as_resource (this, uri_string, out ontology, out name);
	return ontology.get_class_by_name (name);
}

public void dump () {
}

}