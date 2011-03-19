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

/*
 * Charango.Ontology: class for parsing and ontologies
 */
class Charango.Ontology: GLib.Object {

internal Rdf.World *redland;

/**
 * uri: URI for this ontology
 */
public Rdf.Uri uri;

/**
 * prefix: Ontology prefix
 */
public string prefix;

List<Charango.Class>  class_list = null;

public Ontology.from_file (Rdf.World _redland,
                           string    file_name,
                           string    base_path) {
	redland = _redland;

	var storage = new Rdf.Storage (redland, null, null, null);
	var model = new Rdf.Model (redland, storage, null);
	var parser = new Rdf.Parser (redland, "turtle", null, null);

	var file_path = GLib.Path.build_filename (base_path, file_name, null);
	var file_uri = new Rdf.Uri.from_filename (redland, file_path),
		base_uri = new Rdf.Uri.from_filename (redland, base_path);

	parser.parse_into_model (file_uri, base_uri, model);

	/* Find ontology info */
	unowned Rdf.Node uri_node = model.get_source
	                         (redland->get_concept_resource_by_index (Concept.MS_type),
	                          get_tracker_ontology_class (redland));
	if (uri_node == null)
		print ("warning: Ontology %s does not describe itself as a tracker ontology\n", file_name);
	uri = new Rdf.Uri.from_uri (uri_node.get_uri());

	unowned Rdf.Node prefix_node = model.get_target (uri_node,
	                                                 get_tracker_prefix_predicate (redland));
	if (prefix_node == null)
		print ("warning: Ontology %s does not list a prefix\n", file_name);
	prefix = prefix_node.get_literal_value ();
	assert (prefix != null);

	/* Next step: look for each rdf:type and build the class heirarchy */
	Rdf.Iterator iter = model.get_sources (redland->get_concept_resource_by_index (Concept.MS_type),
	                                       redland->get_concept_resource_by_index (Concept.S_Class));
	while (!iter.end()) {
		unowned Rdf.Node class_node = iter.get_object ();
		var rdfs_class = new Charango.Class (this, model, class_node);
		class_list.prepend (rdfs_class);
		iter.next();
	}
}

internal Charango.Class? get_rdfs_class (string name) {
	foreach (Charango.Class c in class_list) {
		if (c.name == name)
			return c;
	}

	return null;
}

public void dump () {
	print ("charango ontology: %s [%s]\n", uri.to_string(), prefix);
	foreach (Charango.Class rdfs_class in class_list) {
		print ("\t"); rdfs_class.dump();
	}
}

}
