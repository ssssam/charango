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
Rdf.World *redland;

List<Ontology> ontology_list = null;

public Context() {
	redland = new Rdf.World();
}

/**
 * add_local_ontology_source: Read ontology data from files in a local path
 * @path: location to search for files
 *
 * Loads all of the files in @path as RDF ontology files. The files will be
 * parsed using the <link rel="http://librdf.org/raptor/">Raptor</a> library's
 * Turtle parser.
 */
public void add_local_ontology_source (string base_path)
            throws FileError {
	var dir = Dir.open (base_path);

	do {
		var file_name = dir.read_name();
		if (file_name == null)
			break;

		var ontology = new Ontology.from_file (redland, file_name, base_path);
		ontology_list.prepend (ontology);
	} while (true);
}

Ontology? get_ontology_for_prefix (string prefix) {
	/* FIXME: there must be a better way to search lists in vala */
	foreach (Ontology c in ontology_list) {
		if (c.prefix == prefix)
			return c;
	}
	return null;
}

internal Charango.Class? get_rdfs_class (string class_uri_string) {
	/* FIXME: most certainly not a standards-compliant way of parsing a URI ... */
	Ontology? ontology = null;
	string? fragment = null;

	if (class_uri_string.index_of_char ('#') == -1) {
		/* See if it's abbreviated */
		var colon_pos = class_uri_string.index_of_char (':');
		if (colon_pos == -1) {
			warning ("invalid class URI: %s\n", class_uri_string);
			return null;
		}

		string prefix = class_uri_string[0:colon_pos];
		ontology = get_ontology_for_prefix (prefix);
		if (ontology == null) {
			warning ("unknown ontology prefix: %s\n", prefix);
			return null;
		}

		fragment = class_uri_string[colon_pos+1: class_uri_string.length];
	} else {
		warning ("FIXME: full uris not yet supported\n");
	}

	return ontology.get_rdfs_class (fragment);
}

public void dump () {
}

}