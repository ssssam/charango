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

namespace Charango {

/* get_ontology_node_from_model:
 *
 * Assuming @model holds a single ontology definition, find its URI by searching
 * for 'xx rdf:type yy' where yy is an ontology class.
 */
Rdf.Node? get_ontology_node_from_model (Rdf.World *redland,
                                        Rdf.Model  model,
                                        string     file_path)
          throws ParseError {
	Rdf.Node? node = null;

	node = model.get_source (redland->concept (Concept.MS_type),
	                         get_owl_ontology_class (redland));

	if (node == null)
		node = model.get_source (redland->concept (Concept.MS_type),
		                         get_tracker_ontology_class (redland));

	if (node == null) {
		node = model.get_source (redland->concept (Concept.MS_type),
		                         get_dsc_ontology_class (redland));

		if (node != null)
			// Tracker .description file, let's ignore this
			return null;

		throw new ParseError.PARSE_ERROR
		  ("Ontology definition not found in file %s\n", file_path);
	}

	return node;
}

}

/*
 * Charango.Ontology: class for parsing and ontologies
 */
public class Charango.Ontology: GLib.Object {

internal Charango.Context context;

public bool builtin = false;

/**
 * uri: namespace URI for this ontology
 */
public string uri;

/**
 * prefix: Ontology prefix
 */
public string prefix;

protected List<Charango.Class>    class_list = null;
protected List<Charango.Property> property_list = null;

Rdf.Model? model;

public Ontology (Context _context) {
	context = _context;
}

internal void load_from_model (owned Rdf.Model _model,
                               Rdf.Node        this_node)
              throws ParseError                           {
	Rdf.World *redland = context.redland;

	model = (owned) _model;
	uri = this_node.get_uri().to_string();

	Rdf.Node prefix_node;
	prefix_node = model.get_target (this_node,
	                                get_tracker_prefix_predicate (redland));
	if (prefix_node != null)
		prefix = prefix_node.get_literal_value ();

	// Read class list
	Rdf.Iterator iter;
	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          redland->concept (Concept.S_Class));
	while (!iter.end()) {
		var rdfs_class = new Charango.Class (this,
		                                     iter.get_object (),
		                                     context.max_class_id ++);
		class_list.prepend (rdfs_class);
		iter.next();
	}

	// Read property list
	iter = model.get_sources (redland->concept (Concept.MS_type),
	                          redland->concept (Concept.MS_Property));
	while (!iter.end()) {
		var rdfs_property = new Charango.Property (this,
		                                           iter.get_object ());
		property_list.prepend (rdfs_property);
		iter.next();
	}
}

/* complete_load: connect up the property and class objects */
internal void complete_load ()
         throws ParseError     {
	foreach (Class c in class_list)
		if (c.builtin == false)
			c.load (model);
	foreach (Property p in property_list)
		p.load (model);
	model = null;
}

internal Charango.Class? get_class_by_name (string name) {
	foreach (Charango.Class c in class_list) {
		if (c.name == name) {
			return c;
		}
	}

	return null;
}

public void dump () {
	print ("charango ontology: %s [%s]\n", uri.to_string(), prefix);
	foreach (Charango.Class rdfs_class in class_list) {
		assert (rdfs_class != null);
		print ("\tclass %i: ", 1); rdfs_class.dump();
	}
	foreach (Charango.Property rdfs_property in property_list) {
		print ("\tproperty %i: ", 1); rdfs_property.dump();
	}
}

}
